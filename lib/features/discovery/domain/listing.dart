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

  String get heroTag => 'listing-hero-$id';

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
    };
  }
}
