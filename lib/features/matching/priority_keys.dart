import 'package:homizi/features/matching/domain/intelligent_match.dart';

/// Ranked items on Set My Priorities. Rank 1 is the top of the list.
enum PriorityKey {
  budget,
  location,
  occupancy,
  propertyType,
  gender,
  lifestyle,
  furnishing,
  bathroom,
  amenities,
  tenantProfile,
  lease,
  rules,
}

/// Tenant and flatmate order from the priorities spec.
const tenantPriorityOrder = <PriorityKey>[
  PriorityKey.budget,
  PriorityKey.location,
  PriorityKey.occupancy,
  PriorityKey.propertyType,
  PriorityKey.gender,
  PriorityKey.lifestyle,
  PriorityKey.furnishing,
  PriorityKey.bathroom,
  PriorityKey.amenities,
];

/// Host, owner, and property-partner order from the priorities spec.
const hostPriorityOrder = <PriorityKey>[
  PriorityKey.propertyType,
  PriorityKey.tenantProfile,
  PriorityKey.budget,
  PriorityKey.gender,
  PriorityKey.occupancy,
  PriorityKey.lease,
  PriorityKey.rules,
  PriorityKey.lifestyle,
];

/// Hard misses. A zero on one of these caps the percent in the low band.
const hardPriorityKeys = <PriorityKey>{
  PriorityKey.budget,
  PriorityKey.gender,
  PriorityKey.occupancy,
};

class PriorityCopy {
  const PriorityCopy({
    required this.key,
    required this.title,
    required this.subtitle,
  });

  final PriorityKey key;
  final String title;
  final String subtitle;
}

const tenantPriorityCopy = <PriorityCopy>[
  PriorityCopy(
    key: PriorityKey.budget,
    title: 'Budget Range',
    subtitle: 'The monthly rent you can pay',
  ),
  PriorityCopy(
    key: PriorityKey.location,
    title: 'Location & Workplace',
    subtitle: 'Near office, distance & travel time',
  ),
  PriorityCopy(
    key: PriorityKey.occupancy,
    title: 'Occupancy Required',
    subtitle: 'Full / Master / Separate / Shared',
  ),
  PriorityCopy(
    key: PriorityKey.propertyType,
    title: 'Property Type',
    subtitle: 'House / 1RK / 1BHK / 2BHK / 3BHK',
  ),
  PriorityCopy(
    key: PriorityKey.gender,
    title: 'Flatmate Gender Preference',
    subtitle: 'Male / Female / Any / LGBTQ+',
  ),
  PriorityCopy(
    key: PriorityKey.lifestyle,
    title: 'Lifestyle Preferences',
    subtitle: 'Smoking, Drinking, Food, Cooking, Cleaning',
  ),
  PriorityCopy(
    key: PriorityKey.furnishing,
    title: 'Furnishing Preference',
    subtitle: 'Furnished / Semi / Unfurnished',
  ),
  PriorityCopy(
    key: PriorityKey.bathroom,
    title: 'Bathroom Preference',
    subtitle: 'Attached / Private / Shared',
  ),
  PriorityCopy(
    key: PriorityKey.amenities,
    title: 'Essential Amenities',
    subtitle: 'Wi-Fi, AC, Cook, Cleaning, Maid, etc.',
  ),
];

const hostPriorityCopy = <PriorityCopy>[
  PriorityCopy(
    key: PriorityKey.propertyType,
    title: 'Property Type & Details',
    subtitle: 'House / 1RK / 1BHK / 2BHK / 3BHK',
  ),
  PriorityCopy(
    key: PriorityKey.tenantProfile,
    title: 'Preferred Tenant Profile',
    subtitle: 'Working / Student / Couple / Family, etc.',
  ),
  PriorityCopy(
    key: PriorityKey.budget,
    title: 'Budget / Expected Rent',
    subtitle: 'Rent range per month',
  ),
  PriorityCopy(
    key: PriorityKey.gender,
    title: 'Tenant / Flatmate Gender Preference',
    subtitle: 'Male / Female / Any / LGBTQ+',
  ),
  PriorityCopy(
    key: PriorityKey.occupancy,
    title: 'Occupancy Preference',
    subtitle: 'Single / Family / Group / Flatmates',
  ),
  PriorityCopy(
    key: PriorityKey.lease,
    title: 'Lease Duration',
    subtitle: 'Short / 6–11 Months / Long Term',
  ),
  PriorityCopy(
    key: PriorityKey.rules,
    title: 'Property Rules & Restrictions',
    subtitle: 'Pet, Smoking, Drinking, Guests, etc.',
  ),
  PriorityCopy(
    key: PriorityKey.lifestyle,
    title: 'Preferred Lifestyle Match',
    subtitle: 'Veg / Non-Veg, Cooking, Cleaning, etc.',
  ),
];

String priorityWire(PriorityKey key) => switch (key) {
  PriorityKey.budget => 'budget',
  PriorityKey.location => 'location',
  PriorityKey.occupancy => 'occupancy',
  PriorityKey.propertyType => 'property_type',
  PriorityKey.gender => 'gender',
  PriorityKey.lifestyle => 'lifestyle',
  PriorityKey.furnishing => 'furnishing',
  PriorityKey.bathroom => 'bathroom',
  PriorityKey.amenities => 'amenities',
  PriorityKey.tenantProfile => 'tenant_profile',
  PriorityKey.lease => 'lease',
  PriorityKey.rules => 'rules',
};

PriorityKey? priorityFromWire(String raw) {
  for (final key in PriorityKey.values) {
    if (priorityWire(key) == raw) {
      return key;
    }
  }
  return null;
}

TenantFactorId? tenantFactorFor(PriorityKey key) => switch (key) {
  PriorityKey.budget => TenantFactorId.budget,
  PriorityKey.location => TenantFactorId.location,
  PriorityKey.occupancy => TenantFactorId.occupancy,
  PriorityKey.propertyType => TenantFactorId.propertyType,
  PriorityKey.gender => TenantFactorId.gender,
  PriorityKey.lifestyle => TenantFactorId.lifestyle,
  PriorityKey.furnishing => TenantFactorId.furnishing,
  PriorityKey.bathroom => TenantFactorId.bathroom,
  PriorityKey.amenities => TenantFactorId.amenities,
  PriorityKey.tenantProfile || PriorityKey.lease || PriorityKey.rules => null,
};

List<TenantFactorId> tenantFactorsIn(List<PriorityKey> keys) {
  return [
    for (final key in keys)
      if (tenantFactorFor(key) != null) tenantFactorFor(key)!,
  ];
}

List<PriorityKey> orderFromWires(
  List<String> wires,
  List<PriorityKey> fallback,
) {
  final parsed = <PriorityKey>[
    for (final wire in wires)
      if (priorityFromWire(wire) != null) priorityFromWire(wire)!,
  ];
  final allowed = fallback.toSet();
  final seen = <PriorityKey>{};
  final ordered = <PriorityKey>[
    for (final key in parsed)
      if (allowed.contains(key) && seen.add(key)) key,
  ];
  for (final key in fallback) {
    if (seen.add(key)) {
      ordered.add(key);
    }
  }
  return ordered;
}

/// In-memory ranking the scorers read after Save My Priorities.
///
/// Null means the caller’s own order is used. Cleared in tests.
class SavedRanks {
  static List<TenantFactorId>? tenant;
  static List<PriorityKey>? host;

  static void clear() {
    tenant = null;
    host = null;
  }
}
