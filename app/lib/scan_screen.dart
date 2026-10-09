import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'api_service.dart';
import 'book.dart';
import 'isbn_utils.dart';
import 'widgets.dart';

enum _SheetAction { scanAnother, done }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _camera = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
    facing: CameraFacing.back,
  );

  final _formKey = GlobalKey<FormState>();
  final _isbnController = TextEditingController();

  bool _lookingUp = false;
  String? _error;

  @override
  void dispose() {
    _camera.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    try {
      await _camera.start();
    } catch (_) {
      // Already running, nothing to do.
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _camera.stop();
    } catch (_) {
      // Already stopped, nothing to do.
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_lookingUp) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final isbn = normalizeIsbn(raw);
    if (!isValidIsbn(isbn)) return; // ignore misreads and non-book barcodes
    _lookup(isbn);
  }

  Future<void> _lookup(String isbn) async {
    if (_lookingUp) return;
    setState(() {
      _lookingUp = true;
      _error = null;
    });
    await _stopCamera(); // stop recording as soon as we have a valid scan

    try {
      final outcome = await ApiService.instance.scanIsbn(isbn);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _isbnController.clear();
      setState(() => _lookingUp = false);

      final action = await showModalBottomSheet<_SheetAction>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (_) => _ResultSheet(outcome: outcome),
      );
      if (!mounted) return;

      if (action == _SheetAction.done) {
        Navigator.pop(context);
      } else {
        await _startCamera(); // scan another, or sheet was swiped away
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _lookingUp = false;
        _error = e.message;
      });
    }
  }

  void _submitManual() {
    if (_formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    _lookup(normalizeIsbn(_isbnController.text));
  }

  Future<void> _tryAgain() async {
    setState(() => _error = null);
    await _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add a book')),
      body: ContentWidth(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    MobileScanner(controller: _camera, onDetect: _onDetect),
                    Center(
                      child: Container(
                        width: 260,
                        height: 130,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 14,
                      child: Text(
                        'Align the barcode on the back cover inside the frame',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_lookingUp)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black87,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 16),
                                Text(
                                  'Looking up your book...',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_error!)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _tryAgain,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan again'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Or enter the ISBN manually',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _isbnController,
                enabled: !_lookingUp,
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
              onPressed: _lookingUp ? null : _submitManual,
              icon: const Icon(Icons.search),
              label: const Text('Look up book'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSheet extends StatefulWidget {
  final ScanOutcome outcome;
  const _ResultSheet({required this.outcome});

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late Book _book;
  bool _saving = false;
  String? _savedNote;

  @override
  void initState() {
    super.initState();
    _book = widget.outcome.book;
  }

  Future<void> _save({
    int? rating,
    String? status,
    required String note,
  }) async {
    if (_book.id == null) return;
    setState(() => _saving = true);
    try {
      final updated = await ApiService.instance.updateBook(
        _book.id!,
        rating: rating,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _book = updated;
        _savedNote = note;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.outcome.isNew;
    final hasSynopsis =
        _book.description != null && _book.description!.isNotEmpty;
    final readLater = _book.status == 'TO_READ';

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isNew ? Icons.check_circle : Icons.info,
                  size: 20,
                  color: isNew ? Colors.green : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isNew ? 'Added to your library' : 'Already in your library',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(
                  title: _book.title,
                  coverUrl: _book.coverUrl,
                  width: 96,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _book.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _book.author,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_book.genre != null) ...[
                        const SizedBox(height: 10),
                        Chip(
                          label: Text(_book.genre!),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasSynopsis)
              _Synopsis(text: _book.description!)
            else
              Text(
                'No synopsis is available for this book yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Have you read it?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_saving) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(5, (i) {
                final value = i + 1;
                final filled = _book.rating != null && value <= _book.rating!;
                return IconButton(
                  tooltip: 'Rate $value out of 5',
                  iconSize: 36,
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving
                      ? null
                      : () => _save(
                          rating: value,
                          status: _book.status ?? 'FINISHED',
                          note: 'Rated $value out of 5',
                        ),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving || readLater
                    ? null
                    : () => _save(
                        status: 'TO_READ',
                        note: 'Saved to your To read list. Rate it later.',
                      ),
                icon: Icon(
                  readLater
                      ? Icons.bookmark_added_outlined
                      : Icons.bookmark_border,
                ),
                label: Text(
                  readLater ? 'On your To read list' : 'Not read yet',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (_savedNote != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_savedNote!, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, _SheetAction.scanAnother),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Scan another'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _SheetAction.done),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Synopsis extends StatefulWidget {
  final String text;
  const _Synopsis({required this.text});

  @override
  State<_Synopsis> createState() => _SynopsisState();
}

class _SynopsisState extends State<_Synopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.text.length > 180;
    final collapsed = isLong && !_expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: collapsed ? 4 : null,
          overflow: collapsed ? TextOverflow.ellipsis : TextOverflow.visible,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        if (isLong)
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
      ],
    );
  }
}
