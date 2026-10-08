import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'api_service.dart';
import 'isbn_utils.dart';
import 'widgets.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  bool _busy = false;
  ScanOutcome? _outcome;
  String? _error;

  String? _lastIsbn;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup(String isbn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _outcome = null;
    });
    try {
      final outcome = await ApiService.instance.scanIsbn(isbn);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _outcome = outcome);
      _controller.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final isbn = normalizeIsbn(raw);
    if (!isValidIsbn(isbn)) return; // ignore non-book or misread barcodes

    final now = DateTime.now();
    if (isbn == _lastIsbn && now.difference(_lastScanAt).inSeconds < 4) return;
    _lastIsbn = isbn;
    _lastScanAt = now;
    _lookup(isbn);
  }

  void _submitManual() {
    if (_formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    _lookup(normalizeIsbn(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add a book')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (kIsWeb)
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Camera scanning is available in the mobile app. '
                        'Enter an ISBN below to add a book.',
                      ),
                    ),
                  ],
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 280,
                  child: Stack(
                    children: [
                      MobileScanner(onDetect: _onDetect),
                      Center(
                        child: Container(
                          width: 250,
                          height: 140,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Text(
                          'Point the camera at the barcode on the back cover',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                      if (_busy)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black54,
                            child: Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Or enter the ISBN manually',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _controller,
                enabled: !_busy,
                textInputAction: TextInputAction.search,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9xX\- ]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'ISBN',
                  hintText: '9780140328721',
                  prefixIcon: Icon(Icons.tag),
                ),
                validator: (v) => isValidIsbn(normalizeIsbn(v ?? ''))
                    ? null
                    : 'Enter a valid 10 or 13 digit ISBN',
                onFieldSubmitted: (_) => _submitManual(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _submitManual,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_busy ? 'Looking up...' : 'Look up book'),
            ),
            if (_outcome != null) ...[
              const SizedBox(height: 20),
              _ResultCard(outcome: _outcome!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 20),
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ScanOutcome outcome;
  const _ResultCard({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = outcome.book;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                outcome.isNew ? Icons.check_circle : Icons.info,
                color: outcome.isNew ? Colors.green : theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                outcome.isNew ? 'Added to your library' : 'Already in your library',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
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
                    Text(book.author, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
