/// Rent affordability helper for the "Be a Smart Liver" tool.
///
/// Keeps housing near 25–30% of take-home income. Other EMIs reduce how much
/// rent can still feel healthy.
library;

import 'package:homizi/core/format/inr.dart';

class SmartLiverInput {
  const SmartLiverInput({
    required this.monthlyIncomeInr,
    this.otherEmisInr = 0,
  });

  final int monthlyIncomeInr;
  final int otherEmisInr;
}

class SmartLiverResult {
  const SmartLiverResult({
    required this.monthlyIncomeInr,
    required this.otherEmisInr,
    required this.remainingAfterEmisInr,
    required this.rentMinInr,
    required this.rentMaxInr,
    required this.tip,
  });

  final int monthlyIncomeInr;
  final int otherEmisInr;
  final int remainingAfterEmisInr;
  final int rentMinInr;
  final int rentMaxInr;
  final String tip;

  /// Share of income at the top of the healthy band.
  double get maxShareOfIncome =>
      monthlyIncomeInr <= 0 ? 0 : rentMaxInr / monthlyIncomeInr;
}

/// Round rupees to the nearest [step] for friendlier rent bands.
int roundRentInr(int amount, {int step = 500}) {
  if (step <= 0) {
    return amount;
  }
  if (amount <= 0) {
    return 0;
  }
  return ((amount + (step ~/ 2)) ~/ step) * step;
}

/// Comfortable rent is about 25–30% of take-home. Other EMIs shrink the cap.
SmartLiverResult smartLiver(SmartLiverInput input) {
  if (input.monthlyIncomeInr <= 0) {
    throw ArgumentError('Monthly income must be more than zero.');
  }
  if (input.otherEmisInr < 0) {
    throw ArgumentError('Other EMIs cannot be negative.');
  }

  final income = input.monthlyIncomeInr;
  final emis = input.otherEmisInr;
  final remaining = income - emis < 0 ? 0 : income - emis;

  var minRent = roundRentInr((income * 0.25).round());
  var maxRent = roundRentInr((income * 0.30).round());

  if (emis > 0) {
    final cappedMax = roundRentInr((remaining * 0.70).round());
    if (cappedMax < maxRent) {
      maxRent = cappedMax;
    }
    if (minRent > maxRent) {
      minRent = maxRent;
    }
  }

  if (maxRent < 1000 && remaining >= 1000) {
    maxRent = roundRentInr(remaining ~/ 2);
    minRent = roundRentInr((maxRent * 0.8).round());
  }

  final tip = _tip(
    income: income,
    emis: emis,
    remaining: remaining,
    minRent: minRent,
    maxRent: maxRent,
  );

  return SmartLiverResult(
    monthlyIncomeInr: income,
    otherEmisInr: emis,
    remainingAfterEmisInr: remaining,
    rentMinInr: minRent,
    rentMaxInr: maxRent,
    tip: tip,
  );
}

String _tip({
  required int income,
  required int emis,
  required int remaining,
  required int minRent,
  required int maxRent,
}) {
  final band = '${formatInr(minRent)}–${formatInr(maxRent)}';
  if (emis > 0 && remaining < minRent) {
    return 'Other EMIs already take most of this income. Pause new rent until '
        'those loans ease, or look for a smaller share with flatmates.';
  }
  if (emis > 0) {
    return 'Keep rent near $band so housing plus other EMIs stay comfortable. '
        'Aim under a third of take-home when you can.';
  }
  if (income < 25000) {
    return 'A healthy rent is about $band. Shared rooms and PGs in growing '
        'Indian cities often fit this band.';
  }
  return 'A healthy rent is about 25–30% of take-home: $band. Leaving the rest '
      'for food, commute, and savings keeps the month calm.';
}
