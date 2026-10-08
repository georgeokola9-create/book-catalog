import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'book.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  static const String baseUrl = 'http://localhost:8080';

  late Book _book;
  bool _isSaving = false;
  String? _errorMessage;

  static const List<String> _statusOptions = ['TO_READ', 'READING', 'FINISHED'];

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'TO_READ':
        return 'To Read';
      case 'READING':
        return 'Reading';
      case 'FINISHED':
        return 'Finished';
      default:
        return status;
    }
  }

  Future<void> _updateBook({int? rating, String? status}) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final requestBody = <String, Object>{};
      if (rating != null) {
        requestBody['rating'] = rating;
      }
      if (status != null) {
        requestBody['status'] = status;
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/books/${_book.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final updated = Book.fromJson(jsonDecode(response.body));
        setState(() {
          _book = updated;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to update (status ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: could not reach the server';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_book.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_book.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              _book.author,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'ISBN: ${_book.isbn}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_book.genre != null) ...[
              const SizedBox(height: 8),
              Chip(label: Text(_book.genre!)),
            ],
            if (_book.description != null && _book.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _book.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            Text('Your Rating', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                final starValue = index + 1;
                final filled =
                    _book.rating != null && starValue <= _book.rating!;
                return IconButton(
                  icon: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: _isSaving
                      ? null
                      : () => _updateBook(rating: starValue),
                );
              }),
            ),
            const SizedBox(height: 16),
            Text('Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _statusOptions.map((status) {
                final selected = _book.status == status;
                return ChoiceChip(
                  label: Text(_statusLabel(status)),
                  selected: selected,
                  onSelected: _isSaving
                      ? null
                      : (_) => _updateBook(status: status),
                );
              }).toList(),
            ),
            if (_isSaving) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
