import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/search_properties/search_draft.dart';

/// A saved search from role onboarding, so Search does not ask again.
///
/// Needs a city plus a budget or a home type. A city on its own still opens
/// the wizard. City comes from [Personalization.city], `tenant_preferences.city`,
/// or the first locality.
PropertySearch? propertySearchSeededFrom({
  Personalization? personal,
  TenantPreferences? tenant,
}) {
  final city = _city(personal, tenant);
  final min = tenant?.budgetMinInr ?? personal?.budgetMin;
  final max = tenant?.budgetMaxInr ?? personal?.budgetMax;
  final types = tenant?.propertyTypes ?? const <String>[];
  final looking = personal?.lookingFor ?? '';
  final hasBudget = min != null || max != null;
  final hasType = types.isNotEmpty || _seekerLooking(looking);
  if (city.length < 2 || (!hasBudget && !hasType)) {
    return null;
  }
  final floor = _clamp(min, searchBudgetFloor);
  final ceiling = _clamp(max, min != null ? searchBudgetCeiling : 15000);
  final low = floor <= ceiling ? floor : ceiling;
  final high = floor <= ceiling ? ceiling : floor;
  return PropertySearch(
    occupancy: _occupancy(types, looking),
    propertyKind: _kind(types),
    budgetMinInr: low,
    budgetMaxInr: high,
    useOffice: false,
    usePreferredArea: true,
    placeQuery: city,
    furnishing: _furnishing(personal),
  );
}

String _city(Personalization? personal, TenantPreferences? tenant) {
  final picked = personal?.city.trim() ?? '';
  if (picked.length >= 2) {
    return picked;
  }
  final stored = tenant?.city.trim() ?? '';
  if (stored.length >= 2) {
    return stored;
  }
  for (final place in tenant?.localities ?? const <String>[]) {
    final trimmed = place.trim();
    if (trimmed.length >= 2) {
      return trimmed;
    }
  }
  return '';
}

bool _seekerLooking(String looking) {
  return looking == 'home' || looking == 'room' || looking == 'flatmate';
}

int _clamp(int? value, int fallback) {
  final raw = value ?? fallback;
  if (raw < searchBudgetFloor) {
    return searchBudgetFloor;
  }
  if (raw > searchBudgetCeiling) {
    return searchBudgetCeiling;
  }
  return raw;
}

OccupancyChoice _occupancy(List<String> types, String looking) {
  if (types.contains('shared_room') || looking == 'flatmate') {
    return OccupancyChoice.sharedRoom;
  }
  if (types.contains('private_room') || looking == 'room') {
    return OccupancyChoice.separateRoom;
  }
  if (looking == 'home' ||
      types.contains('apartment') ||
      types.contains('independent_house') ||
      types.contains('villa')) {
    return OccupancyChoice.entire;
  }
  return OccupancyChoice.anyBudget;
}

PropertyKindChoice _kind(List<String> types) {
  for (final type in types) {
    switch (type) {
      case '1bhk' || '1_bhk' || 'bhk1':
        return PropertyKindChoice.bhk1;
      case '2bhk' || '2_bhk' || 'bhk2':
        return PropertyKindChoice.bhk2;
      case '3bhk' || '3_bhk' || 'bhk3':
        return PropertyKindChoice.bhk3;
      case '1rk' || 'rk1' || 'studio':
        return PropertyKindChoice.rk1;
      case 'independent_house' || 'villa' || 'house':
        return PropertyKindChoice.individualHouse;
    }
  }
  return PropertyKindChoice.anyBudget;
}

FurnishingChoice _furnishing(Personalization? personal) {
  if (personal?.preferences.contains('furnished') ?? false) {
    return FurnishingChoice.furnished;
  }
  return FurnishingChoice.anyBudget;
}
