import 'package:homizi/features/trust/user_badges.dart';

/// Public listing shape used by the demo client.
/// Contact fields are intentionally absent. The server function
/// `get_contact_visibility` is the only place a phone or email may appear.
class Listing {
  const Listing({
    required this.id,
    required this.hostUserId,
    required this.title,
    required this.city,
    required this.locality,
    required this.rentInr,
    required this.depositInr,
    required this.furnishing,
    required this.propertyType,
    required this.hostDisplayName,
    required this.amenities,
    required this.summary,
    this.bedrooms = 2,
    this.maintenanceInr = 0,
    this.brokerageInr = 0,
    this.occupancyMax = 1,
    this.availableFromIso,
    this.restrictions = const [],
    this.suitability = const [],
    this.friendlyTags = const [],
    this.photoAssets = const [],
    this.hostAvatarUrl,
    this.hostVerified = false,
    this.hostOccupation = '',
    this.hostKind = 'Host',
    this.demoReciprocal = false,
    this.trust = const UserBadges(),
    this.replyWithinHours,
    this.areaSqft,
    this.preferredTenants = const [],
    this.parking = false,
    this.petsAllowed = false,
    this.nonVegAllowed = false,
    this.gatedSociety = false,
    this.floorNo,
    this.totalFloors,
    this.photoCountOverride,
    this.publishedAtIso,
    this.approxLatitude,
    this.approxLongitude,
    this.listingVerified = false,
  });

  final String id;
  final String hostUserId;
  final String title;
  final String city;
  final String locality;
  final int rentInr;
  final int depositInr;
  final int maintenanceInr;
  final int brokerageInr;
  final int occupancyMax;

  /// `yyyy-mm-dd` when the home is free. Null means it is free now.
  final String? availableFromIso;
  final List<String> restrictions;
  final List<String> suitability;

  /// Host-declared tags such as couple_friendly or lgbtq_friendly.
  final List<String> friendlyTags;
  final String furnishing;
  final String propertyType;
  final String hostDisplayName;
  final List<String> amenities;
  final String summary;
  final int bedrooms;

  /// Bundled demo photos, or absolute https URLs from the seed catalog.
  final List<String> photoAssets;

  /// Profile image. An absolute URL or a bundled asset path.
  final String? hostAvatarUrl;
  final bool hostVerified;
  final String hostOccupation;

  /// Owner, flatmate, or host. A claim, not a government check.
  final String hostKind;

  /// Demo-only flag so the matches screen can illustrate a reciprocal like.
  final bool demoReciprocal;

  /// Phone, email, profile, and the demo ID badge. Contact values are absent.
  final UserBadges trust;

  /// Server-computed mean reply time, in hours. Null when there is no reply yet.
  final int? replyWithinHours;

  /// Built-up area. Null when the host has not entered it.
  final int? areaSqft;

  /// `family`, `bachelors`, `female`, or `any`.
  final List<String> preferredTenants;
  final bool parking;
  final bool petsAllowed;
  final bool nonVegAllowed;
  final bool gatedSociety;
  final int? floorNo;
  final int? totalFloors;

  /// Usable photo count from the server. Demo cards use [photoAssets].
  final int? photoCountOverride;

  /// When the home was published, `yyyy-mm-dd` or a full timestamp.
  final String? publishedAtIso;

  /// Locality-level public point. Never a building coordinate.
  final double? approxLatitude;
  final double? approxLongitude;

  /// The listing itself was reviewed. Separate from the owner's identity check.
  final bool listingVerified;

  String get heroTag => 'listing-hero-$id';

  int get photoCount => photoCountOverride ?? photoAssets.length;

  DateTime? get publishedAt {
    final value = publishedAtIso;
    if (value == null || value.length < 10) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  String get preferredTenantsLabel {
    final labels = [
      for (final key in preferredTenants) preferredTenantLabel(key),
    ];
    return labels.join(', ');
  }

  DateTime? get availableOn {
    final value = availableFromIso;
    if (value == null || value.length < 10) {
      return null;
    }
    final parts = value.substring(0, 10).split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  String get bhkLabel {
    if (propertyType == 'studio' || bedrooms <= 0) {
      return 'Studio';
    }
    if (propertyType == 'shared_room') {
      return 'Shared room';
    }
    if (propertyType == 'private_room') {
      return 'Private room';
    }
    if (propertyType == 'room_in_2bhk') {
      return '1 room in 2BHK';
    }
    if (propertyType == 'room_in_3bhk') {
      return '1 room in 3BHK';
    }
    if (propertyType == 'room_in_4bhk') {
      return '1 room in 4BHK';
    }
    return '$bedrooms BHK';
  }

  String get furnishingLabel => switch (furnishing) {
    'unfurnished' => 'Unfurnished',
    'semi_furnished' => 'Semi-furnished',
    'furnished' => 'Furnished',
    _ => furnishing,
  };

  String get propertyTypeLabel => propertyTypeLabelOf(propertyType);

  Listing withTrust(UserBadges trust, {int? replyWithinHours}) {
    return Listing(
      id: id,
      hostUserId: hostUserId,
      title: title,
      city: city,
      locality: locality,
      rentInr: rentInr,
      depositInr: depositInr,
      maintenanceInr: maintenanceInr,
      brokerageInr: brokerageInr,
      occupancyMax: occupancyMax,
      availableFromIso: availableFromIso,
      restrictions: restrictions,
      suitability: suitability,
      friendlyTags: friendlyTags,
      furnishing: furnishing,
      propertyType: propertyType,
      hostDisplayName: hostDisplayName,
      amenities: amenities,
      summary: summary,
      bedrooms: bedrooms,
      photoAssets: photoAssets,
      hostAvatarUrl: hostAvatarUrl,
      hostVerified: hostVerified,
      hostOccupation: hostOccupation,
      hostKind: hostKind,
      demoReciprocal: demoReciprocal,
      trust: trust,
      replyWithinHours: replyWithinHours ?? this.replyWithinHours,
      areaSqft: areaSqft,
      preferredTenants: preferredTenants,
      parking: parking,
      petsAllowed: petsAllowed,
      nonVegAllowed: nonVegAllowed,
      gatedSociety: gatedSociety,
      floorNo: floorNo,
      totalFloors: totalFloors,
      photoCountOverride: photoCountOverride,
      publishedAtIso: publishedAtIso,
      approxLatitude: approxLatitude,
      approxLongitude: approxLongitude,
      listingVerified: listingVerified,
    );
  }

  Map<String, Object?> toPublicJson() {
    return {
      'id': id,
      'hostUserId': hostUserId,
      'title': title,
      'city': city,
      'locality': locality,
      'rentInr': rentInr,
      'depositInr': depositInr,
      'maintenanceInr': maintenanceInr,
      'brokerageInr': brokerageInr,
      'furnishing': furnishing,
      'propertyType': propertyType,
      'hostDisplayName': hostDisplayName,
      'amenities': amenities,
      'restrictions': restrictions,
      'suitability': suitability,
      'friendlyTags': friendlyTags,
      'summary': summary,
      if (areaSqft != null) 'areaSqft': areaSqft,
      'preferredTenants': preferredTenants,
      'photoCount': photoCount,
      'approxLatitude': ?approxLatitude,
      'approxLongitude': ?approxLongitude,
    };
  }
}

const preferredTenantKeys = <String>['family', 'bachelors', 'female', 'any'];

const filterPropertyTypes = <String>[
  'apartment',
  'independent_house',
  'villa',
  'pg',
  'studio',
  'shared_room',
  'private_room',
  'room_in_2bhk',
  'room_in_3bhk',
  'room_in_4bhk',
];

/// A whole home. A room inside a shared flat is not one of these.
const fullHousePropertyTypes = <String>[
  'apartment',
  'independent_house',
  'villa',
];

bool listingIsFullHouse(Listing listing) =>
    fullHousePropertyTypes.contains(listing.propertyType);

/// Locality match on a whole name, not a raw substring.
/// "Bandra" matches "Bandra West". "Khar" does not match "Kharadi".
bool localityNameMatches(String listingLocality, String wanted) {
  final place = listingLocality.trim().toLowerCase();
  final item = wanted.trim().toLowerCase();
  if (place.isEmpty || item.isEmpty) {
    return false;
  }
  if (place == item) {
    return true;
  }
  return _localityToken(place, item) || _localityToken(item, place);
}

bool _localityToken(String text, String token) {
  var start = 0;
  while (start <= text.length - token.length) {
    final index = text.indexOf(token, start);
    if (index < 0) {
      return false;
    }
    final beforeOk = index == 0 || _localityBreak(text.codeUnitAt(index - 1));
    final after = index + token.length;
    final afterOk =
        after == text.length || _localityBreak(text.codeUnitAt(after));
    if (beforeOk && afterOk) {
      return true;
    }
    start = index + token.length;
  }
  return false;
}

bool _localityBreak(int unit) =>
    unit == 32 || unit == 44 || unit == 45 || unit == 47;

String propertyTypeLabelOf(String propertyType) => switch (propertyType) {
  'apartment' => 'Apartment',
  'independent_house' => 'Independent house',
  'villa' => 'Villa',
  'pg' => 'PG',
  'private_room' => 'Private room',
  'shared_room' => 'Shared room',
  'studio' => 'Studio',
  'room_in_2bhk' => '1 room in 2BHK',
  'room_in_3bhk' => '1 room in 3BHK',
  'room_in_4bhk' => '1 room in 4BHK',
  _ => propertyType,
};

/// Host tags shown as chips on cards and the detail page.
const listingFriendlyTagKeys = <String>['couple_friendly', 'lgbtq_friendly'];

String listingFriendlyTagLabel(String key) => switch (key) {
  'couple_friendly' => 'Couple friendly',
  'lgbtq_friendly' => 'LGBTQ+ friendly',
  _ => key,
};

const furnishingLevels = <String>['unfurnished', 'semi_furnished', 'furnished'];

String preferredTenantLabel(String key) => switch (key) {
  'family' => 'Family',
  'bachelors' => 'Bachelors',
  'female' => 'Women',
  'any' => 'Any',
  _ => key,
};
