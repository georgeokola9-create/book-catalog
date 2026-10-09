import 'package:flutter/material.dart';

import 'api_service.dart';
import 'book.dart';
import 'widgets.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final ApiService _apiService = const ApiService();
  late Book _book;
  bool _isSaving = false;
  bool _refreshing = false;
  String? _errorMessage;

  bool get _busy => _isSaving || _refreshing;

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _fetchDetails() async {
    final id = _book.id;
    if (id == null) return;

    setState(() {
      _refreshing = true;
      _errorMessage = null;
    });

    try {
      final updated = await _apiService.refreshBook(id);
      if (!mounted) return;
      setState(() => _book = updated);
      if (updated.description == null || updated.description!.isEmpty) {
        _showMessage('No synopsis is available for this book.');
      }
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _updateBook({int? rating, String? status}) async {
    final id = _book.id;
    if (id == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updated = await _apiService.updateBook(
        id,
        rating: rating,
        status: status,
      );
      setState(() => _book = updated);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_book.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(
                  title: _book.title,
                  coverUrl: _book.coverUrl,
                  width: 96,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_book.title, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        _book.author,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ISBN: ${_book.isbn}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Builder(
                        builder: (context) {
                          final meta = [
                            if (_book.publisher != null) _book.publisher!,
                            if (_book.publishedDate != null)
                              _book.publishedDate!,
                            if (_book.pageCount != null)
                              '${_book.pageCount} pages',
                          ].join(' - ');
                          if (meta.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(meta, style: theme.textTheme.bodySmall),
                          );
                        },
                      ),
                      if (_book.genre != null) ...[
                        const SizedBox(height: 8),
                        Chip(label: Text(_book.genre!)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Synopsis', style: theme.textTheme.titleMedium),
                        if (_refreshing) ...[
                          const SizedBox(width: 10),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_book.description != null &&
                        _book.description!.isNotEmpty)
                      _ExpandableText(_book.description!)
                    else ...[
                      Text(
                        'No synopsis saved for this book yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _fetchDetails,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Fetch details'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Your Rating', style: theme.textTheme.titleMedium),
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
                  onPressed: _busy
                      ? null
                      : () => _updateBook(rating: starValue),
                );
              }),
            ),
            const SizedBox(height: 16),
            Text('Status', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _statusOptions.map((status) {
                final selected = _book.status == status;
                return ChoiceChip(
                  label: Text(_statusLabel(status)),
                  selected: selected,
                  onSelected: _busy ? null : (_) => _updateBook(status: status),
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

class _ExpandableText extends StatefulWidget {
  final String text;

  const _ExpandableText(this.text);

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.text.length > 280;
    final collapsed = isLong && !_expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: collapsed ? 5 : null,
          overflow: collapsed ? TextOverflow.ellipsis : TextOverflow.visible,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        if (isLong)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
      ],
    );
  }
}
