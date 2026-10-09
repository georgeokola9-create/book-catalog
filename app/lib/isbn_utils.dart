String normalizeIsbn(String value) {
  return value.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
}

bool looksLikeIsbn(String value) {
  final isbn = normalizeIsbn(value);
  return isbn.length == 10 || isbn.length == 13;
}

bool isValidIsbn(String value) {
  final isbn = normalizeIsbn(value);
  if (isbn.length == 10) return _isValidIsbn10(isbn);
  if (isbn.length == 13) return _isValidIsbn13(isbn);
  return false;
}

bool _isValidIsbn10(String isbn) {
  var total = 0;
  for (var i = 0; i < 10; i++) {
    final char = isbn[i];
    final value = char == 'X' && i == 9 ? 10 : int.tryParse(char);
    if (value == null) return false;
    total += value * (10 - i);
  }
  return total % 11 == 0;
}

bool _isValidIsbn13(String isbn) {
  var total = 0;
  for (var i = 0; i < 13; i++) {
    final value = int.tryParse(isbn[i]);
    if (value == null) return false;
    total += value * (i.isEven ? 1 : 3);
  }
  return total % 10 == 0;
}
