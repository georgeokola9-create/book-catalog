package com.bookcatalog.backend;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
public class GoogleBooksService {

    private final RestClient googleClient = RestClient.create("https://www.googleapis.com/books/v1");
    private final RestClient openLibraryClient = RestClient.create("https://openlibrary.org");

    @Value("${google.books.api.key:}")
    private String googleBooksApiKey;

    public Book lookupByIsbn(String isbn) {
        System.out.println("DEBUG - Google Books API key loaded as: [" + googleBooksApiKey + "]");
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
            book.setGenre(categories != null && !categories.isEmpty() ? categories.get(0) : null);

            book.setDescription((String) volumeInfo.get("description"));

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
                book.setGenre((String) subjects.get(0).get("name"));
            }

            return book;
        } catch (Exception e) {
            System.out.println("Open Library lookup failed: " + e.getMessage());
            return null;
        }
    }
}
