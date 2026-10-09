import 'package:flutter/material.dart';

import 'api_service.dart';
import 'book.dart';
import 'book_detail_screen.dart';
import 'widgets.dart';

class RecommendationsScreen extends StatefulWidget {
  final int refreshToken;

  const RecommendationsScreen({super.key, this.refreshToken = 0});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final ApiService _apiService = const ApiService();
  late Future<List<Book>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _booksFuture = _apiService.fetchRecommendations();
  }

  @override
  void didUpdateWidget(covariant RecommendationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final booksFuture = _apiService.fetchRecommendations();
    setState(() => _booksFuture = booksFuture);
    await booksFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recommendations')),
      body: FutureBuilder<List<Book>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ErrorState(
              title: 'Could not load recommendations.',
              details: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final books = snapshot.data ?? [];
          if (books.isEmpty) {
            return EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'No recommendations yet',
              message:
                  'Rate a few books 4 or 5 stars to build your taste profile.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: books.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final book = books[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: BookCover(
                    title: book.title,
                    coverUrl: book.coverUrl,
                    width: 52,
                  ),
                  title: Text(book.title),
                  subtitle: Text(
                    [book.author, book.genre].whereType<String>().join(' - '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookDetailScreen(book: book),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
