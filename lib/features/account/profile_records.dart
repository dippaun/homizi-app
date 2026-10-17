import 'package:homizi/core/verification/identity_verification_gateway.dart';

/// Private matching inputs from `tenant_preferences`.
/// An empty value is not a filter. Discover still shows published homes.
class TenantPreferences {
  const TenantPreferences({
    this.budgetMinInr,
    this.budgetMaxInr,
    this.localities = const [],
    this.occupancy = 1,
    this.propertyTypes = const [],
    this.lifestyle = const [],
  });

  final int? budgetMinInr;
  final int? budgetMaxInr;
  final List<String> localities;
  final int occupancy;
  final List<String> propertyTypes;
  final List<String> lifestyle;

  /// Schema defaults only. The feed must not treat this as a search.
  bool get isBlank =>
      budgetMinInr == null &&
      budgetMaxInr == null &&
      localities.isEmpty &&
      propertyTypes.isEmpty &&
      lifestyle.isEmpty;

  TenantPreferences copyWith({
    int? budgetMinInr,
    int? budgetMaxInr,
    List<String>? localities,
    int? occupancy,
    List<String>? propertyTypes,
    List<String>? lifestyle,
    bool clearBudgetMin = false,
    bool clearBudgetMax = false,
  }) {
    return TenantPreferences(
      budgetMinInr: clearBudgetMin ? null : (budgetMinInr ?? this.budgetMinInr),
      budgetMaxInr: clearBudgetMax ? null : (budgetMaxInr ?? this.budgetMaxInr),
      localities: localities ?? this.localities,
      occupancy: occupancy ?? this.occupancy,
      propertyTypes: propertyTypes ?? this.propertyTypes,
      lifestyle: lifestyle ?? this.lifestyle,
    );
  }
}

const tenantPropertyTypes = [
  'apartment',
  'independent_house',
  'villa',
  'pg',
  'studio',
  'shared_room',
  'private_room',
];

const tenantLifestyles = [
  'pets_ok',
  'non_smoker',
  'early_riser',
  'night_owl',
  'wfh',
];

String tenantPropertyTypeLabel(String value) => switch (value) {
  'apartment' => 'Apartment',
  'independent_house' => 'Independent house',
  'villa' => 'Villa',
  'pg' => 'PG',
  'studio' => 'Studio',
  'shared_room' => 'Shared room',
  'private_room' => 'Private room',
  _ => value,
};

String tenantLifestyleLabel(String value) => switch (value) {
  'pets_ok' => 'Pets ok',
  'non_smoker' => 'Non-smoker',
  'early_riser' => 'Early riser',
  'night_owl' => 'Night owl',
  'wfh' => 'Works from home',
  _ => value,
};

class TenantProfile {
  const TenantProfile({
    this.displayName = '',
    this.occupation = '',
    this.bio = '',
    this.verification = VerificationStatus.notStarted,
    this.preferences = const TenantPreferences(),
  });

  final String displayName;
  final String occupation;
  final String bio;
  final VerificationStatus verification;
  final TenantPreferences preferences;

  TenantProfile copyWith({
    String? displayName,
    String? occupation,
    String? bio,
    VerificationStatus? verification,
    TenantPreferences? preferences,
  }) {
    return TenantProfile(
      displayName: displayName ?? this.displayName,
      occupation: occupation ?? this.occupation,
      bio: bio ?? this.bio,
      verification: verification ?? this.verification,
      preferences: preferences ?? this.preferences,
    );
  }
}

class HostProfile {
  const HostProfile({this.category = 'owner', this.companyName = ''});

  final String category;
  final String companyName;

  HostProfile copyWith({String? category, String? companyName}) {
    return HostProfile(
      category: category ?? this.category,
      companyName: companyName ?? this.companyName,
    );
  }
}

const forbiddenProfileColumns = {
  'phone',
  'email',
  'date_of_birth',
  'verification_status',
  'aadhaar',
};

/// Columns the client may write on `profiles`. Verification is a server function.
Map<String, Object?> tenantProfileColumns(TenantProfile profile) {
  final occupation = profile.occupation.trim();
  final bio = profile.bio.trim();
  return {
    'display_name': profile.displayName.trim(),
    'occupation': occupation.isEmpty ? null : occupation,
    'public_bio': bio.isEmpty ? null : bio,
  };
}

/// Columns the client may write on `tenant_preferences`. `user_id` is added
/// by the gateway. A missing row is inserted. Blank lists are stored as empty.
Map<String, Object?> tenantPreferenceColumns(TenantPreferences preferences) {
  return {
    'budget_min_inr': preferences.budgetMinInr,
    'budget_max_inr': preferences.budgetMaxInr,
    'localities': preferences.localities,
    'occupancy': preferences.occupancy,
    'property_types': [
      for (final type in preferences.propertyTypes)
        if (tenantPropertyTypes.contains(type)) type,
    ],
    'lifestyle': [
      for (final item in preferences.lifestyle)
        if (tenantLifestyles.contains(item)) item,
    ],
  };
}

TenantPreferences preferencesFromRow(Map<String, dynamic>? row) {
  if (row == null) {
    return const TenantPreferences();
  }
  return TenantPreferences(
    budgetMinInr: _nullableInt(row['budget_min_inr']),
    budgetMaxInr: _nullableInt(row['budget_max_inr']),
    localities: _stringList(row['localities']),
    occupancy: _nullableInt(row['occupancy']) ?? 1,
    propertyTypes: [
      for (final type in _stringList(row['property_types']))
        if (tenantPropertyTypes.contains(type)) type,
    ],
    lifestyle: [
      for (final item in _stringList(row['lifestyle']))
        if (tenantLifestyles.contains(item)) item,
    ],
  );
}

/// Null when the form can be saved. Budget and occupancy match the table checks.
String? preferenceSaveError(TenantPreferences preferences) {
  final min = preferences.budgetMinInr;
  final max = preferences.budgetMaxInr;
  if (min != null && max != null && min > max) {
    return 'Enter a budget minimum that is not above the maximum.';
  }
  if (preferences.occupancy < 1 || preferences.occupancy > 20) {
    return 'Occupancy must be between 1 and 20.';
  }
  return null;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}

const hostCategories = ['owner', 'broker', 'company', 'flatmate', 'other'];

/// Null when the host form can be saved. Category matches the enum.
String? hostProfileSaveError(HostProfile profile) {
  if (!hostCategories.contains(profile.category)) {
    return 'Choose owner, broker, company, flatmate, or other.';
  }
  if (profile.companyName.trim().length > 120) {
    return 'Company name must be 120 characters or fewer.';
  }
  return null;
}

Map<String, Object?> hostProfileColumns(HostProfile profile) {
  final company = profile.companyName.trim();
  return {
    'host_category': profile.category,
    'company_name': company.isEmpty ? null : company,
  };
}
