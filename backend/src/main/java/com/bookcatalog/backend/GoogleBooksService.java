package com.bookcatalog.backend;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
public class GoogleBooksService {

    private final RestClient googleClient = RestClient.create("https://www.googleapis.com/books/v1");
    private final RestClient openLibraryClient = RestClient.create("https://openlibrary.org");

    @Value("${google.books.api.key:}")
    private String googleBooksApiKey;

    private static String openLibraryCover(String isbn) {
        return "https://covers.openlibrary.org/b/isbn/" + isbn + "-M.jpg?default=false";
    }

    private static String cleanText(String raw) {
        if (raw == null) return null;
        String text = raw
                .replaceAll("(?i)<br\\s*/?>|</p>", "\n")
                .replaceAll("<[^>]+>", "")
                .replace("&quot;", "\"")
                .replace("&#39;", "'")
                .replace("&nbsp;", " ")
                .replace("&amp;", "&")
                .replaceAll("[ \\t]+", " ")
                .replaceAll("\\n\\s*\\n+", "\n\n")
                .trim();
        return text.isEmpty() ? null : text;
    }

    @SuppressWarnings("unchecked")
    private static String googleCover(Map<String, Object> volumeInfo, String isbn) {
        Map<String, Object> images = (Map<String, Object>) volumeInfo.get("imageLinks");
        if (images != null) {
            Object thumb = images.get("thumbnail");
            if (thumb == null) thumb = images.get("smallThumbnail");
            if (thumb != null) {
                return thumb.toString().replace("http://", "https://").replace("&edge=curl", "");
            }
        }
        return openLibraryCover(isbn);
    }

    private static String extractDescription(Object value) {
        if (value instanceof String s) return cleanText(s);
        if (value instanceof Map<?, ?> m && m.get("value") instanceof String s) return cleanText(s);
        return null;
    }

    @SuppressWarnings("unchecked")
    private String fetchOpenLibraryDescription(String editionKey) {
        if (editionKey == null) return null;
        try {
            Map<String, Object> edition = openLibraryClient.get()
                    .uri(editionKey + ".json").retrieve().body(Map.class);
            if (edition == null) return null;

            String fromEdition = extractDescription(edition.get("description"));
            if (fromEdition != null) return fromEdition;

            List<Map<String, Object>> works = (List<Map<String, Object>>) edition.get("works");
            if (works == null || works.isEmpty()) return null;

            Map<String, Object> work = openLibraryClient.get()
                    .uri(works.get(0).get("key") + ".json").retrieve().body(Map.class);
            return work == null ? null : extractDescription(work.get("description"));
        } catch (Exception e) {
            return null;
        }
    }

    public Book lookupByIsbn(String isbn) {
        if (googleBooksApiKey != null && !googleBooksApiKey.isBlank()) {
            Book book = tryGoogleBooks(isbn);
            if (book != null) {
                return book;
            }
        }
        return tryOpenLibrary(isbn);
    }

    @SuppressWarnings("unchecked")
    private Book tryGoogleBooks(String isbn) {
        try {
            Map<String, Object> response = googleClient.get()
                    .uri("/volumes?q=isbn:{isbn}&key={key}", isbn, googleBooksApiKey)
                    .retrieve()
                    .body(Map.class);

            if (response == null || !response.containsKey("items")) {
                return null;
            }

            List<Map<String, Object>> items = (List<Map<String, Object>>) response.get("items");
            if (items.isEmpty()) {
                return null;
            }

            Map<String, Object> volumeInfo = (Map<String, Object>) items.get(0).get("volumeInfo");

            Book book = new Book();
            book.setIsbn(isbn);
            book.setTitle((String) volumeInfo.getOrDefault("title", "Unknown Title"));

            List<String> authors = (List<String>) volumeInfo.get("authors");
            book.setAuthor(authors != null && !authors.isEmpty() ? String.join(", ", authors) : "Unknown Author");

            List<String> categories = (List<String>) volumeInfo.get("categories");
            if (categories != null && !categories.isEmpty()) {
                book.setGenre(categories.get(0));
                book.setTags(categories);
            } else {
                book.setTags(new ArrayList<>());
            }

            book.setDescription(cleanText((String) volumeInfo.get("description")));
            book.setCoverUrl(googleCover(volumeInfo, isbn));
            book.setPublisher((String) volumeInfo.get("publisher"));
            book.setPublishedDate((String) volumeInfo.get("publishedDate"));
            Object pages = volumeInfo.get("pageCount");
            if (pages instanceof Number n && n.intValue() > 0) book.setPageCount(n.intValue());

            return book;
        } catch (Exception e) {
            System.out.println("Google Books lookup failed: " + e.getMessage());
            return null;
        }
    }

    @SuppressWarnings("unchecked")
    private Book tryOpenLibrary(String isbn) {
        try {
            Map<String, Object> response = openLibraryClient.get()
                    .uri("/api/books?bibkeys=ISBN:{isbn}&format=json&jscmd=data", isbn)
                    .retrieve()
                    .body(Map.class);

            String key = "ISBN:" + isbn;
            if (response == null || !response.containsKey(key)) {
                return null;
            }

            Map<String, Object> data = (Map<String, Object>) response.get(key);

            Book book = new Book();
            book.setIsbn(isbn);
            book.setTitle((String) data.getOrDefault("title", "Unknown Title"));

            List<Map<String, Object>> authors = (List<Map<String, Object>>) data.get("authors");
            if (authors != null && !authors.isEmpty()) {
                List<String> names = authors.stream()
                        .map(a -> (String) a.get("name"))
                        .toList();
                book.setAuthor(String.join(", ", names));
            } else {
                book.setAuthor("Unknown Author");
            }

            List<Map<String, Object>> subjects = (List<Map<String, Object>>) data.get("subjects");
            if (subjects != null && !subjects.isEmpty()) {
                List<String> subjectNames = subjects.stream()
                        .map(s -> (String) s.get("name"))
                        .filter(Objects::nonNull)
                        .toList();
                book.setGenre(subjectNames.isEmpty() ? null : subjectNames.get(0));
                book.setTags(subjectNames);
            } else {
                book.setTags(new ArrayList<>());
            }

            Map<String, Object> cover = (Map<String, Object>) data.get("cover");
            String coverUrl = null;
            if (cover != null) {
                coverUrl = (String) (cover.get("medium") != null ? cover.get("medium") : cover.get("large"));
            }
            book.setCoverUrl(coverUrl != null ? coverUrl : openLibraryCover(isbn));

            List<Map<String, Object>> publishers = (List<Map<String, Object>>) data.get("publishers");
            if (publishers != null && !publishers.isEmpty()) {
                book.setPublisher((String) publishers.get(0).get("name"));
            }
            book.setPublishedDate((String) data.get("publish_date"));
            Object pages = data.get("number_of_pages");
            if (pages instanceof Number n && n.intValue() > 0) book.setPageCount(n.intValue());

            book.setDescription(fetchOpenLibraryDescription((String) data.get("key")));

            return book;
        } catch (Exception e) {
            System.out.println("Open Library lookup failed: " + e.getMessage());
            return null;
        }
    }

    public List<Book> searchByTag(String tag) {
        List<Book> results = googleSearchByTag(tag);
        if (!results.isEmpty()) {
            return results;
        }
        return openLibrarySearchByTag(tag);
    }

    @SuppressWarnings("unchecked")
    private List<Book> googleSearchByTag(String tag) {
        List<Book> results = new ArrayList<>();
        try {
            Map<String, Object> response = googleClient.get()
                    .uri("/volumes?q=subject:{tag}&maxResults=10"
                                    + (googleBooksApiKey != null && !googleBooksApiKey.isBlank() ? "&key={key}" : ""),
                            tag, googleBooksApiKey)
                    .retrieve()
                    .body(Map.class);

            if (response == null || !response.containsKey("items")) {
                return results;
            }

            List<Map<String, Object>> items = (List<Map<String, Object>>) response.get("items");
            for (Map<String, Object> item : items) {
                Map<String, Object> volumeInfo = (Map<String, Object>) item.get("volumeInfo");
                if (volumeInfo == null) {
                    continue;
                }

                List<String> isbns = extractIsbn(volumeInfo);
                if (isbns.isEmpty()) {
                    continue;
                }

                Book book = new Book();
                book.setIsbn(isbns.get(0));
                book.setTitle((String) volumeInfo.getOrDefault("title", "Unknown Title"));

                List<String> authors = (List<String>) volumeInfo.get("authors");
                book.setAuthor(authors != null && !authors.isEmpty() ? String.join(", ", authors) : "Unknown Author");

                List<String> categories = (List<String>) volumeInfo.get("categories");
                book.setTags(categories != null ? categories : List.of());
                book.setGenre(categories != null && !categories.isEmpty() ? categories.get(0) : null);
                book.setCoverUrl(googleCover(volumeInfo, book.getIsbn()));

                results.add(book);
            }
        } catch (Exception e) {
            System.out.println("googleSearchByTag failed for tag '" + tag + "': " + e.getMessage());
        }
        return results;
    }

    @SuppressWarnings("unchecked")
    private List<Book> openLibrarySearchByTag(String tag) {
        List<Book> results = new ArrayList<>();
        try {
            Map<String, Object> response = openLibraryClient.get()
                    .uri("/search.json?subject={tag}&fields=title,author_name,isbn,subject,cover_i&limit=10", tag)
                    .retrieve()
                    .body(Map.class);

            if (response == null || !response.containsKey("docs")) {
                return results;
            }

            List<Map<String, Object>> docs = (List<Map<String, Object>>) response.get("docs");
            for (Map<String, Object> doc : docs) {
                List<String> isbns = (List<String>) doc.get("isbn");
                if (isbns == null || isbns.isEmpty()) {
                    continue;
                }

                Book book = new Book();
                book.setIsbn(isbns.get(0));
                book.setTitle((String) doc.getOrDefault("title", "Unknown Title"));

                List<String> authorNames = (List<String>) doc.get("author_name");
                book.setAuthor(authorNames != null && !authorNames.isEmpty()
                        ? String.join(", ", authorNames) : "Unknown Author");

                List<String> subjects = (List<String>) doc.get("subject");
                book.setTags(subjects != null ? subjects : List.of());
                book.setGenre(subjects != null && !subjects.isEmpty() ? subjects.get(0) : tag);
                Object coverId = doc.get("cover_i");
                book.setCoverUrl(coverId != null
                        ? "https://covers.openlibrary.org/b/id/" + coverId + "-M.jpg"
                        : openLibraryCover(isbns.get(0)));

                results.add(book);
            }
        } catch (Exception e) {
            System.out.println("openLibrarySearchByTag failed for tag '" + tag + "': " + e.getMessage());
        }
        return results;
    }

    @SuppressWarnings("unchecked")
    private List<String> extractIsbn(Map<String, Object> volumeInfo) {
        List<Map<String, Object>> identifiers = (List<Map<String, Object>>) volumeInfo.get("industryIdentifiers");
        if (identifiers == null) {
            return List.of();
        }

        List<String> isbn13s = identifiers.stream()
                .filter(id -> "ISBN_13".equals(id.get("type")))
                .map(id -> (String) id.get("identifier"))
                .filter(Objects::nonNull)
                .toList();
        if (!isbn13s.isEmpty()) {
            return isbn13s;
        }

        return identifiers.stream()
                .filter(id -> "ISBN_10".equals(id.get("type")))
                .map(id -> (String) id.get("identifier"))
                .filter(Objects::nonNull)
                .toList();
    }
}
