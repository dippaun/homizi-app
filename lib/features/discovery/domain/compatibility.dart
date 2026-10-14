import 'package:homizi/features/discovery/domain/listing.dart';

/// Approved scoring (PD-06, 12 October 2026).
///
/// Factors are budget, city, locality, furnishing, and property type.
/// Gender, religion, caste, age, and marital status are not inputs.
/// The same rules are in `public.score_compatibility` for a connected database.
/// Demo mode scores on the phone so a missing project still explains the fit.
class CompatibilityPreference {
  const CompatibilityPreference({
    required this.budgetMinInr,
    required this.budgetMaxInr,
    required this.city,
    this.locality,
    this.furnishing,
    this.propertyType,
  });

  final int budgetMinInr;
  final int budgetMaxInr;
  final String city;
  final String? locality;
  final String? furnishing;
  final String? propertyType;
}

class CompatibilityResult {
  const CompatibilityResult({required this.score, required this.reasons});

  final int score;
  final List<String> reasons;
}

CompatibilityResult scoreCompatibility({
  required CompatibilityPreference preference,
  required Listing listing,
}) {
  var score = 0;
  final reasons = <String>[];

  final budgetPoints = _budgetPoints(
    rent: listing.rentInr,
    min: preference.budgetMinInr,
    max: preference.budgetMaxInr,
  );
  score += budgetPoints;
  reasons.add(
    budgetPoints == 40
        ? 'Rent sits inside your budget.'
        : budgetPoints == 15
        ? 'Rent is close to your budget.'
        : 'Rent is outside your budget.',
  );

  final cityMatch = _same(preference.city, listing.city);
  if (cityMatch) {
    score += 25;
    reasons.add('City matches ${listing.city}.');
  } else {
    reasons.add('City does not match ${preference.city}.');
  }

  final wantedLocality = preference.locality?.trim() ?? '';
  if (wantedLocality.isEmpty || _same(wantedLocality, listing.locality)) {
    score += 15;
    reasons.add(
      wantedLocality.isEmpty
          ? 'No locality preference set.'
          : 'Locality matches ${listing.locality}.',
    );
  } else {
    reasons.add('Locality does not match $wantedLocality.');
  }

  if (preference.furnishing == null ||
      _same(preference.furnishing!, listing.furnishing)) {
    score += 10;
    reasons.add(
      preference.furnishing == null
          ? 'No furnishing preference set.'
          : 'Furnishing matches.',
    );
  } else {
    reasons.add('Furnishing does not match.');
  }

  if (preference.propertyType == null ||
      _same(preference.propertyType!, listing.propertyType)) {
    score += 10;
    reasons.add(
      preference.propertyType == null
          ? 'No property type preference set.'
          : 'Property type matches.',
    );
  } else {
    reasons.add('Property type does not match.');
  }

  return CompatibilityResult(score: score, reasons: reasons);
}

int _budgetPoints({required int rent, required int min, required int max}) {
  if (rent >= min && rent <= max) {
    return 40;
  }
  final bound = rent < min ? min : max;
  if (bound == 0) {
    return 0;
  }
  final delta = (rent - bound).abs() / bound;
  return delta <= 0.20 ? 15 : 0;
}

bool _same(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();
