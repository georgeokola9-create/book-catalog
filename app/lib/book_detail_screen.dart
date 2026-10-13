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
  String? _saving; // 'rating' or 'status' while a save is in flight
  bool _deleting = false;
  bool _loadingDetails = false;
  bool _adding = false;

  bool get _busy => _saving != null || _deleting || _loadingDetails || _adding;
  bool get _hasSynopsis =>
      _book.description != null && _book.description!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    // Recommended books are not saved yet, so load their synopsis automatically.
    if (!_book.isOwned && !_hasSynopsis) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _loadDetails(announce: false));
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _loadDetails({bool announce = true}) async {
    setState(() => _loadingDetails = true);
    try {
      final Book? fetched = _book.isOwned
          ? await ApiService.instance.refreshBook(_book.id!)
          : await ApiService.instance.lookupIsbn(_book.isbn);
      if (!mounted) return;
      if (fetched == null) {
        if (announce) _showMessage('No details were found for this book.');
        return;
      }
      setState(() {
        _book = _book.isOwned ? fetched : _book.withDetailsFrom(fetched);
      });
      if (announce && !_hasSynopsis) {
        _showMessage('No synopsis is available for this book.');
      }
    } on ApiException catch (e) {
      if (announce) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Future<void> _addToLibrary() async {
    setState(() => _adding = true);
    try {
      final outcome = await ApiService.instance.scanIsbn(_book.isbn);
      if (!mounted) return;
      // Keep the synopsis we already loaded while the book was unsaved.
      setState(() => _book = outcome.book.withDetailsFrom(_book));
      _showMessage('Added to your library');
    } on ApiException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _update({int? rating, String? status}) async {
    setState(() => _saving = rating != null ? 'rating' : 'status');
    try {
      final updated = await ApiService.instance
          .updateBook(_book.id!, rating: rating, status: status);
      if (!mounted) return;
      setState(() => _book = updated.withDetailsFrom(_book));
    } on ApiException catch (e) {
      _showMessage(e.message);
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
              child: const Text('Cancel')),
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
    final meta = [
      if (_book.publisher != null) _book.publisher!,
      if (_book.publishedDate != null) _book.publishedDate!,
      if (_book.pageCount != null) '${_book.pageCount} pages',
    ].join(' | ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book details'),
        actions: [
          if (_book.isOwned)
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
                      BookCover(
                          title: _book.title,
                          coverUrl: _book.coverUrl,
                          width: 96),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_book.title,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(_book.author,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            SelectableText('ISBN ${_book.isbn}',
                                style: theme.textTheme.bodySmall),
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(meta, style: theme.textTheme.bodySmall),
                            ],
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
                      _SectionTitle('Synopsis', loading: _loadingDetails),
                      const SizedBox(height: 8),
                      if (_hasSynopsis)
                        _ExpandableText(_book.description!)
                      else if (_loadingDetails)
                        Text('Looking for a synopsis...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant))
                      else ...[
                        Text('No synopsis saved for this book yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _loadDetails,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Fetch details'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!_book.isOwned)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Not in your library yet',
                            loading: _adding),
                        const SizedBox(height: 6),
                        Text(
                          'Add this book to rate it and track your reading.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _busy ? null : _addToLibrary,
                          icon: const Icon(Icons.add),
                          label: Text(_adding ? 'Adding...' : 'Add to library'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Your rating',
                            loading: _saving == 'rating'),
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
                              onPressed:
                                  _busy ? null : () => _update(rating: value),
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
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Reading status',
                            loading: _saving == 'status'),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            emptySelectionAllowed: true,
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                  value: 'TO_READ', label: Text('To read')),
                              ButtonSegment(
                                  value: 'READING', label: Text('Reading')),
                              ButtonSegment(
                                  value: 'FINISHED', label: Text('Finished')),
                            ],
                            selected: _book.status == null
                                ? <String>{}
                                : {_book.status!},
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
        Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        if (loading) ...[
          const SizedBox(width: 10),
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ],
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
