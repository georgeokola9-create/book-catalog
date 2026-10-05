import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isProcessing = false;
  String? _statusMessage;
  Map<String, dynamic>? _lastScannedBook;

  // NOTE: 10.0.2.2 is the special alias Android emulators use to reach
  // "localhost" on your actual computer. For Chrome/web testing, use
  // localhost directly instead. We'll make this configurable later.
  static const String baseUrl = 'http://localhost:8080';

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return; // debounce: ignore scans while one is in flight

    final barcode = capture.barcodes.firstOrNull;
    final isbn = barcode?.rawValue;
    if (isbn == null || isbn.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Looking up ISBN $isbn...';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/books/scan?isbn=$isbn'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final book = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _lastScannedBook = book;
          _statusMessage = response.statusCode == 201
              ? 'Added: ${book['title']}'
              : 'Already in your catalog: ${book['title']}';
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _statusMessage = 'No book found for ISBN $isbn';
        });
      } else {
        setState(() {
          _statusMessage =
              'Something went wrong (status ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Network error: could not reach the server';
      });
    } finally {
      // Small delay before allowing another scan, so the same barcode
      // isn't immediately re-scanned while still in view of the camera
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a Book')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              onDetect: _handleBarcode,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _statusMessage ??
                              'Point the camera at a book barcode',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_lastScannedBook != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _lastScannedBook!['author'] ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
