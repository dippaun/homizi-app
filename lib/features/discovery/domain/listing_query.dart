import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';

/// How a 1 RK chip is sent to PostgREST.
///
/// A studio often has no bedrooms row, so that case must not use an inner embed.
enum OneRkMode { none, studioOrZero, zeroBedrooms }

/// Predicates [SupabaseDiscoveryGateway] can send, plus the client checks
/// that still run after the rows come back.
class ListingQueryPlan {
  const ListingQueryPlan({
    required this.source,
    required this.impossible,
    required this.propertyTypes,
    required this.bedrooms,
    required this.oneRk,
    required this.friendlyTags,
  });

  final ListingFilters source;
  final bool impossible;

  /// Null leaves property type open. A list is the allowed types.
  final List<String>? propertyTypes;
  final BedroomConstraint bedrooms;
  final OneRkMode oneRk;
  final List<String> friendlyTags;

  bool get needsFeatureEmbed =>
      !impossible &&
      oneRk != OneRkMode.studioOrZero &&
      (bedrooms.active || oneRk == OneRkMode.zeroBedrooms);

  /// Embedded `or` for studio OR an explicit 0-bedroom home.
  String? get oneRkOrFilter {
    if (impossible || oneRk != OneRkMode.studioOrZero) {
      return null;
    }
    return 'property_type.eq.studio,'
        'and(property_features.feature_key.eq.bedrooms,'
        'property_features.value.eq.0)';
  }

  List<String> get friendlyTagKeys => [
    for (final tag in friendlyTags) friendlyTagFeatureKey(tag),
  ];
}

String friendlyTagFeatureKey(String tag) => 'tag:$tag';

/// Like-pattern escape. `_` and `%` stay literal in city and locality filters.
String escapeLike(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

/// Property ids that carry every requested friendly tag.
List<String> propertyIdsWithEveryTag(
  Iterable<({String propertyId, String featureKey})> rows,
  List<String> tags,
) {
  if (tags.isEmpty) {
    return const [];
  }
  final needed = tags.map(friendlyTagFeatureKey).toSet();
  final found = <String, Set<String>>{};
  for (final row in rows) {
    if (row.propertyId.isEmpty || !needed.contains(row.featureKey)) {
      continue;
    }
    found.putIfAbsent(row.propertyId, () => <String>{}).add(row.featureKey);
  }
  final ids = [
    for (final entry in found.entries)
      if (needed.every(entry.value.contains)) entry.key,
  ]..sort();
  return ids;
}

ListingQueryPlan planListingQuery(ListingFilters filters) {
  final chip = filters.quickChip;
  if (chip != null && chip.isNotEmpty && !quickChips.contains(chip)) {
    return _impossible(filters);
  }

  List<String>? types;
  void restrict(List<String> next) {
    if (types == null) {
      types = [...next];
      return;
    }
    final allowed = next.toSet();
    types = [
      for (final type in types!)
        if (allowed.contains(type)) type,
    ];
  }

  final propertyType = filters.propertyType;
  if (propertyType != null && propertyType.isNotEmpty) {
    restrict([propertyType]);
  }
  switch (chip) {
    case 'pg':
      restrict(const ['pg', 'shared_room']);
    case 'flatmate':
      restrict(const [
        'private_room',
        'shared_room',
        'room_in_2bhk',
        'room_in_3bhk',
        'room_in_4bhk',
      ]);
    case 'room_in_2bhk':
    case 'room_in_3bhk':
    case 'room_in_4bhk':
      restrict([chip!]);
    case '1bhk':
    case '2bhk':
    case '3bhk':
    case '4bhk':
    case 'full_house':
      restrict(fullHousePropertyTypes);
    case '1rk':
      break;
  }
  if (bedroomSelectsFullHouse(filters)) {
    restrict(fullHousePropertyTypes);
  }
  if (types != null && types!.isEmpty) {
    return _impossible(filters);
  }

  var oneRk = OneRkMode.none;
  if (chip == '1rk') {
    final studioOnly =
        types != null && types!.length == 1 && types!.single == 'studio';
    final noStudio = types != null && !types!.contains('studio');
    if (studioOnly) {
      oneRk = OneRkMode.none;
    } else if (noStudio) {
      oneRk = OneRkMode.zeroBedrooms;
    } else {
      oneRk = OneRkMode.studioOrZero;
    }
  }

  return ListingQueryPlan(
    source: filters,
    impossible: false,
    propertyTypes: types == null ? null : List.unmodifiable(types!),
    bedrooms: bedroomConstraint(filters),
    oneRk: oneRk,
    friendlyTags: List.unmodifiable(filters.friendlyTags),
  );
}

/// True when the property query would still return [listing].
///
/// The query is allowed to be wider than [ListingFilters.matches]. It must
/// not drop a home the client would keep.
bool sqlPlanAllows(Listing listing, ListingQueryPlan plan) {
  if (plan.impossible) {
    return false;
  }
  if (!listingPassesSharedFilters(listing, plan.source)) {
    return false;
  }
  final types = plan.propertyTypes;
  if (types != null && !types.contains(listing.propertyType)) {
    return false;
  }
  final exact = plan.bedrooms.exact;
  if (exact != null && plan.needsFeatureEmbed && listing.bedrooms != exact) {
    return false;
  }
  final atLeast = plan.bedrooms.atLeast;
  if (atLeast != null && plan.needsFeatureEmbed && listing.bedrooms < atLeast) {
    return false;
  }
  if (plan.oneRk == OneRkMode.zeroBedrooms && listing.bedrooms > 0) {
    return false;
  }
  if (plan.oneRk == OneRkMode.studioOrZero &&
      listing.propertyType != 'studio' &&
      listing.bedrooms > 0) {
    return false;
  }
  for (final tag in plan.friendlyTags) {
    if (!listing.friendlyTags.contains(tag)) {
      return false;
    }
  }
  return true;
}

ListingQueryPlan _impossible(ListingFilters filters) {
  return ListingQueryPlan(
    source: filters,
    impossible: true,
    propertyTypes: const [],
    bedrooms: const BedroomConstraint(),
    oneRk: OneRkMode.none,
    friendlyTags: const [],
  );
}
