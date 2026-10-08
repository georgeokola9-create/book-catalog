import 'package:flutter/material.dart';

import 'api_service.dart';
import 'book.dart';
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

  final Set<String> _adding = {};
  final Set<String> _added = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final books = await ApiService.instance.fetchRecommendations();
      if (!mounted) return;
      setState(() {
        _books = books;
        _added.clear();
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
    try {
      await ApiService.instance.scanIsbn(book.isbn);
      if (!mounted) return;
      setState(() => _added.add(book.isbn));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${book.title}" added to your library')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _adding.remove(book.isbn));
    }
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
        message: 'Finding books you might like...',
        hint: 'This can take up to a minute.',
      );
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_books.isEmpty) {
      return const EmptyView(
        icon: Icons.auto_awesome_outlined,
        title: 'No recommendations yet',
        message: 'Rate at least one book 4 stars or higher, then check back.',
      );
    }

    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _books.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Picked from the books you rated highly',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        final book = _books[i - 1];
        final adding = _adding.contains(book.isbn);
        final added = _added.contains(book.isbn);

        return AppCard(
          child: Row(
            children: [
              BookAvatar(title: book.title),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (book.genre != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        book.genre!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
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
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : added
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : IconButton.filledTonal(
                              tooltip: 'Add to library',
                              icon: const Icon(Icons.add),
                              onPressed: () => _add(book),
                            ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
