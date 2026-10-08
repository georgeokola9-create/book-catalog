class Book {
  final int? id; // null for recommendations that are not in the library yet
  final String isbn;
  final String title;
  final String author;
  final String? genre;
  final String? description;
  final int? rating;
  final String? status;
  final List<String> tags;

  const Book({
    required this.id,
    required this.isbn,
    required this.title,
    required this.author,
    this.genre,
    this.description,
    this.rating,
    this.status,
    this.tags = const [],
  });

  bool get isOwned => id != null;

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: (json['id'] as num?)?.toInt(),
      isbn: json['isbn'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown Author',
      genre: json['genre'] as String?,
      description: json['description'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      status: json['status'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const [],
    );
  }
}
