import 'package:homizi/core/format/inr.dart';

/// A personality card a host reviews. Age is a range the person chose.
/// It is not a date of birth and it is not a match score.
class TenantCard {
  const TenantCard({
    required this.userId,
    required this.name,
    required this.occupation,
    required this.about,
    required this.city,
    this.ageRange = '',
    this.lifestyle = const [],
    this.budgetMinInr,
    this.budgetMaxInr,
    this.moveInIso,
    this.photoRef,
  });

  final String userId;
  final String name;
  final String occupation;
  final String about;
  final String city;
  final String ageRange;
  final List<String> lifestyle;
  final int? budgetMinInr;
  final int? budgetMaxInr;
  final String? moveInIso;
  final String? photoRef;

  String get budgetLabel {
    final min = budgetMinInr;
    final max = budgetMaxInr;
    if (min == null && max == null) {
      return 'Budget not set';
    }
    if (min != null && max != null) {
      return '${formatInr(min)}–${formatInr(max)}';
    }
    if (max != null) {
      return 'Up to ${formatInr(max)}';
    }
    return 'From ${formatInr(min!)}';
  }

  String get moveInLabel {
    final day = moveInIso;
    if (day == null || day.length < 10) {
      return 'Move-in flexible';
    }
    return 'Move-in ${day.substring(0, 10)}';
  }
}

TenantCard tenantCardFromRows({
  required Map<String, dynamic> profile,
  required Map<String, dynamic> requirement,
}) {
  final lifestyle = requirement['lifestyle'];
  return TenantCard(
    userId: profile['user_id']?.toString() ?? '',
    name: _text(profile['display_name'], 'Tenant'),
    occupation: _text(profile['occupation'], ''),
    about: _text(profile['public_bio'], ''),
    city: _text(requirement['city'], ''),
    ageRange: _text(profile['age_range'], ''),
    lifestyle: [
      for (final item in (lifestyle is List ? lifestyle : const []))
        item.toString(),
    ],
    budgetMinInr: _int(requirement['budget_min_inr']),
    budgetMaxInr: _int(requirement['budget_max_inr']),
    moveInIso: requirement['move_in_date']?.toString(),
    photoRef: _text(profile['avatar_path'], ''),
  );
}

String _text(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
