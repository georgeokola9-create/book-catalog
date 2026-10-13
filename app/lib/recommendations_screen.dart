import 'package:flutter/material.dart';

import 'api_service.dart';
import 'book.dart';
import 'book_detail_screen.dart';
import 'widgets.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<Book> _books = [];
  bool _loading = true;
  String? _error;

  bool _stale = false; // library changed since these picks were made
  bool _selfChange = false; // true while this screen is adding a book itself
  final Set<String> _adding = {};

  @override
  void initState() {
    super.initState();
    libraryVersion.addListener(_onLibraryChanged);
    _load();
  }

  @override
  void dispose() {
    libraryVersion.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    if (_selfChange || !mounted) return;
    setState(() => _stale = true);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _stale = false;
    });
    try {
      final books = await ApiService.instance.fetchRecommendations();
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _add(Book book) async {
    setState(() => _adding.add(book.isbn));
    _selfChange = true;
    try {
      await ApiService.instance.scanIsbn(book.isbn);
      if (!mounted) return;
      setState(() => _books = _books.where((b) => b.isbn != book.isbn).toList());
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${book.title}" added to your library')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      _selfChange = false;
      if (mounted) setState(() => _adding.remove(book.isbn));
    }
  }

  void _open(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('For you'),
        actions: [
          IconButton(
            tooltip: 'Refresh recommendations',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: ContentWidth(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(
        message:
            'Finding books you might like...\nThe first search can take up to a minute.',
      );
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_books.isEmpty) {
      return const EmptyView(
        icon: Icons.auto_awesome_outlined,
        title: 'No recommendations right now',
        message:
            'Rate at least one book 4 stars or higher, then tap refresh to get picks.',
      );
    }

    final theme = Theme.of(context);
    return Column(
      children: [
        if (_stale)
          Material(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your library changed. Refresh for updated picks.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Refresh')),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: _books.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    'Picked from the books you rated highly',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return _RecommendationTile(
                book: _books[i - 1],
                adding: _adding.contains(_books[i - 1].isbn),
                onTap: () => _open(_books[i - 1]),
                onAdd: () => _add(_books[i - 1]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final Book book;
  final bool adding;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _RecommendationTile({
    required this.book,
    required this.adding,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final synopsis = book.description?.trim() ?? '';

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(title: book.title, coverUrl: book.coverUrl, width: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                if (synopsis.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(synopsis,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                ],
                if (book.genre != null) ...[
                  const SizedBox(height: 6),
                  Text(book.genre!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: adding
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : IconButton.filledTonal(
                      tooltip: 'Add to library',
                      icon: const Icon(Icons.add),
                      onPressed: onAdd,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
