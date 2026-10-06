import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('shows catalog screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BookCatalogApp());

    expect(find.text('My Catalog'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });
}
