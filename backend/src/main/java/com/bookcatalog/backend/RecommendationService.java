package com.bookcatalog.backend;

import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.*;
import java.util.stream.Collectors;

@Service
public class RecommendationService {

    private static final int MIN_RATING = 4;
    private static final int TAGS_PER_BOOK = 3;
    private static final int MAX_SEARCH_TAGS = 12;
    private static final int MAX_PER_AUTHOR = 2;
    private static final int MAX_LIMIT = 20;
    private static final long CACHE_TTL_MS = 10 * 60 * 1000L;

    // Too broad to be useful as a search term (still used for scoring)
    private static final Set<String> GENERIC_TAGS = Set.of(
            "fiction", "general", "literature", "history", "literary",
            "classics", "fiction, general", "juvenile fiction", "novela");

    private final BookRepository bookRepository;
    private final GoogleBooksService googleBooksService;

    private volatile CachedResult cache;

    private record CachedResult(String key, long createdAt, List<Book> books) {}

    public RecommendationService(BookRepository bookRepository,
                                 GoogleBooksService googleBooksService) {
        this.bookRepository = bookRepository;
        this.googleBooksService = googleBooksService;
    }

    public List<Book> getRecommendations(int limit) {
        int size = Math.max(1, Math.min(limit, MAX_LIMIT));
        List<Book> catalog = bookRepository.findAll();

        List<Book> liked = catalog.stream()
                .filter(b -> b.getRating() != null && b.getRating() >= MIN_RATING)
                .toList();
        if (liked.isEmpty()) return List.of();

        // Same library and ratings as last time? Serve the cached result.
        String cacheKey = fingerprint(catalog) + "|" + size;
        CachedResult hit = cache;
        if (hit != null && hit.key().equals(cacheKey)
                && System.currentTimeMillis() - hit.createdAt() < CACHE_TTL_MS) {
            return hit.books();
        }

        List<String> vocabulary = catalog.stream()
                .flatMap(b -> usefulTags(b).stream())
                .distinct()
                .toList();
        if (vocabulary.isEmpty()) return List.of();

        double[] taste = buildTasteVector(liked, vocabulary);
        List<String> searchTags = pickSearchTags(liked);
        if (searchTags.isEmpty()) return List.of();

        List<Book> candidates = searchInParallel(searchTags);

        // What the user already owns, by ISBN and by work (title + author)
        Set<String> ownedIsbns = new HashSet<>();
        Set<String> ownedWorks = new HashSet<>();
        Set<String> ownedTitles = new HashSet<>();
        for (Book b : catalog) {
            ownedIsbns.add(b.getIsbn());
            ownedWorks.add(workKey(b));
            ownedTitles.add(normalize(b.getTitle()));
        }

        // One candidate per ISBN, minus anything already owned
        Map<String, Book> byIsbn = new LinkedHashMap<>();
        for (Book c : candidates) {
            if (c.getIsbn() == null || ownedIsbns.contains(c.getIsbn())) continue;
            if (ownedWorks.contains(workKey(c))) continue;
            if (authorKey(c).isEmpty() && ownedTitles.contains(normalize(c.getTitle()))) continue;
            byIsbn.putIfAbsent(c.getIsbn(), c);
        }

        List<Map.Entry<Book, Double>> scored = new ArrayList<>();
        for (Book c : byIsbn.values()) {
            List<String> tags = usefulTags(c);
            if (tags.isEmpty()) continue;
            double score = cosineSimilarity(taste, buildVector(tags, vocabulary));
            if (score > 0) scored.add(Map.entry(c, score));
        }
        scored.sort((a, b) -> Double.compare(b.getValue(), a.getValue()));

        // Best first, but one edition per work and a cap per author
        Set<String> seenWorks = new HashSet<>();
        Map<String, Integer> perAuthor = new HashMap<>();
        List<Book> picks = new ArrayList<>();
        for (Map.Entry<Book, Double> entry : scored) {
            Book book = entry.getKey();
            String work = workKey(book);
            String author = authorKey(book);
            if (seenWorks.contains(work)) continue;
            if (perAuthor.getOrDefault(author, 0) >= MAX_PER_AUTHOR) continue;
            seenWorks.add(work);
            perAuthor.merge(author, 1, Integer::sum);
            picks.add(book);
            if (picks.size() == size) break;
        }

        enrichDetails(picks);

        // Never cache an empty result, it may just mean the external APIs failed
        if (!picks.isEmpty()) {
            cache = new CachedResult(cacheKey, System.currentTimeMillis(), picks);
        }
        return picks;
    }

    // ---------- search tag selection ----------

    /** Each liked book contributes its most informative tags, so no single book dominates. */
    private List<String> pickSearchTags(List<Book> liked) {
        Map<String, Integer> frequency = new HashMap<>();
        for (Book b : liked) {
            for (String t : usefulTags(b)) frequency.merge(t, 1, Integer::sum);
        }

        List<List<String>> perBook = new ArrayList<>();
        for (Book b : liked) {
            List<String> tags = usefulTags(b).stream()
                    .filter(t -> !GENERIC_TAGS.contains(t))
                    .collect(Collectors.toCollection(ArrayList::new));
            // Tags shared by several liked books first; sort is stable, so the
            // original order (most specific tags come first) breaks ties.
            tags.sort((a, c) -> Integer.compare(frequency.get(c), frequency.get(a)));
            perBook.add(tags);
        }

        Set<String> chosen = new LinkedHashSet<>();
        int[] next = new int[perBook.size()];
        for (int round = 0; round < TAGS_PER_BOOK && chosen.size() < MAX_SEARCH_TAGS; round++) {
            for (int i = 0; i < perBook.size() && chosen.size() < MAX_SEARCH_TAGS; i++) {
                List<String> tags = perBook.get(i);
                while (next[i] < tags.size()) {
                    if (chosen.add(tags.get(next[i]++))) break;
                }
            }
        }
        return new ArrayList<>(chosen);
    }

    private List<Book> searchInParallel(List<String> tags) {
        ExecutorService pool = Executors.newFixedThreadPool(Math.min(tags.size(), 6));
        try {
            List<Callable<List<Book>>> tasks = tags.stream()
                    .map(tag -> (Callable<List<Book>>) () -> googleBooksService.searchByTag(tag))
                    .toList();
            List<Book> all = new ArrayList<>();
            for (Future<List<Book>> future : pool.invokeAll(tasks, 40, TimeUnit.SECONDS)) {
                if (future.isCancelled()) continue;
                try {
                    all.addAll(future.get());
                } catch (ExecutionException ignored) {
                    // one failed search should not break the rest
                }
            }
            return all;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return List.of();
        } finally {
            pool.shutdownNow();
        }
    }

    // ---------- tags and vectors ----------

    private static List<String> usefulTags(Book book) {
        if (book.getTags() == null) return List.of();
        return book.getTags().stream()
                .filter(Objects::nonNull)
                .map(t -> t.trim().toLowerCase(Locale.ROOT))
                .filter(RecommendationService::isUsefulTag)
                .distinct()
                .toList();
    }

    private static boolean isUsefulTag(String t) {
        if (t.length() < 3 || t.length() > 40) return false;
        if (t.contains(":") || t.contains("--")) return false;
        if (t.matches(".*\\d{3,}.*")) return false; // years, call numbers
        return !(t.startsWith("reading level")
                || t.contains("large type")
                || t.contains("open library")
                || t.contains("new york times")
                || t.contains("in library")
                || t.contains("long now")
                || t.contains("publication type")
                || t.contains("translations")
                || t.contains("language materials")
                || t.contains("collectionid"));
    }

    private double[] buildVector(List<String> tags, List<String> vocabulary) {
        Set<String> set = new HashSet<>(tags);
        double[] vector = new double[vocabulary.size()];
        for (int i = 0; i < vocabulary.size(); i++) {
            vector[i] = set.contains(vocabulary.get(i)) ? 1.0 : 0.0;
        }
        return vector;
    }

    /** Average of the liked books, weighted by rating (a 5 counts more than a 4). */
    private double[] buildTasteVector(List<Book> liked, List<String> vocabulary) {
        double[] sum = new double[vocabulary.size()];
        double totalWeight = 0;
        for (Book b : liked) {
            double weight = b.getRating();
            double[] v = buildVector(usefulTags(b), vocabulary);
            for (int i = 0; i < v.length; i++) sum[i] += v[i] * weight;
            totalWeight += weight;
        }
        for (int i = 0; i < sum.length; i++) sum[i] /= totalWeight;
        return sum;
    }

    private double cosineSimilarity(double[] a, double[] b) {
        double dot = 0, normA = 0, normB = 0;
        for (int i = 0; i < a.length; i++) {
            dot += a[i] * b[i];
            normA += a[i] * a[i];
            normB += b[i] * b[i];
        }
        if (normA == 0 || normB == 0) return 0;
        return dot / (Math.sqrt(normA) * Math.sqrt(normB));
    }

    // ---------- matching the same book across editions ----------

    private static String normalize(String s) {
        if (s == null) return "";
        return s.toLowerCase(Locale.ROOT)
                .replaceAll("\\(.*?\\)", " ")
                .replaceAll("[:;].*$", "")
                .replaceAll("[^\\p{L}\\p{N}]+", " ")
                .trim()
                .replaceFirst("^(the|a|an) ", "");
    }

    private static String authorKey(Book b) {
        String a = b.getAuthor();
        if (a == null || a.isBlank() || a.equalsIgnoreCase("Unknown Author")) return "";
        return normalize(a.split(",")[0]);
    }

    private static String workKey(Book b) {
        return normalize(b.getTitle()) + "|" + authorKey(b);
    }

    private static String fingerprint(List<Book> catalog) {
        String joined = catalog.stream()
                .map(b -> b.getIsbn() + ":" + b.getRating())
                .sorted()
                .collect(Collectors.joining(","));
        return String.valueOf(joined.hashCode());
    }

    // ---------- synopsis prefetch (nothing is saved) ----------

    private void enrichDetails(List<Book> books) {
        List<Book> missing = books.stream()
                .filter(b -> isBlank(b.getDescription()))
                .toList();
        if (missing.isEmpty()) return;

        ExecutorService pool = Executors.newFixedThreadPool(Math.min(missing.size(), 6));
        try {
            List<Callable<Void>> tasks = missing.stream()
                    .map(book -> (Callable<Void>) () -> {
                        Book details = googleBooksService.lookupCached(book.getIsbn());
                        if (details != null) fillMissing(book, details);
                        return null;
                    })
                    .toList();
            pool.invokeAll(tasks, 25, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } finally {
            pool.shutdownNow();
        }
    }

    private static void fillMissing(Book target, Book source) {
        if (isBlank(target.getDescription())) target.setDescription(source.getDescription());
        if (isBlank(target.getCoverUrl())) target.setCoverUrl(source.getCoverUrl());
        if (isBlank(target.getPublisher())) target.setPublisher(source.getPublisher());
        if (isBlank(target.getPublishedDate())) target.setPublishedDate(source.getPublishedDate());
        if (target.getPageCount() == null) target.setPageCount(source.getPageCount());
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
