String normalizeIsbn(String raw) =>
    raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

/// Validates ISBN-10 and ISBN-13 including the check digit, so a bad
/// camera read is rejected before it ever reaches the server.
bool isValidIsbn(String isbn) {
  if (RegExp(r'^\d{13}$').hasMatch(isbn)) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(isbn[i]) * (i.isEven ? 1 : 3);
    }
    return (10 - sum % 10) % 10 == int.parse(isbn[12]);
  }
  if (RegExp(r'^\d{9}[\dX]$').hasMatch(isbn)) {
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += int.parse(isbn[i]) * (10 - i);
    }
    sum += isbn[9] == 'X' ? 10 : int.parse(isbn[9]);
    return sum % 11 == 0;
  }
  return false;
}
