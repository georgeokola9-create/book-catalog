class Book {
  final int id;
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

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as int,
      isbn: json['isbn'] as String,
      title: json['title'] as String,
      author: json['author'] as String? ?? 'Unknown Author',
      genre: json['genre'] as String?,
      description: json['description'] as String?,
      rating: json['rating'] as int?,
      status: json['status'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
    );
  }
}
