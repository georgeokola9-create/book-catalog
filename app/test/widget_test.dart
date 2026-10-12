import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('shows catalog screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BookCatalogApp());

    expect(find.text('My Library'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
