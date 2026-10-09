import 'package:flutter/material.dart';

import 'catalog_screen.dart';
import 'recommendations_screen.dart';
import 'scan_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  int _catalogVersion = 0;
  int _recommendationsVersion = 0;

  void _refreshTabs() {
    setState(() {
      _catalogVersion++;
      _recommendationsVersion++;
    });
  }

  Future<void> _openScanner() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => const ScanScreen()),
    );
    if (mounted) {
      _refreshTabs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CatalogScreen(refreshToken: _catalogVersion),
      RecommendationsScreen(refreshToken: _recommendationsVersion),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      floatingActionButton: FloatingActionButton(
        onPressed: _openScanner,
        tooltip: 'Scan ISBN',
        child: const Icon(Icons.qr_code_scanner),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Catalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Recommendations',
          ),
        ],
      ),
    );
  }
}
