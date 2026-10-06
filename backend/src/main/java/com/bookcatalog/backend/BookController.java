package com.bookcatalog.backend;

import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/books")
public class BookController {

    private final BookRepository bookRepository;
    private final GoogleBooksService googleBooksService;

    public BookController(BookRepository bookRepository, GoogleBooksService googleBooksService) {
        this.bookRepository = bookRepository;
        this.googleBooksService = googleBooksService;
    }

    @GetMapping
    public List<Book> getAllBooks() {
        return bookRepository.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Book> getBookById(@PathVariable Long id) {
        return bookRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Book> createBook(@Valid @RequestBody Book book) {
        if (bookRepository.existsByIsbn(book.getIsbn())) {
            return ResponseEntity.status(HttpStatus.CONFLICT).build();
        }
        Book saved = bookRepository.save(book);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    @PostMapping("/scan")
    public ResponseEntity<Book> scanBook(@RequestParam String isbn) {
        var existing = bookRepository.findByIsbn(isbn);
        if (existing.isPresent()) {
            return ResponseEntity.ok(existing.get());
        }

        Book book = googleBooksService.lookupByIsbn(isbn);
        if (book == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        Book saved = bookRepository.save(book);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    @PatchMapping("/{id}")
    public ResponseEntity<Book> updateBook(@PathVariable Long id, @RequestBody Book updates) {
        return bookRepository.findById(id)
                .map(existing -> {
                    if (updates.getRating() != null) {
                        existing.setRating(updates.getRating());
                    }
                    if (updates.getStatus() != null) {
                        existing.setStatus(updates.getStatus());
                    }
                    if (updates.getTitle() != null) {
                        existing.setTitle(updates.getTitle());
                    }
                    if (updates.getAuthor() != null) {
                        existing.setAuthor(updates.getAuthor());
                    }
                    if (updates.getGenre() != null) {
                        existing.setGenre(updates.getGenre());
                    }
                    if (updates.getDescription() != null) {
                        existing.setDescription(updates.getDescription());
                    }
                    Book saved = bookRepository.save(existing);
                    return ResponseEntity.ok(saved);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteBook(@PathVariable Long id) {
        if (!bookRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        bookRepository.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}
