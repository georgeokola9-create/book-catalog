package com.bookcatalog.backend;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.springframework.stereotype.Service;

@Service
public class RecommendationService {

    private final BookRepository bookRepository;
    private final GoogleBooksService googleBooksService;

    public RecommendationService(BookRepository bookRepository, GoogleBooksService googleBooksService) {
        this.bookRepository = bookRepository;
        this.googleBooksService = googleBooksService;
    }

    public List<Book> getRecommendations(int limit) {
        List<Book> catalog = bookRepository.findAll();

        List<String> vocabulary = catalog.stream()
                .flatMap(b -> tagsFor(b).stream())
                .distinct()
                .toList();

        if (vocabulary.isEmpty()) {
            return List.of();
        }

        List<Book> highlyRated = catalog.stream()
                .filter(b -> b.getRating() != null && b.getRating() >= 4)
                .toList();

        if (highlyRated.isEmpty()) {
            return List.of();
        }

        double[] tasteVector = buildAverageVector(highlyRated, vocabulary);

        Set<String> ownedIsbns = new HashSet<>();
        catalog.forEach(b -> ownedIsbns.add(b.getIsbn()));

        // Only search using tags from highly-rated books, capped to avoid excessive API calls
        List<String> searchTags = highlyRated.stream()
                .flatMap(b -> tagsFor(b).stream())
                .distinct()
                .limit(10)
                .toList();

        List<Book> candidates = new ArrayList<>();
        for (String tag : searchTags) {
            List<Book> results = googleBooksService.searchByTag(tag);
            candidates.addAll(results);
        }

        Map<String, Book> uniqueCandidates = new LinkedHashMap<>();
        for (Book candidate : candidates) {
            if (candidate.getIsbn() != null && !ownedIsbns.contains(candidate.getIsbn())) {
                uniqueCandidates.putIfAbsent(candidate.getIsbn(), candidate);
            }
        }

        List<Map.Entry<Book, Double>> scored = new ArrayList<>();
        for (Book candidate : uniqueCandidates.values()) {
            double[] candidateVector = buildVector(tagsFor(candidate), vocabulary);
            double score = cosineSimilarity(tasteVector, candidateVector);
            if (score > 0) {
                scored.add(Map.entry(candidate, score));
            }
        }

        scored.sort((a, b) -> Double.compare(b.getValue(), a.getValue()));

        List<Book> top = scored.stream()
                .limit(limit)
                .map(Map.Entry::getKey)
                .toList();

        enrichDetails(top);
        return top;
    }

    /** Fills in synopsis and publisher info for the final picks, in parallel and without saving anything. */
    private void enrichDetails(List<Book> books) {
        List<Book> missing = books.stream()
                .filter(b -> b.getDescription() == null || b.getDescription().isBlank())
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

    private List<String> tagsFor(Book book) {
        return book.getTags() != null ? book.getTags() : List.of();
    }

    private double[] buildVector(List<String> tags, List<String> vocabulary) {
        double[] vector = new double[vocabulary.size()];
        for (int i = 0; i < vocabulary.size(); i++) {
            vector[i] = tags.contains(vocabulary.get(i)) ? 1.0 : 0.0;
        }
        return vector;
    }

    private double[] buildAverageVector(List<Book> books, List<String> vocabulary) {
        double[] sum = new double[vocabulary.size()];
        for (Book book : books) {
            double[] vector = buildVector(tagsFor(book), vocabulary);
            for (int i = 0; i < vector.length; i++) {
                sum[i] += vector[i];
            }
        }
        for (int i = 0; i < sum.length; i++) {
            sum[i] /= books.size();
        }
        return sum;
    }

    private double cosineSimilarity(double[] a, double[] b) {
        double dot = 0;
        double normA = 0;
        double normB = 0;
        for (int i = 0; i < a.length; i++) {
            dot += a[i] * b[i];
            normA += a[i] * a[i];
            normB += b[i] * b[i];
        }
        if (normA == 0 || normB == 0) {
            return 0;
        }
        return dot / (Math.sqrt(normA) * Math.sqrt(normB));
    }
}
