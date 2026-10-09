import 'package:flutter/material.dart';

import 'home_shell.dart';
import 'theme.dart';

void main() {
  runApp(const BookCatalogApp());
}

class BookCatalogApp extends StatelessWidget {
  const BookCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Catalog',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeShell(),
    );
  }
}
