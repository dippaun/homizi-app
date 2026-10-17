class FlatmateShare {
  const FlatmateShare({required this.name, required this.weight});

  final String name;

  /// Room weight. A larger room uses a higher weight than a smaller one.
  final int weight;
}

class SplitLine {
  const SplitLine({
    required this.name,
    required this.weight,
    required this.rentInr,
    required this.depositInr,
    required this.maintenanceInr,
    required this.utilitiesInr,
  });

  final String name;
  final int weight;
  final int rentInr;
  final int depositInr;
  final int maintenanceInr;
  final int utilitiesInr;

  int get monthlyInr => rentInr + maintenanceInr + utilitiesInr;
}

class SplitResult {
  const SplitResult({
    required this.lines,
    required this.monthlyPool,
    this.incomeInr,
    this.ratio,
    this.band,
  });

  final List<SplitLine> lines;
  final int monthlyPool;
  final int? incomeInr;

  /// Household monthly housing cost divided by take-home income.
  final double? ratio;
  final String? band;
}

class SplitInput {
  const SplitInput({
    required this.rentInr,
    required this.depositInr,
    required this.maintenanceInr,
    required this.utilitiesInr,
    required this.shares,
    this.incomeInr,
  });

  final int rentInr;
  final int depositInr;
  final int maintenanceInr;
  final int utilitiesInr;
  final List<FlatmateShare> shares;
  final int? incomeInr;
}

/// Splits [amount] by positive weights. The parts add back to [amount].
List<int> splitAmount(int amount, List<int> weights) {
  if (amount < 0) {
    throw ArgumentError('Amount cannot be negative.');
  }
  if (weights.isEmpty) {
    throw ArgumentError('Add at least one flatmate.');
  }
  if (weights.any((weight) => weight <= 0)) {
    throw ArgumentError('Each room share must be at least 1.');
  }
  final total = weights.fold<int>(0, (sum, weight) => sum + weight);
  final base = <int>[];
  final remainders = <({int index, int rem})>[];
  var assigned = 0;
  for (var index = 0; index < weights.length; index++) {
    final exact = amount * weights[index];
    final share = exact ~/ total;
    base.add(share);
    assigned += share;
    remainders.add((index: index, rem: exact % total));
  }
  remainders.sort((a, b) {
    final byRemainder = b.rem.compareTo(a.rem);
    if (byRemainder != 0) {
      return byRemainder;
    }
    return a.index.compareTo(b.index);
  });
  var left = amount - assigned;
  var cursor = 0;
  while (left > 0) {
    final index = remainders[cursor % remainders.length].index;
    base[index] = base[index] + 1;
    left -= 1;
    cursor += 1;
  }
  return base;
}

/// Comfortable at or under 30% of take-home. Stretch through 40%.
String? affordabilityBand(int monthlyHousing, int incomeInr) {
  if (incomeInr <= 0) {
    return null;
  }
  final ratio = monthlyHousing / incomeInr;
  if (ratio <= 0.30) {
    return 'Comfortable';
  }
  if (ratio <= 0.40) {
    return 'Stretch';
  }
  return 'Above a third';
}

SplitResult rentSplit(SplitInput input) {
  if (input.rentInr < 0 ||
      input.depositInr < 0 ||
      input.maintenanceInr < 0 ||
      input.utilitiesInr < 0) {
    throw ArgumentError('Amounts cannot be negative.');
  }
  final weights = [for (final share in input.shares) share.weight];
  final rents = splitAmount(input.rentInr, weights);
  final deposits = splitAmount(input.depositInr, weights);
  final maintenance = splitAmount(input.maintenanceInr, weights);
  final utilities = splitAmount(input.utilitiesInr, weights);
  final lines = <SplitLine>[
    for (var index = 0; index < input.shares.length; index++)
      SplitLine(
        name: input.shares[index].name.trim().isEmpty
            ? 'Flatmate ${index + 1}'
            : input.shares[index].name.trim(),
        weight: input.shares[index].weight,
        rentInr: rents[index],
        depositInr: deposits[index],
        maintenanceInr: maintenance[index],
        utilitiesInr: utilities[index],
      ),
  ];
  final monthlyPool = input.rentInr + input.maintenanceInr + input.utilitiesInr;
  final income = input.incomeInr;
  return SplitResult(
    lines: lines,
    monthlyPool: monthlyPool,
    incomeInr: income,
    ratio: income == null || income <= 0 ? null : monthlyPool / income,
    band: income == null ? null : affordabilityBand(monthlyPool, income),
  );
}
