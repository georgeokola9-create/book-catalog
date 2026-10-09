import 'dart:convert';

import 'package:http/http.dart' as http;

import 'book.dart';
import 'config.dart';
import 'isbn_utils.dart';

class ApiService {
  const ApiService();

  static const instance = ApiService();

  Future<List<Book>> fetchBooks() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/books'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load books (status ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((json) => Book.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Book>> fetchRecommendations({int limit = 8}) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/recommendations?limit=$limit'),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load recommendations (status ${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((json) => Book.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Book> scanBook(String rawIsbn) async {
    final outcome = await scanIsbn(rawIsbn);
    return outcome.book;
  }

  Future<ScanOutcome> scanIsbn(String rawIsbn) async {
    final isbn = normalizeIsbn(rawIsbn);
    final response = await http.post(
      Uri.parse('$apiBaseUrl/books/scan?isbn=$isbn'),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ScanOutcome(
        book: Book.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
        isNew: response.statusCode == 201,
      );
    }
    if (response.statusCode == 404) {
      throw ApiException('No book found for ISBN $isbn');
    }
    throw ApiException('Scan failed (status ${response.statusCode})');
  }

  Future<Book> refreshBook(int id) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/books/$id/refresh'),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not fetch book details');
    }

    return Book.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Book> updateBook(int id, {int? rating, String? status}) async {
    final requestBody = <String, Object>{};
    if (rating != null) requestBody['rating'] = rating;
    if (status != null) requestBody['status'] = status;

    final response = await http.patch(
      Uri.parse('$apiBaseUrl/books/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to update (status ${response.statusCode})');
    }

    return Book.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class ScanOutcome {
  final Book book;
  final bool isNew;

  const ScanOutcome({required this.book, required this.isNew});
}

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}
