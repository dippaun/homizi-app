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
    this.photoAssets = const [],
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
  final String furnishing;
  final String propertyType;
  final String hostDisplayName;
  final List<String> amenities;
  final String summary;
  final int bedrooms;

  /// Bundled demo photos. Empty for rows that come from the server.
  final List<String> photoAssets;
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
    return '$bedrooms BHK';
  }

  String get furnishingLabel => switch (furnishing) {
    'unfurnished' => 'Unfurnished',
    'semi_furnished' => 'Semi-furnished',
    'furnished' => 'Furnished',
    _ => furnishing,
  };

  String get propertyTypeLabel => switch (propertyType) {
    'apartment' => 'Apartment',
    'private_room' => 'Private room',
    'shared_room' => 'Shared room',
    'studio' => 'Studio',
    _ => propertyType,
  };

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
      furnishing: furnishing,
      propertyType: propertyType,
      hostDisplayName: hostDisplayName,
      amenities: amenities,
      summary: summary,
      bedrooms: bedrooms,
      photoAssets: photoAssets,
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
      'summary': summary,
      if (areaSqft != null) 'areaSqft': areaSqft,
      'preferredTenants': preferredTenants,
      'photoCount': photoCount,
    };
  }
}

const preferredTenantKeys = <String>['family', 'bachelors', 'female', 'any'];

String preferredTenantLabel(String key) => switch (key) {
  'family' => 'Family',
  'bachelors' => 'Bachelors',
  'female' => 'Women',
  'any' => 'Any',
  _ => key,
};
