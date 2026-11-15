import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

const _photos = <String>[
  'assets/images/real/living.webp',
  'assets/images/real/bedroom.webp',
  'assets/images/real/kitchen.webp',
  'assets/images/real/bath.webp',
];

const _names = <String>[
  'Ananya Iyer',
  'Rohan Mehta',
  'Sana Qureshi',
  'Kabir Shah',
  'Meera Krishnan',
  'Arjun Nair',
  'Priya Deshmukh',
  'Vikram Joshi',
  'Neha Kapoor',
  'Imran Khan',
  'Lakshmi Rao',
  'Fatima Hussain',
];

const _rents = <int>[8000, 14000, 24000, 42000, 62000];

/// One realistic home for every seeded locality that the original catalog
/// does not already cover, plus one published home whose host is not verified.
List<Listing> filterGapListings(List<Listing> existing) {
  final covered = <String>{
    for (final listing in existing)
      '${listing.city}|${listing.locality}'.toLowerCase(),
  };
  final added = <Listing>[];
  var index = 0;
  for (final place in localitySeed) {
    final key = '${place.city}|${place.name}'.toLowerCase();
    if (covered.contains(key)) {
      continue;
    }
    covered.add(key);
    added.add(_home(place.city, place.name, index));
    index += 1;
  }
  added.add(
    const Listing(
      id: 'lst_pending_bopal',
      hostUserId: 'demo-host-pending',
      title: '1 BHK in Bopal, verification pending',
      city: 'Ahmedabad',
      locality: 'Bopal',
      rentInr: 12000,
      depositInr: 24000,
      furnishing: 'semi_furnished',
      propertyType: 'apartment',
      bedrooms: 1,
      occupancyMax: 2,
      hostDisplayName: 'Kavya Patel',
      hostOccupation: 'Teacher',
      hostKind: 'Owner',
      hostAvatarUrl: 'assets/avatars/avatar_03.webp',
      amenities: ['Lift', 'Parking'],
      photoAssets: _photos,
      summary:
          'A semi-furnished 1 BHK in Bopal. The owner has published the home and identity verification is still pending.',
      areaSqft: 640,
      preferredTenants: ['bachelors', 'female'],
      parking: true,
      petsAllowed: true,
      restrictions: ['Vegetarian only'],
      availableFromIso: '2026-11-12',
      approxLatitude: 23.027,
      approxLongitude: 72.465,
    ),
  );
  return added;
}

Listing _home(String city, String locality, int index) {
  final name = _names[index % _names.length];
  final rent = _rents[index % _rents.length];
  final types = <String>['apartment', 'independent_house', 'studio', 'pg'];
  final type = types[index % types.length];
  final bedrooms = switch (type) {
    'studio' => 0,
    'pg' => 1,
    'independent_house' => 3,
    _ => 1 + (index % 3),
  };
  final furnishing = switch (index % 3) {
    0 => 'furnished',
    1 => 'semi_furnished',
    _ => 'unfurnished',
  };
  final point = _point(city, index);
  return Listing(
    id: 'lst_gap_${index.toString().padLeft(3, '0')}',
    hostUserId: 'demo-host-gap-$index',
    title: _title(type, bedrooms, locality),
    city: city,
    locality: locality,
    rentInr: rent,
    depositInr: rent * 2,
    furnishing: furnishing,
    propertyType: type,
    bedrooms: bedrooms,
    occupancyMax: bedrooms <= 0 ? 1 : bedrooms + 1,
    hostDisplayName: name,
    hostOccupation: 'Working professional',
    hostKind: 'Owner',
    hostAvatarUrl: 'assets/avatars/avatar_0${(index % 5) + 1}.webp',
    hostVerified: true,
    amenities: const ['Lift', 'Wi-Fi', 'Parking'],
    photoAssets: _photos,
    summary:
        'A $furnishing home in $locality, $city. Rent is shown in rupees. The street address stays off this card.',
    areaSqft: 500 + (index % 8) * 120,
    preferredTenants: index.isEven
        ? const ['family', 'any']
        : const ['bachelors', 'female'],
    friendlyTags: index % 4 == 0
        ? const ['lgbtq_friendly', 'couple_friendly']
        : const [],
    parking: true,
    petsAllowed: index.isEven,
    nonVegAllowed: index % 3 != 0,
    restrictions: index % 3 == 0
        ? const ['Vegetarian only', 'No smoking']
        : const ['No smoking'],
    floorNo: index % 6,
    totalFloors: 8,
    availableFromIso: '2026-11-${(index % 27 + 1).toString().padLeft(2, '0')}',
    approxLatitude: point.$1,
    approxLongitude: point.$2,
  );
}

(double, double) _point(String city, int index) {
  final base = switch (city) {
    'Mumbai' => (19.07, 72.87),
    'Pune' => (18.52, 73.85),
    'Delhi NCR' => (28.61, 77.20),
    'Hyderabad' => (17.38, 78.48),
    'Chennai' => (13.08, 80.27),
    'Ahmedabad' => (23.02, 72.57),
    _ => (12.97, 77.59),
  };
  final nudge = (index % 7) * 0.004;
  return (base.$1 + nudge, base.$2 - nudge);
}

String _title(String type, int bedrooms, String locality) {
  final kind = switch (type) {
    'studio' => 'Studio',
    'pg' => 'PG',
    'shared_room' => 'Shared room',
    'private_room' => 'Private room',
    'independent_house' => 'Individual house',
    _ => bedrooms <= 0 ? '1 RK' : '$bedrooms BHK',
  };
  return '$kind in $locality';
}
