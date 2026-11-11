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

/// Short rent for a card chip. 22000 → ₹22k, 150000 → ₹1.5L.
String formatInrCompact(int amount) {
  final sign = amount < 0 ? '-' : '';
  final abs = amount.abs();
  if (abs >= 10000000) {
    return '$sign₹${_compactUnit(abs / 10000000)}cr';
  }
  if (abs >= 100000) {
    return '$sign₹${_compactUnit(abs / 100000)}L';
  }
  if (abs >= 1000) {
    return '$sign₹${_compactUnit(abs / 1000)}k';
  }
  return '$sign₹$abs';
}

String _compactUnit(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return rounded.round().toString();
  }
  return rounded.toStringAsFixed(1);
}

/// Monthly rent chip, for example ₹22k/mo.
String chipMonthlyRent(int rent) => '${formatInrCompact(rent)}/mo';

/// Budget chip. A single figure when the ends match.
String chipMoneySpan(int low, int high) {
  if (high <= 0 || low == high) {
    return formatInrCompact(low);
  }
  return '${formatInrCompact(low)}–${formatInrCompact(high)}';
}

/// First place name. "Koramangala, Indiranagar" stays "Koramangala".
String chipPlace(String place) {
  final first = place.split(',').first.trim();
  return first.isEmpty ? place.trim() : first;
}

/// Furnishing that still fits on a pill.
String chipFurnishing(String label) => switch (label) {
  'Semi-furnished' => 'Semi',
  _ => label,
};

/// Built-up area, for example 1600 → 1,600 sq ft.
String formatSqft(int amount) => '${formatIndianDigits(amount)} sq ft';
