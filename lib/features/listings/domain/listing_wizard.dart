import 'package:homizi/features/listings/domain/listing_draft.dart';

/// Eight sections of the property listing wizard.
const listingWizardSteps = <String>[
  'What to list',
  'Location',
  'Nearby places',
  'Property and living',
  'House rules',
  'Services and availability',
  'Rent and charges',
  'Photos',
];

const listingIntentOptions = <(String, String, String)>[
  ('room', 'A room / shared room', 'Single room or double sharing'),
  ('whole_flat', 'A whole flat / apartment', '1BHK, 2BHK, and larger flats'),
  ('pg', 'A paying guest (PG)', 'PG or hostel property'),
  (
    'shared_space',
    'Shared space (I am an existing tenant)',
    'Looking for a flatmate or roomie',
  ),
];

const buildingKindOptions = <(String, String)>[
  ('apartment', 'Apartment'),
  ('house', 'House'),
  ('pg', 'PG'),
  ('villa', 'Villa'),
  ('floor', 'Floor'),
];

const configurationOptions = <(String, String)>[
  ('1rk', '1 RK'),
  ('1bhk', '1 BHK'),
  ('2bhk', '2 BHK'),
  ('3bhk', '3 BHK'),
  ('4bhk', '4 BHK'),
  ('4plus', '4+ BHK'),
];

const rentableAreaOptions = <(String, String)>[
  ('single', 'Single occupancy'),
  ('double', 'Double sharing'),
  ('entire', 'Entire flat'),
];

const nearbyKinds = <String>[
  'metro',
  'train',
  'bus',
  'airport',
  'hospital',
  'supermarket',
  'mall',
  'movie',
  'gym',
];

String nearbyKindLabel(String kind) => switch (kind) {
  'metro' => 'Metro station',
  'train' => 'Train station',
  'bus' => 'Bus stop',
  'airport' => 'Airport',
  'hospital' => 'Hospital',
  'supermarket' => 'Supermarket / grocery',
  'mall' => 'Mall',
  'movie' => 'Movie theatre',
  'gym' => 'Gym / fitness centre',
  _ => kind,
};

const photoSequence = <String>[
  'Room',
  'Kitchen',
  'WC',
  'Hall',
  'Balcony',
  'Building exterior',
];

const wizardSamplePhotos = <PhotoSlot>[
  PhotoSlot(
    label: 'Room',
    isPrimary: true,
    moderationStatus: 'approved',
    sampleAsset: 'assets/photos/bed_02.webp',
  ),
  PhotoSlot(
    label: 'Kitchen',
    isPrimary: false,
    moderationStatus: 'approved',
    sampleAsset: 'assets/photos/kitchen_01.webp',
  ),
  PhotoSlot(
    label: 'WC',
    isPrimary: false,
    moderationStatus: 'approved',
    sampleAsset: 'assets/photos/bath_01.webp',
  ),
  PhotoSlot(
    label: 'Hall',
    isPrimary: false,
    moderationStatus: 'approved',
    sampleAsset: 'assets/photos/living_01.webp',
  ),
  PhotoSlot(
    label: 'Balcony',
    isPrimary: false,
    moderationStatus: 'approved',
    sampleAsset: 'assets/photos/balcony_01.webp',
  ),
  PhotoSlot(
    label: 'Building exterior',
    isPrimary: false,
    moderationStatus: 'approved',
    sampleAsset: 'assets/photos/exterior_01.webp',
  ),
];

const photoTips = <String>[
  'The room photo must be first, and it must be the space you are offering.',
  'Then kitchen, WC, hall, balcony if there is one, and the building exterior.',
  'Show the whole space from the door to the opposite wall.',
  'Use clear, well-lit photos. Skip blurry, dark, or close-up shots.',
  'At least 3 photos are required. Balcony is optional.',
];

/// Floor number applies to a stacked building, not a house or a villa.
bool floorApplies(String buildingKind) {
  return buildingKind == 'apartment' ||
      buildingKind == 'floor' ||
      buildingKind == 'pg';
}

/// Flatmate details are only for shared accommodation.
bool showsFlatmates(ListingDraft draft) {
  return draft.listingIntent == 'room' ||
      draft.listingIntent == 'pg' ||
      draft.listingIntent == 'shared_space';
}

bool draftPhotosVerified(ListingDraft draft) {
  if (draft.photos.length < 3) {
    return false;
  }
  return draft.photos.every((photo) => photo.moderationStatus == 'approved');
}

String assetForPhoto(PhotoSlot photo) {
  final sample = photo.sampleAsset;
  if (sample != null && sample.isNotEmpty) {
    return sample;
  }
  switch (photo.label.trim().toLowerCase()) {
    case 'kitchen':
      return 'assets/photos/kitchen_01.webp';
    case 'wc':
    case 'bathroom':
      return 'assets/photos/bath_01.webp';
    case 'hall':
    case 'living room':
    case 'living':
      return 'assets/photos/living_01.webp';
    case 'balcony':
      return 'assets/photos/balcony_01.webp';
    case 'building exterior':
    case 'exterior':
      return 'assets/photos/exterior_01.webp';
    default:
      return 'assets/photos/bed_01.webp';
  }
}

/// What still blocks publish. Older drafts keep the original checks.
List<String> releaseGaps(ListingDraft draft) {
  if (draft.listingIntent.isEmpty) {
    return draft.publishBlockers();
  }
  return wizardGaps(draft);
}

/// Mandatory answers for the 8-section wizard.
List<String> wizardGaps(ListingDraft draft) {
  final gaps = <String>[];
  if (draft.listingIntent.isEmpty) {
    gaps.add('Choose what you want to list.');
  }
  if (draft.title.trim().length < 3) {
    gaps.add('Add a title of at least 3 characters.');
  }
  if (draft.city.trim().isEmpty) {
    gaps.add('Choose a city.');
  }
  if (draft.locality.trim().isEmpty) {
    gaps.add('Add a locality.');
  }
  if (draft.buildingName.trim().isEmpty) {
    gaps.add('Add the tower or building name.');
  }
  if (draft.buildingKind.isEmpty) {
    gaps.add('Choose a property type.');
  }
  if (draft.configuration.isEmpty) {
    gaps.add('Choose a configuration.');
  }
  if (draft.areaSqft == null) {
    gaps.add('Enter the total area in sq ft.');
  }
  if (draft.rentableArea.isEmpty) {
    gaps.add('Choose the area available for rent.');
  }
  if (floorApplies(draft.buildingKind) &&
      (draft.floorNo == null || draft.totalFloors == null)) {
    gaps.add('Enter the floor number and the total floors.');
  }
  if (draft.nearby.length < nearbyKinds.length) {
    gaps.add('Add nearby places, with travel time for each.');
  } else if (draft.nearby.any((place) => place.minutes <= 0)) {
    gaps.add('Enter a travel time in minutes for each nearby place.');
  }
  if (draft.parkingKind.isEmpty) {
    gaps.add('Choose parking for a car, a bike, or none.');
  }
  if (draft.propertyAgeText.trim().isEmpty) {
    gaps.add('Enter the age of the property.');
  }
  if (draft.wcType.isEmpty) {
    gaps.add('Choose a separate or shared WC.');
  }
  if (draft.waterSupply.isEmpty || draft.waterHours.trim().isEmpty) {
    gaps.add('Choose the water supply and the hours.');
  }
  if (draft.petsChoice == null) {
    gaps.add('Say whether pets are allowed.');
  }
  if (draft.guestsAllowed == null) {
    gaps.add('Say whether guests are allowed.');
  }
  if (draft.nonVegChoice == null) {
    gaps.add('Say whether non-veg is allowed.');
  }
  if (draft.drinkingAllowed == null) {
    gaps.add('Say whether drinking is allowed.');
  }
  if (draft.partyingAllowed == null) {
    gaps.add('Say whether partying is allowed.');
  }
  if (draft.suitableFor.isEmpty) {
    gaps.add('Choose who the home suits.');
  }
  if (draft.genderPreference.isEmpty) {
    gaps.add('Choose who the home is open for.');
  }
  if (draft.preferredOccupation.isEmpty) {
    gaps.add('Choose a preferred occupation.');
  }
  if (draft.cookService == null) {
    gaps.add('Say whether cook service is available.');
  }
  if (draft.maidService == null) {
    gaps.add('Say whether maid service is available.');
  }
  if (draft.possessionDate.trim().isEmpty) {
    gaps.add('Add a possession date.');
  }
  final rent = draft.rentInr;
  if (rent == null || rent <= 0) {
    gaps.add('Enter a monthly rent in rupees.');
  }
  gaps.addAll(photoSequenceGaps(draft.photos));
  gaps.addAll(draft.persistBlockers());
  final unique = <String>[];
  for (final gap in gaps) {
    if (!unique.contains(gap)) {
      unique.add(gap);
    }
  }
  return unique;
}

List<String> photoSequenceGaps(List<PhotoSlot> photos) {
  final gaps = <String>[];
  if (photos.length < 3) {
    gaps.add('Add at least 3 photos.');
  }
  if (photos.isEmpty ||
      photos.first.label != 'Room' ||
      !photos.first.isPrimary) {
    gaps.add('The first photo must be the room.');
  }
  final labels = [for (final photo in photos) photo.label];
  for (final required in const ['Room', 'Kitchen', 'WC']) {
    if (!labels.contains(required)) {
      gaps.add('Add a $required photo.');
    }
  }
  var last = -1;
  for (final label in labels) {
    final index = photoSequence.indexOf(label);
    if (index < 0 || index < last) {
      gaps.add(
        'Keep photos in sequence: Room, Kitchen, WC, Hall, Balcony, then the building exterior.',
      );
      break;
    }
    last = index;
  }
  return gaps;
}

class RentingCost {
  const RentingCost({
    required this.rent,
    required this.deposit,
    required this.brokerage,
    required this.oneTime,
    required this.maintenance,
    required this.electricity,
    required this.water,
    required this.wifi,
    required this.otherMonthly,
  });

  final int rent;
  final int deposit;
  final int brokerage;
  final int oneTime;
  final int maintenance;
  final int electricity;
  final int water;
  final int wifi;
  final int otherMonthly;

  int get moveInTotal => deposit + brokerage + oneTime;

  int get monthlyTotal =>
      rent + maintenance + electricity + water + wifi + otherMonthly;

  static int _money(int? amount) => amount == null || amount < 0 ? 0 : amount;

  factory RentingCost.fromDraft(ListingDraft draft) {
    final deposit = int.tryParse(draft.depositText.trim()) ?? 0;
    return RentingCost(
      rent: _money(draft.rentInr),
      deposit: deposit < 0 ? 0 : deposit,
      brokerage: _money(draft.brokerageInr),
      oneTime: _money(draft.oneTimeInr),
      maintenance: _money(draft.maintenanceInr),
      electricity: _money(draft.electricityInr),
      water: _money(draft.waterChargeInr),
      wifi: _money(draft.wifiChargeInr),
      otherMonthly: _money(draft.otherMonthlyInr),
    );
  }
}

/// Same locality always returns the same places. Travel time is included.
List<NearbyPlace> nearbyPlacesFor({
  required String city,
  required String locality,
}) {
  final name = locality.trim().toLowerCase();
  if (name.isEmpty) {
    return const [];
  }
  final known = _knownNearby[name];
  if (known != null) {
    return known;
  }
  return _variedNearby(city.trim(), locality.trim());
}

List<NearbyPlace> _variedNearby(String city, String locality) {
  final hash = _hash('$city|$locality');
  final airport = city.toLowerCase() == 'mumbai'
      ? 'CSMI Airport'
      : 'Nearest airport';
  final seeds = <(String, String, double, double, int)>[
    ('metro', 'Metro near $locality', 0.6, 1.4, 6),
    ('train', 'Railway station near $locality', 0.5, 2.2, 7),
    ('bus', 'Bus stop near $locality', 0.2, 0.6, 8),
    ('airport', airport, 6.0, 10.0, 3),
    ('hospital', 'Hospital near $locality', 0.8, 1.6, 6),
    ('supermarket', 'Grocery near $locality', 0.3, 0.8, 8),
    ('mall', 'Mall near $locality', 1.0, 2.4, 6),
    ('movie', 'Cinema near $locality', 0.9, 1.8, 6),
    ('gym', 'Gym near $locality', 0.4, 1.1, 7),
  ];
  return [
    for (var index = 0; index < seeds.length; index++)
      _place(
        seeds[index].$1,
        seeds[index].$2,
        _km(hash, index, seeds[index].$3, seeds[index].$4),
        seeds[index].$5,
      ),
  ];
}

NearbyPlace _place(String kind, String name, double km, int pace) {
  final minutes = (km * pace).round().clamp(2, 90);
  return NearbyPlace(kind: kind, name: name, km: km, minutes: minutes);
}

double _km(int hash, int salt, double base, double spread) {
  final n = (hash + salt * 97) % 100;
  final value = base + spread * n / 100;
  return (value * 10).round() / 10;
}

int _hash(String text) {
  var hash = 17;
  for (final unit in text.codeUnits) {
    hash = (hash * 33 + unit) & 0x7fffffff;
  }
  return hash;
}

const _knownNearby = <String, List<NearbyPlace>>{
  'bandra west': [
    NearbyPlace(kind: 'metro', name: 'Bandra West Metro', km: 0.8, minutes: 5),
    NearbyPlace(
      kind: 'train',
      name: 'Bandra railway station',
      km: 0.8,
      minutes: 8,
    ),
    NearbyPlace(kind: 'bus', name: 'S.V. Road bus stop', km: 0.4, minutes: 3),
    NearbyPlace(kind: 'airport', name: 'CSMI Airport', km: 8.5, minutes: 30),
    NearbyPlace(
      kind: 'hospital',
      name: 'Lilavati Hospital',
      km: 1.1,
      minutes: 6,
    ),
    NearbyPlace(
      kind: 'supermarket',
      name: "Nature's Basket, Pali Hill",
      km: 0.5,
      minutes: 4,
    ),
    NearbyPlace(kind: 'mall', name: 'Linking Road', km: 1.6, minutes: 10),
    NearbyPlace(
      kind: 'movie',
      name: 'G7 Multiplex, Bandra West',
      km: 1.4,
      minutes: 9,
    ),
    NearbyPlace(
      kind: 'gym',
      name: 'Talwalkars, Pali Hill',
      km: 0.7,
      minutes: 5,
    ),
  ],
  'andheri west': [
    NearbyPlace(kind: 'metro', name: 'Andheri Metro', km: 0.6, minutes: 6),
    NearbyPlace(
      kind: 'train',
      name: 'Andheri railway station',
      km: 0.5,
      minutes: 7,
    ),
    NearbyPlace(
      kind: 'bus',
      name: 'Andheri station bus stop',
      km: 0.3,
      minutes: 4,
    ),
    NearbyPlace(kind: 'airport', name: 'CSMI Airport', km: 4.2, minutes: 18),
    NearbyPlace(
      kind: 'hospital',
      name: 'Kokilaben Hospital',
      km: 2.4,
      minutes: 12,
    ),
    NearbyPlace(
      kind: 'supermarket',
      name: 'DMart, Andheri West',
      km: 0.9,
      minutes: 8,
    ),
    NearbyPlace(kind: 'mall', name: 'Infiniti Mall', km: 1.3, minutes: 9),
    NearbyPlace(kind: 'movie', name: 'PVR Infiniti Mall', km: 1.3, minutes: 9),
    NearbyPlace(kind: 'gym', name: "Gold's Gym, Andheri", km: 0.8, minutes: 7),
  ],
  'powai': [
    NearbyPlace(kind: 'metro', name: 'Saki Naka Metro', km: 2.1, minutes: 10),
    NearbyPlace(
      kind: 'train',
      name: 'Kanjurmarg railway station',
      km: 3.4,
      minutes: 14,
    ),
    NearbyPlace(kind: 'bus', name: 'Powai bus stop', km: 0.4, minutes: 4),
    NearbyPlace(kind: 'airport', name: 'CSMI Airport', km: 6.5, minutes: 25),
    NearbyPlace(
      kind: 'hospital',
      name: 'Hiranandani Hospital',
      km: 0.8,
      minutes: 6,
    ),
    NearbyPlace(
      kind: 'supermarket',
      name: 'DMart, Hiranandani',
      km: 0.6,
      minutes: 5,
    ),
    NearbyPlace(kind: 'mall', name: 'Galleria, Powai', km: 0.7, minutes: 6),
    NearbyPlace(kind: 'movie', name: 'PVR, Hiranandani', km: 1.1, minutes: 8),
    NearbyPlace(kind: 'gym', name: "Gold's Gym, Powai", km: 0.9, minutes: 7),
  ],
  'dadar': [
    NearbyPlace(kind: 'metro', name: 'Prabhadevi Metro', km: 1.2, minutes: 8),
    NearbyPlace(
      kind: 'train',
      name: 'Dadar railway station',
      km: 0.4,
      minutes: 5,
    ),
    NearbyPlace(kind: 'bus', name: 'Dadar TT bus stop', km: 0.3, minutes: 3),
    NearbyPlace(kind: 'airport', name: 'CSMI Airport', km: 12, minutes: 40),
    NearbyPlace(kind: 'hospital', name: 'KEM Hospital', km: 1.6, minutes: 10),
    NearbyPlace(
      kind: 'supermarket',
      name: 'Star Bazaar, Dadar',
      km: 0.7,
      minutes: 6,
    ),
    NearbyPlace(
      kind: 'mall',
      name: 'Kohinoor Square, Dadar',
      km: 1.1,
      minutes: 8,
    ),
    NearbyPlace(
      kind: 'movie',
      name: 'Plaza Cinema, Dadar',
      km: 0.8,
      minutes: 7,
    ),
    NearbyPlace(kind: 'gym', name: 'Talwalkars, Dadar', km: 0.6, minutes: 5),
  ],
  'juhu': [
    NearbyPlace(kind: 'metro', name: 'D.N. Nagar Metro', km: 2.2, minutes: 12),
    NearbyPlace(
      kind: 'train',
      name: 'Vile Parle railway station',
      km: 2.4,
      minutes: 12,
    ),
    NearbyPlace(kind: 'bus', name: 'Juhu bus stop', km: 0.3, minutes: 4),
    NearbyPlace(kind: 'airport', name: 'CSMI Airport', km: 5.5, minutes: 20),
    NearbyPlace(
      kind: 'hospital',
      name: 'Nanavati Hospital',
      km: 3.2,
      minutes: 14,
    ),
    NearbyPlace(
      kind: 'supermarket',
      name: 'Smart Bazaar, Juhu',
      km: 0.6,
      minutes: 5,
    ),
    NearbyPlace(
      kind: 'mall',
      name: 'Juhu Shopping Centre',
      km: 0.8,
      minutes: 6,
    ),
    NearbyPlace(kind: 'movie', name: 'PVR Juhu', km: 1.2, minutes: 8),
    NearbyPlace(kind: 'gym', name: 'Talwalkars, Juhu', km: 0.7, minutes: 6),
  ],
  'goregaon east': [
    NearbyPlace(kind: 'metro', name: 'Goregaon Metro', km: 1.4, minutes: 8),
    NearbyPlace(
      kind: 'train',
      name: 'Goregaon railway station',
      km: 1.6,
      minutes: 10,
    ),
    NearbyPlace(kind: 'bus', name: 'Film City bus stop', km: 0.5, minutes: 4),
    NearbyPlace(kind: 'airport', name: 'CSMI Airport', km: 7.5, minutes: 28),
    NearbyPlace(
      kind: 'hospital',
      name: 'Lifeline Hospital, Goregaon',
      km: 1.2,
      minutes: 8,
    ),
    NearbyPlace(
      kind: 'supermarket',
      name: 'DMart, Goregaon East',
      km: 0.8,
      minutes: 6,
    ),
    NearbyPlace(kind: 'mall', name: 'Oberoi Mall', km: 1.8, minutes: 10),
    NearbyPlace(kind: 'movie', name: 'PVR Oberoi Mall', km: 1.8, minutes: 10),
    NearbyPlace(kind: 'gym', name: 'Gold Gym, Goregaon', km: 0.9, minutes: 7),
  ],
  'malad west': [
    NearbyPlace(kind: 'metro', name: 'Malad Metro', km: 1.1, minutes: 7),
    NearbyPlace(
      kind: 'train',
      name: 'Malad railway station',
      km: 1.3,
      minutes: 9,
    ),
    NearbyPlace(kind: 'bus', name: 'Malad West bus stop', km: 0.4, minutes: 4),
    NearbyPlace(kind: 'airport', name: 'CSMI Airport', km: 10, minutes: 35),
    NearbyPlace(
      kind: 'hospital',
      name: 'Thunga Hospital, Malad',
      km: 1.0,
      minutes: 7,
    ),
    NearbyPlace(
      kind: 'supermarket',
      name: 'DMart, Malad West',
      km: 0.7,
      minutes: 6,
    ),
    NearbyPlace(
      kind: 'mall',
      name: 'Inorbit Mall, Malad',
      km: 2.2,
      minutes: 12,
    ),
    NearbyPlace(
      kind: 'movie',
      name: 'INOX Inorbit, Malad',
      km: 2.2,
      minutes: 12,
    ),
    NearbyPlace(kind: 'gym', name: 'Talwalkars, Malad', km: 0.8, minutes: 6),
  ],
  'chembur': [
    NearbyPlace(kind: 'metro', name: 'Chembur Metro', km: 0.9, minutes: 6),
    NearbyPlace(
      kind: 'train',
      name: 'Chembur railway station',
      km: 1.5,
      minutes: 9,
    ),
    NearbyPlace(
      kind: 'bus',
      name: 'Chembur Naka bus stop',
      km: 0.4,
      minutes: 4,
    ),
    NearbyPlace(kind: 'airport', name: 'CSMI Airport', km: 8.0, minutes: 28),
    NearbyPlace(
      kind: 'hospital',
      name: 'Apollo Spectra, Chembur',
      km: 1.3,
      minutes: 8,
    ),
    NearbyPlace(
      kind: 'supermarket',
      name: 'DMart, Chembur',
      km: 0.8,
      minutes: 6,
    ),
    NearbyPlace(
      kind: 'mall',
      name: 'K Star Mall, Chembur',
      km: 1.4,
      minutes: 9,
    ),
    NearbyPlace(
      kind: 'movie',
      name: 'Basant Cinema, Chembur',
      km: 1.1,
      minutes: 8,
    ),
    NearbyPlace(kind: 'gym', name: 'Talwalkars, Chembur', km: 0.9, minutes: 7),
  ],
  'mulund': [
    NearbyPlace(kind: 'metro', name: 'Mulund Metro', km: 1.6, minutes: 9),
    NearbyPlace(
      kind: 'train',
      name: 'Mulund railway station',
      km: 0.8,
      minutes: 7,
    ),
    NearbyPlace(kind: 'bus', name: 'Mulund bus depot', km: 0.6, minutes: 5),
    NearbyPlace(kind: 'airport', name: 'CSMI Airport', km: 14, minutes: 45),
    NearbyPlace(
      kind: 'hospital',
      name: 'Fortis Hospital, Mulund',
      km: 2.1,
      minutes: 10,
    ),
    NearbyPlace(
      kind: 'supermarket',
      name: 'DMart, Mulund',
      km: 0.7,
      minutes: 6,
    ),
    NearbyPlace(kind: 'mall', name: 'R Mall, Mulund', km: 1.2, minutes: 8),
    NearbyPlace(kind: 'movie', name: 'PVR R Mall, Mulund', km: 1.2, minutes: 8),
    NearbyPlace(kind: 'gym', name: 'Gold Gym, Mulund', km: 0.9, minutes: 7),
  ],
  'thane': [
    NearbyPlace(kind: 'metro', name: 'Teen Haath Naka', km: 2.4, minutes: 12),
    NearbyPlace(
      kind: 'train',
      name: 'Thane railway station',
      km: 1.8,
      minutes: 10,
    ),
    NearbyPlace(
      kind: 'bus',
      name: 'Thane station bus stop',
      km: 0.4,
      minutes: 4,
    ),
    NearbyPlace(kind: 'airport', name: 'CSMI Airport', km: 18, minutes: 50),
    NearbyPlace(
      kind: 'hospital',
      name: 'Jupiter Hospital, Thane',
      km: 3.5,
      minutes: 14,
    ),
    NearbyPlace(kind: 'supermarket', name: 'DMart, Thane', km: 0.9, minutes: 7),
    NearbyPlace(kind: 'mall', name: 'Viviana Mall', km: 2.8, minutes: 14),
    NearbyPlace(kind: 'movie', name: 'INOX Viviana Mall', km: 2.8, minutes: 14),
    NearbyPlace(kind: 'gym', name: 'Talwalkars, Thane', km: 1.1, minutes: 8),
  ],
};

/// Locality centre used on the public map. Never a building coordinate.
(double, double) approxPointFor(String city, String locality) {
  final key = '${city.trim().toLowerCase()}|${locality.trim().toLowerCase()}';
  return _points[key] ??
      _points[locality.trim().toLowerCase()] ??
      (city.trim().toLowerCase() == 'mumbai'
          ? (19.076, 72.877)
          : (19.076, 72.877));
}

const _points = <String, (double, double)>{
  'mumbai|bandra west': (19.060, 72.830),
  'bandra west': (19.060, 72.830),
  'mumbai|andheri west': (19.136, 72.830),
  'andheri west': (19.136, 72.830),
  'mumbai|powai': (19.118, 72.906),
  'powai': (19.118, 72.906),
  'mumbai|dadar': (19.018, 72.844),
  'dadar': (19.018, 72.844),
  'mumbai|juhu': (19.107, 72.826),
  'juhu': (19.107, 72.826),
  'mumbai|goregaon east': (19.166, 72.849),
  'goregaon east': (19.166, 72.849),
  'mumbai|malad west': (19.187, 72.835),
  'malad west': (19.187, 72.835),
  'mumbai|chembur': (19.052, 72.899),
  'chembur': (19.052, 72.899),
  'mumbai|mulund': (19.172, 72.956),
  'mulund': (19.172, 72.956),
  'mumbai|thane': (19.218, 72.978),
  'thane': (19.218, 72.978),
  'pune|baner': (18.559, 73.776),
  'baner': (18.559, 73.776),
  'bengaluru|koramangala': (12.935, 77.624),
  'koramangala': (12.935, 77.624),
};
