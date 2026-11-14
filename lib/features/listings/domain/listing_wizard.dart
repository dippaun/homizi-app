import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';

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
  ('room', 'A Room / Shared Room', 'Single room or double sharing'),
  ('whole_flat', 'A Whole Flat / Apartment', '1BHK, 2BHK, etc.'),
  ('pg', 'A Paying Guest (PG)', 'PG or hostel property'),
  (
    'shared_space',
    'Shared Space (I am an existing tenant)',
    'Looking for a flatmate / roomie',
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
    sampleAsset: 'assets/images/real/bedroom_b.webp',
  ),
  PhotoSlot(
    label: 'Kitchen',
    isPrimary: false,
    moderationStatus: 'approved',
    sampleAsset: 'assets/images/real/kitchen.webp',
  ),
  PhotoSlot(
    label: 'WC',
    isPrimary: false,
    moderationStatus: 'approved',
    sampleAsset: 'assets/images/real/bath.webp',
  ),
  PhotoSlot(
    label: 'Hall',
    isPrimary: false,
    moderationStatus: 'approved',
    sampleAsset: 'assets/images/real/living.webp',
  ),
  PhotoSlot(
    label: 'Balcony',
    isPrimary: false,
    moderationStatus: 'approved',
    sampleAsset: 'assets/images/real/balcony.webp',
  ),
  PhotoSlot(
    label: 'Building exterior',
    isPrimary: false,
    moderationStatus: 'approved',
    sampleAsset: 'assets/images/real/apartment.webp',
  ),
];

const photoTips = <String>[
  'Show the entire space from the door to the opposite wall.',
  'Use clear, well-lit photos.',
  'No blurry or dark photos.',
  'Follow the exact sequence.',
  'At least 3 photos are required. Balcony is optional.',
];

/// Labels on the photo step. Stored labels stay short for the sequence check.
String photoSlotTitle(String label) => switch (label) {
  'WC' => 'WC / Bathroom',
  'Hall' => 'Hall / Living Area',
  'Balcony' => 'Balcony (if available)',
  'Building exterior' => 'Building Exterior / Street View',
  'Room' => 'Room',
  _ => label,
};

/// Smallest photo the lister will publish. Sample assets have no bytes and pass.
const minListingPhotoWidth = 720;
const minListingPhotoHeight = 480;

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
      return 'assets/images/real/kitchen.webp';
    case 'wc':
    case 'bathroom':
      return 'assets/images/real/bath.webp';
    case 'hall':
    case 'living room':
    case 'living':
      return 'assets/images/real/living.webp';
    case 'balcony':
      return 'assets/images/real/balcony.webp';
    case 'building exterior':
    case 'exterior':
      return 'assets/images/real/apartment.webp';
    default:
      return 'assets/images/real/bedroom.webp';
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
  if (draft.nearby.length < nearbyKinds.length ||
      draft.nearby.any((place) => place.name.trim().isEmpty)) {
    gaps.add(
      'Add a name for each nearby place. Leave distance blank if maps cannot measure it.',
    );
  }
  gaps.addAll(photoQualityGaps(draft.photos));
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

/// Byte photos must be readable and at least 720×480. Sample assets have no
/// bytes and are the bundled photos, so they pass.
List<String> photoQualityGaps(List<PhotoSlot> photos) {
  final gaps = <String>[];
  for (final photo in photos) {
    final bytes = photo.bytes;
    if (bytes == null || bytes.isEmpty) {
      continue;
    }
    final size = imagePixelSize(bytes);
    final label = photoSlotTitle(photo.label);
    if (size == null || !photoMeetsMinResolution(size.$1, size.$2)) {
      gaps.add('Use a photo at least 720 by 480 pixels for $label.');
    }
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

/// Blank nearby rows. Names and distances stay empty.
///
/// This used to invent a place and a travel time for every locality. That
/// is gone. The host types each place, or LocationService fills a row only
/// when maps returns a measurement.
List<NearbyPlace> blankNearbyPlaces() {
  return [for (final kind in nearbyKinds) NearbyPlace(kind: kind, name: '')];
}

/// Names the host has declared, with no distance. Used when a draft must
/// publish without a maps key.
List<NearbyPlace> declaredNearbyPlaces() {
  return [
    for (final kind in nearbyKinds)
      NearbyPlace(kind: kind, name: nearbyKindLabel(kind)),
  ];
}

/// Rows for the nearby step. Empty when [locality] is blank.
/// Never invents a name, a kilometre, or a minute.
List<NearbyPlace> nearbyPlacesFor({
  required String city,
  required String locality,
}) {
  if (locality.trim().isEmpty) {
    return const [];
  }
  final rows = blankNearbyPlaces();
  // City is accepted for a later maps lookup. It never fills a name or a distance.
  if (city.trim().isEmpty) {
    return rows;
  }
  return rows;
}

/// Locality centre used on the public map. Never a building coordinate.
/// Known locality centres. Null when the locality is not in the table:
/// no city falls back to Mumbai coordinates any more.
(double, double)? approxPointFor(String city, String locality) {
  final key = '${city.trim().toLowerCase()}|${locality.trim().toLowerCase()}';
  return _points[key] ?? _points[locality.trim().toLowerCase()];
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
