/// Indian digit grouping without a currency sign, for example 1500000 → 15,00,000.
String formatIndianDigits(int amount) {
  final digits = amount.abs().toString();
  if (digits.length <= 3) {
    return digits;
  }
  final tail = digits.substring(digits.length - 3);
  final head = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  var index = head.length;
  while (index > 0) {
    final start = index - 2 < 0 ? 0 : index - 2;
    groups.add(head.substring(start, index));
    index = start;
  }
  return '${groups.reversed.join(',')},$tail';
}

/// Indian digit grouping, for example 1500000 → ₹15,00,000.
String formatInr(int amount) {
  final sign = amount < 0 ? '-' : '';
  return '$sign₹${formatIndianDigits(amount)}';
}

/// Built-up area, for example 1600 → 1,600 sq ft.
String formatSqft(int amount) => '${formatIndianDigits(amount)} sq ft';
