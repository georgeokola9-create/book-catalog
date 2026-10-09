import 'package:flutter/material.dart';

import 'api_service.dart';
import 'book.dart';
import 'book_detail_screen.dart';
import 'widgets.dart';

class CatalogScreen extends StatefulWidget {
  final int refreshToken;

  const CatalogScreen({super.key, this.refreshToken = 0});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final ApiService _apiService = const ApiService();
  late Future<List<Book>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _booksFuture = _apiService.fetchBooks();
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final booksFuture = _apiService.fetchBooks();
    setState(() => _booksFuture = booksFuture);
    await booksFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Catalog')),
      body: FutureBuilder<List<Book>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ErrorState(
              title: 'Could not load your catalog.',
              details: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final books = snapshot.data ?? [];
          if (books.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book,
              title: 'No books yet',
              message: 'Scan one to get started.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: books.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return _BookTile(book: books[index], onChanged: _refresh);
              },
            ),
          );
        },
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final Book book;
  final Future<void> Function() onChanged;

  const _BookTile({required this.book, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: BookCover(title: book.title, coverUrl: book.coverUrl, width: 52),
      title: Text(book.title),
      subtitle: Text(
        [book.author, book.statusLabel].whereType<String>().join(' - '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: book.rating != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                Text(' ${book.rating}'),
              ],
            )
          : null,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookDetailScreen(book: book)),
        );
        await onChanged();
      },
    );
  }
}
