/// Indian digit grouping, for example 1500000 → ₹15,00,000.
String formatInr(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final sign = negative ? '-' : '';
  if (digits.length <= 3) {
    return '$sign₹$digits';
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
  return '$sign₹${groups.reversed.join(',')},$tail';
}
