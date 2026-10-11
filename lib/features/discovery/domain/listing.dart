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
    this.demoReciprocal = false,
  });

  final String id;
  final String hostUserId;
  final String title;
  final String city;
  final String locality;
  final int rentInr;
  final int depositInr;
  final String furnishing;
  final String propertyType;
  final String hostDisplayName;
  final List<String> amenities;
  final String summary;

  /// Demo-only flag so the matches screen can illustrate a reciprocal like.
  final bool demoReciprocal;

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
      'furnishing': furnishing,
      'propertyType': propertyType,
      'hostDisplayName': hostDisplayName,
      'amenities': amenities,
      'summary': summary,
    };
  }
}
