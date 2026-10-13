import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'book.dart';
import 'config.dart';
import 'isbn_utils.dart';

class ApiService {
  const ApiService();

  static const instance = ApiService();
  static final http.Client _client = http.Client();
  static const Duration _scanTimeout = Duration(seconds: 15);

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(apiBaseUrl);
    return base.replace(
      path: '${base.path}$path',
      queryParameters: query,
    );
  }

  Future<T> _run<T>(
    Future<T> Function() action, {
    Duration? timeout,
  }) {
    final future = action();
    return timeout == null ? future : future.timeout(timeout);
  }

  Object? _json(http.Response response) => jsonDecode(response.body);

  void _ensureOk(http.Response response, String message) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('$message (status ${response.statusCode})');
    }
  }

  Future<List<Book>> fetchBooks() async {
    final response = await _client.get(_uri('/books'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load books (status ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((json) => Book.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Book>> fetchRecommendations({int limit = 8}) async {
    final response = await _client.get(
      _uri('/recommendations', {'limit': '$limit'}),
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
    final response = await _client.post(
      _uri('/books/scan', {'isbn': isbn}),
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
    final response = await _client.post(
      _uri('/books/$id/refresh'),
    );
    if (response.statusCode != 200) {
      throw ApiException('Could not fetch book details');
    }

    return Book.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Fetches book details without saving the book.
  Future<Book?> lookupIsbn(String isbn) async {
    final res = await _run(
      () => _client.get(_uri('/books/lookup', {'isbn': isbn})),
      timeout: _scanTimeout,
    );
    if (res.statusCode == 404) return null;
    _ensureOk(res, 'Could not load book details');
    return Book.fromJson(_json(res) as Map<String, dynamic>);
  }

  Future<Book> updateBook(int id, {int? rating, String? status}) async {
    final requestBody = <String, Object>{};
    if (rating != null) requestBody['rating'] = rating;
    if (status != null) requestBody['status'] = status;

    final response = await _client.patch(
      _uri('/books/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to update (status ${response.statusCode})');
    }

    return Book.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteBook(int id) async {
    final response = await _client.delete(_uri('/books/$id'));
    if (response.statusCode != 204) {
      throw ApiException('Failed to delete (status ${response.statusCode})');
    }
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
