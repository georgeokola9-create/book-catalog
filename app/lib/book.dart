class Book {
  final int? id;
  final String isbn;
  final String title;
  final String author;
  final String? genre;
  final String? description;
  final String? coverUrl;
  final String? publisher;
  final String? publishedDate;
  final int? pageCount;
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
    this.coverUrl,
    this.publisher,
    this.publishedDate,
    this.pageCount,
    this.rating,
    this.status,
    this.tags = const [],
  });

  bool get isOwned => id != null;

  String? get statusLabel {
    switch (status) {
      case 'TO_READ':
        return 'To Read';
      case 'READING':
        return 'Reading';
      case 'FINISHED':
        return 'Finished';
      case null:
      case '':
        return null;
      default:
        return status;
    }
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: (json['id'] as num?)?.toInt(),
      isbn: json['isbn'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown Author',
      genre: json['genre'] as String?,
      description: json['description'] as String?,
      coverUrl: json['coverUrl'] as String?,
      publisher: json['publisher'] as String?,
      publishedDate: json['publishedDate'] as String?,
      pageCount: (json['pageCount'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toInt(),
      status: json['status'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}
