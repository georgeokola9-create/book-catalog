import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'book.dart';
import 'config.dart';

/// Bumped whenever the library changes, so any screen can reload itself.
final ValueNotifier<int> libraryVersion = ValueNotifier<int>(0);
void _notifyLibraryChanged() => libraryVersion.value++;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ScanOutcome {
  final Book book;
  final bool isNew;
  const ScanOutcome(this.book, this.isNew);
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();

  static const _timeout = Duration(seconds: 15);
  static const _scanTimeout = Duration(seconds: 45);
  static const _recommendationTimeout = Duration(seconds: 120);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);

  Future<http.Response> _run(
    Future<http.Response> Function() request, {
    Duration timeout = _timeout,
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Cannot reach the server. Check that the backend is running.');
    }
  }

  void _ensureOk(http.Response res, String fallback) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        '$fallback (status ${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }
  }

  // Decode as UTF-8 explicitly so non-Latin titles are not garbled.
  dynamic _json(http.Response res) => jsonDecode(utf8.decode(res.bodyBytes));

  Future<List<Book>> fetchBooks() async {
    final res = await _run(() => _client.get(_uri('/books')));
    _ensureOk(res, 'Could not load your library');
    return (_json(res) as List<dynamic>)
        .map((e) => Book.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ScanOutcome> scanIsbn(String isbn) async {
    final res = await _run(
      () => _client.post(_uri('/books/scan', {'isbn': isbn})),
      timeout: _scanTimeout,
    );
    if (res.statusCode == 404) {
      throw ApiException('No book found for ISBN $isbn.', statusCode: 404);
    }
    _ensureOk(res, 'Could not add this book');
    final book = Book.fromJson(_json(res) as Map<String, dynamic>);
    final isNew = res.statusCode == 201;
    if (isNew) _notifyLibraryChanged();
    return ScanOutcome(book, isNew);
  }

  Future<Book> updateBook(int id, {int? rating, String? status}) async {
    final res = await _run(
      () => _client.patch(
        _uri('/books/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (rating != null) 'rating': rating,
          if (status != null) 'status': status,
        }),
      ),
    );
    _ensureOk(res, 'Could not save your changes');
    final book = Book.fromJson(_json(res) as Map<String, dynamic>);
    _notifyLibraryChanged();
    return book;
  }

  Future<void> deleteBook(int id) async {
    final res = await _run(() => _client.delete(_uri('/books/$id')));
    _ensureOk(res, 'Could not delete this book');
    _notifyLibraryChanged();
  }

  Future<List<Book>> fetchRecommendations({int limit = 10}) async {
    final res = await _run(
      () => _client.get(_uri('/recommendations', {'limit': '$limit'})),
      timeout: _recommendationTimeout,
    );
    _ensureOk(res, 'Could not load recommendations');
    return (_json(res) as List<dynamic>)
        .map((e) => Book.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
