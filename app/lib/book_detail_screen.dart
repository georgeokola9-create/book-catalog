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
  late Book _book;
  String? _saving; // 'rating' or 'status' while a request is in flight
  bool _deleting = false;

  bool get _busy => _saving != null || _deleting;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _update({int? rating, String? status}) async {
    setState(() => _saving = rating != null ? 'rating' : 'status');
    try {
      final updated = await ApiService.instance.updateBook(
        _book.id!,
        rating: rating,
        status: status,
      );
      if (!mounted) return;
      setState(() => _book = updated);
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this book?'),
        content: Text('"${_book.title}" will be removed from your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 40),
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ApiService.instance.deleteBook(_book.id!);
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = _book.tags.take(8).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book details'),
        actions: [
          IconButton(
            tooltip: 'Remove book',
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _confirmDelete,
          ),
        ],
      ),
      body: Stack(
        children: [
          ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookAvatar(title: _book.title, size: 72),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _book.title,
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _book.author,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              'ISBN ${_book.isbn}',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (_book.genre != null) ...[
                              const SizedBox(height: 10),
                              Chip(
                                label: Text(_book.genre!),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('Your rating', loading: _saving == 'rating'),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (i) {
                          final value = i + 1;
                          final filled =
                              _book.rating != null && value <= _book.rating!;
                          return IconButton(
                            tooltip: 'Rate $value out of 5',
                            iconSize: 34,
                            visualDensity: VisualDensity.compact,
                            onPressed: _busy ? null : () => _update(rating: value),
                            icon: Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: Colors.amber,
                            ),
                          );
                        }),
                      ),
                      Text(
                        _book.rating == null
                            ? 'Tap a star to rate this book'
                            : '${_book.rating} out of 5',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        'Reading status',
                        loading: _saving == 'status',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          emptySelectionAllowed: true,
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 'TO_READ', label: Text('To read')),
                            ButtonSegment(value: 'READING', label: Text('Reading')),
                            ButtonSegment(
                              value: 'FINISHED',
                              label: Text('Finished'),
                            ),
                          ],
                          selected:
                              _book.status == null ? <String>{} : {_book.status!},
                          onSelectionChanged: _busy
                              ? null
                              : (s) {
                                  if (s.isNotEmpty) _update(status: s.first);
                                },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_book.description != null && _book.description!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('About'),
                        const SizedBox(height: 8),
                        Text(_book.description!, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Topics'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in tags)
                              Chip(
                                label: Text(t),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_deleting) ...[
            const ModalBarrier(dismissible: false, color: Colors.black26),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool loading;
  const _SectionTitle(this.text, {this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (loading) ...[
          const SizedBox(width: 10),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }
}
