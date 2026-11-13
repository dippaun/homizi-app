import 'package:homizi/features/roles/requirement_match.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';

/// `{percent, topReasons, missing}` for one seeker against one property.
///
/// Agent F's `lib/features/matching/match_api.dart` is not on main yet.
/// This adapter calls [requirementListingMatch], the same weights as
/// `public.requirement_listing_match`. The percent is that function's
/// return value. Reasons name the factors that earned points. Lifestyle
/// is listed only when it does not conflict with the home's rules, and
/// it does not change the percent.
class SeekerFit {
  const SeekerFit({
    required this.percent,
    required this.topReasons,
    required this.missing,
  });

  final int percent;
  final List<String> topReasons;
  final List<String> missing;
}

SeekerFit scoreSeekerForProperty({
  required HostProperty property,
  required SeekerPublicProfile seeker,
}) {
  final base = _points(property: property, seeker: seeker);
  final cityPoints =
      base - _points(property: property, seeker: seeker, city: '___');
  final localityPoints =
      base -
      _points(property: property, seeker: seeker, localities: const ['___']);
  final budgetPoints =
      base -
      _points(
        property: property,
        seeker: seeker,
        budgetMin: property.rentInr + 100000,
        budgetMax: property.rentInr + 200000,
      );
  final typePoints =
      base -
      _points(
        property: property,
        seeker: seeker,
        roomType: _typeThatMisses(property.propertyType),
      );
  final furnishingPoints =
      base -
      _points(
        property: property,
        seeker: seeker,
        furnishing: _furnishingThatMisses(property.furnishing),
      );
  final amenityPoints =
      base -
      _points(
        property: property,
        seeker: seeker,
        amenities: const ['___missing___'],
      );
  final timingPoints =
      base - _points(property: property, seeker: seeker, dropTiming: true);

  final reasons = <String>[];
  final missing = <String>[];
  if (budgetPoints >= matchWeightBudget) {
    reasons.add('Budget Matches');
  } else if (budgetPoints > 0) {
    missing.add('Budget is close');
  } else {
    missing.add('Budget does not cover this rent');
  }
  if (cityPoints > 0 && localityPoints > 0) {
    reasons.add('Location Matches');
  } else if (cityPoints > 0) {
    reasons.add('City matches');
    missing.add('Preferred locality differs');
  } else {
    missing.add('City differs');
  }
  if (typePoints > 0) {
    reasons.add('Property Type Matches');
  } else {
    missing.add('Property type differs');
  }
  final lifestyle = _lifestyleOk(property, seeker);
  if (lifestyle == true) {
    reasons.add('Lifestyle Matches');
  } else if (lifestyle == false) {
    missing.add('Lifestyle differs');
  }
  if (furnishingPoints >= matchWeightFurnishing) {
    reasons.add('Furnishing matches');
  } else if (seeker.furnishing.trim().isNotEmpty) {
    missing.add('Furnishing differs');
  }
  if (amenityPoints >= matchWeightAmenities) {
    reasons.add('Amenities match');
  } else if (seeker.amenities.isNotEmpty) {
    missing.add('Amenities differ');
  }
  if (timingPoints >= matchWeightTiming) {
    reasons.add('Move-in matches');
  } else {
    missing.add('Move-in is later than this home');
  }
  return SeekerFit(percent: base, topReasons: reasons, missing: missing);
}

int _points({
  required HostProperty property,
  required SeekerPublicProfile seeker,
  String? city,
  List<String>? localities,
  int? budgetMin,
  int? budgetMax,
  String? roomType,
  String? furnishing,
  List<String>? amenities,
  bool dropTiming = false,
}) {
  return requirementListingMatch(
    listingCity: property.city,
    listingLocality: property.locality,
    rentInr: property.rentInr,
    propertyType: property.propertyType,
    furnishing: property.furnishing,
    listingAmenities: property.amenities,
    availableFrom: dropTiming ? DateTime(2099) : property.availableFrom,
    requirementCity: city ?? seeker.city,
    requirementLocalities: localities ?? seeker.localities,
    budgetMinInr: budgetMin ?? seeker.budgetMinInr,
    budgetMaxInr: budgetMax ?? seeker.budgetMaxInr,
    roomTypes: [roomType ?? seeker.roomType],
    propertyTypes: const ['apartment'],
    requirementFurnishings: [
      (furnishing ?? seeker.furnishing).trim(),
    ].where((item) => item.isNotEmpty).toList(),
    requirementAmenities: amenities ?? seeker.amenities,
    moveInDate: dropTiming ? DateTime(1990) : seeker.moveIn,
  );
}

String _typeThatMisses(String propertyType) {
  if (propertyType == 'shared_room' || propertyType == 'pg') {
    return '4bhk';
  }
  return 'shared';
}

String _furnishingThatMisses(String listing) {
  return switch (listing.trim()) {
    'furnished' => 'unfurnished',
    'unfurnished' => 'furnished',
    _ => 'furnished',
  };
}

/// Null when the seeker has not shared lifestyle. True when the shared
/// facts do not conflict with this home's rules.
bool? _lifestyleOk(HostProperty property, SeekerPublicProfile seeker) {
  if (!seeker.lifestyleKnown) {
    return null;
  }
  if (property.noSmoking && seeker.smokes) {
    return false;
  }
  if (!property.petsAllowed && seeker.hasPets) {
    return false;
  }
  if (!property.nonVegAllowed && seeker.wantsNonVeg) {
    return false;
  }
  return true;
}
