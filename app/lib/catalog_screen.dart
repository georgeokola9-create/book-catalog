import 'package:flutter/material.dart';

import 'api_service.dart';
import 'book.dart';
import 'book_detail_screen.dart';
import 'scan_screen.dart';
import 'widgets.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Book> _books = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _statusFilter;

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

  void _onLibraryChanged() => _load(showSpinner: false);

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final books = await ApiService.instance.fetchBooks();
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_books.isEmpty) _error = e.message;
      });
      if (_books.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _openScan() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanScreen()),
      );

  List<Book> get _visible {
    final q = _query.trim().toLowerCase();
    return _books.where((b) {
      final matchesQuery = q.isEmpty ||
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q);
      final matchesStatus = _statusFilter == null || b.status == _statusFilter;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Library')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScan,
        icon: const Icon(Icons.add),
        label: const Text('Add book'),
      ),
      body: ContentWidth(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(message: 'Loading your library...');
    }
    if (_error != null && _books.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_books.isEmpty) {
      return EmptyView(
        icon: Icons.menu_book_outlined,
        title: 'Your library is empty',
        message: 'Scan a barcode or enter an ISBN to add your first book.',
        actionLabel: 'Add your first book',
        onAction: _openScan,
      );
    }

    final visible = _visible;
    final finished = _books.where((b) => b.status == 'FINISHED').length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search by title or author',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _query = ''),
                    ),
            ),
            controller: TextEditingController.fromValue(
              TextEditingValue(
                text: _query,
                selection: TextSelection.collapsed(offset: _query.length),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _filterChip('All', null),
              _filterChip('To read', 'TO_READ'),
              _filterChip('Reading', 'READING'),
              _filterChip('Finished', 'FINISHED'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_books.length} ${_books.length == 1 ? 'book' : 'books'}, $finished finished',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(showSpinner: false),
            child: visible.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyView(
                        icon: Icons.search_off,
                        title: 'No matches',
                        message: 'Try a different search or filter.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _BookTile(
                      book: visible[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookDetailScreen(book: visible[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _statusFilter == value,
        onSelected: (_) => setState(() => _statusFilter = value),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  const _BookTile({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
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
                if (book.status != null) ...[
                  const SizedBox(height: 8),
                  StatusBadge(status: book.status),
                ],
              ],
            ),
          ),
          if (book.rating != null) ...[
            const SizedBox(width: 8),
            Semantics(
              label: 'Rated ${book.rating} out of 5',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 20, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text('${book.rating}', style: theme.textTheme.labelLarge),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
