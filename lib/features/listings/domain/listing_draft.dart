import 'dart:typed_data';

import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/listings/domain/photo_caption.dart';

class PhotoSlot {
  const PhotoSlot({
    required this.label,
    required this.isPrimary,
    this.bytes,
    this.contentType,
    this.storagePath,
    this.moderationStatus = 'pending',
    this.caption = '',
    this.transferProgress,
    this.transferError,
    this.transferAttempt = 0,
    this.sampleAsset,
  });

  final String label;
  final bool isPrimary;

  /// Living room, bedroom, kitchen, and bathroom come before exterior shots.
  bool get isRoom {
    switch (label.trim().toLowerCase()) {
      case 'living room':
      case 'living':
      case 'bedroom':
      case 'kitchen':
      case 'bathroom':
      case 'room':
      case 'hall':
      case 'wc':
      case 'balcony':
        return true;
      default:
        return false;
    }
  }

  /// File bytes chosen on this device. Cleared after a private upload.
  final Uint8List? bytes;

  /// `image/jpeg`, `image/png`, or `image/webp` when [bytes] is set.
  final String? contentType;

  /// Owner-scoped object name. Empty slots use a `.slot` path with no file.
  final String? storagePath;

  /// Read from the server for display. Clients cannot write this column.
  final String moderationStatus;

  /// Optional gallery sentence. Blank falls back to the room type.
  final String caption;

  /// 0 while an upload is starting, 1 when the file is stored or ready.
  final double? transferProgress;

  /// Set when the last upload failed. Cleared by a retry.
  final String? transferError;
  final int transferAttempt;

  /// Bundled demo image. Null for a photo the host picked on this device.
  final String? sampleAsset;

  PhotoSlot copyWith({
    String? label,
    bool? isPrimary,
    Uint8List? bytes,
    bool clearBytes = false,
    String? contentType,
    bool clearContentType = false,
    String? storagePath,
    bool clearStoragePath = false,
    String? moderationStatus,
    String? caption,
    double? transferProgress,
    bool clearTransferProgress = false,
    String? transferError,
    bool clearTransferError = false,
    int? transferAttempt,
    String? sampleAsset,
    bool clearSampleAsset = false,
  }) {
    return PhotoSlot(
      label: label ?? this.label,
      isPrimary: isPrimary ?? this.isPrimary,
      bytes: clearBytes ? null : (bytes ?? this.bytes),
      contentType: clearContentType ? null : (contentType ?? this.contentType),
      storagePath: clearStoragePath ? null : (storagePath ?? this.storagePath),
      moderationStatus: moderationStatus ?? this.moderationStatus,
      caption: caption ?? this.caption,
      transferProgress: clearTransferProgress
          ? null
          : (transferProgress ?? this.transferProgress),
      transferError: clearTransferError
          ? null
          : (transferError ?? this.transferError),
      transferAttempt: transferAttempt ?? this.transferAttempt,
      sampleAsset: clearSampleAsset ? null : (sampleAsset ?? this.sampleAsset),
    );
  }
}

/// One nearby place estimated from a locality. Minutes are the travel time.
class NearbyPlace {
  const NearbyPlace({
    required this.kind,
    required this.name,
    required this.km,
    required this.minutes,
  });

  /// metro, train, bus, airport, hospital, supermarket, mall, movie, or gym.
  final String kind;
  final String name;
  final double km;
  final int minutes;

  NearbyPlace copyWith({String? name, double? km, int? minutes}) {
    return NearbyPlace(
      kind: kind,
      name: name ?? this.name,
      km: km ?? this.km,
      minutes: minutes ?? this.minutes,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NearbyPlace &&
        other.kind == kind &&
        other.name == name &&
        other.km == km &&
        other.minutes == minutes;
  }

  @override
  int get hashCode => Object.hash(kind, name, km, minutes);
}

const listingAmenities = <String>[
  'lift',
  'power_backup',
  'parking',
  'wifi',
  'washing_machine',
  'water_purifier',
  'balcony',
  'security',
  'gym',
  'wardrobes',
  'fridge',
  'ac',
  'fans',
  'tv',
  'gas_pipeline',
];

/// In-flat amenities on the property step. A subset of [listingAmenities].
const inFlatAmenityKeys = <String>[
  'wifi',
  'fridge',
  'ac',
  'fans',
  'washing_machine',
  'tv',
  'gas_pipeline',
];

const listingRestrictions = <String>['no_pets', 'no_smoking', 'no_parties'];

const listingSuitability = <String>[
  'family',
  'working_professionals',
  'students',
  'couple',
];

String listingAmenityLabel(String key) => switch (key) {
  'lift' => 'Lift',
  'power_backup' => 'Power backup',
  'parking' => 'Parking',
  'wifi' => 'Wifi',
  'washing_machine' => 'Washing machine',
  'water_purifier' => 'Water purifier',
  'balcony' => 'Balcony',
  'security' => 'Security',
  'gym' => 'Gym',
  'wardrobes' => 'Wardrobes',
  'fridge' => 'Fridge',
  'ac' => 'AC',
  'fans' => 'Fans',
  'tv' => 'TV',
  'gas_pipeline' => 'Gas pipeline',
  _ => key,
};

String listingRestrictionLabel(String key) => switch (key) {
  'no_pets' => 'No pets',
  'no_smoking' => 'No smoking',
  'no_parties' => 'No loud parties',
  _ => key,
};

String listingSuitabilityLabel(String key) => switch (key) {
  'family' => 'Family',
  'working_professionals' => 'Working professionals',
  'students' => 'Students',
  'couple' => 'Couple',
  _ => key,
};

class ListingDraft {
  const ListingDraft({
    this.id,
    this.title = '',
    this.city = '',
    this.locality = '',
    this.rentText = '',
    this.depositText = '',
    this.maintenanceText = '',
    this.brokerageText = '',
    this.furnishing = 'semi_furnished',
    this.propertyType = 'apartment',
    this.occupancy = 1,
    this.amenities = const [],
    this.restrictions = const [],
    this.suitability = const [],
    this.addressLine = '',
    this.landmark = '',
    this.photos = const [],
    this.areaText = '',
    this.preferredTenants = const [],
    this.parking = false,
    this.petsAllowed = false,
    this.nonVegAllowed = false,
    this.gatedSociety = false,
    this.floorText = '',
    this.totalFloorsText = '',
    this.listedBy = 'host',
    this.brokerageTerms = '',
    this.listingIntent = '',
    this.buildingName = '',
    this.buildingKind = '',
    this.configuration = '',
    this.rentableArea = '',
    this.nearby = const [],
    this.nearbyEdited = false,
    this.parkingKind = '',
    this.propertyAgeText = '',
    this.wcType = '',
    this.waterSupply = '',
    this.waterHours = '',
    this.inFlatAmenities = const [],
    this.petsChoice,
    this.guestsAllowed,
    this.drinkingAllowed,
    this.nonVegChoice,
    this.partyingAllowed,
    this.suitableFor = const [],
    this.genderPreference = '',
    this.preferredOccupation = '',
    this.cookService,
    this.maidService,
    this.flatmatesBrief = '',
    this.linkFlatmateProfiles = false,
    this.possessionDate = '',
    this.highlights = '',
    this.oneTimeChargesText = '',
    this.electricityText = '',
    this.waterChargeText = '',
    this.wifiChargeText = '',
    this.otherMonthlyText = '',
  });

  /// Client-generated id so a later save updates the same row.
  final String? id;
  final String title;
  final String city;
  final String locality;
  final String rentText;
  final String depositText;
  final String maintenanceText;
  final String brokerageText;
  final String furnishing;
  final String propertyType;
  final int occupancy;
  final List<String> amenities;
  final List<String> restrictions;
  final List<String> suitability;

  /// Street line stored only in property_private_details. Explore never reads it.
  final String addressLine;
  final String landmark;
  final List<PhotoSlot> photos;

  /// Slice B owns the posting wizard. These fields stay on the draft so both
  /// the current editor and that wizard write the same columns.
  final String areaText;
  final List<String> preferredTenants;
  final bool parking;
  final bool petsAllowed;
  final bool nonVegAllowed;
  final bool gatedSociety;
  final String floorText;
  final String totalFloorsText;

  /// `host` or `broker`. Broker listings show a Broker chip.
  final String listedBy;

  /// Free-text brokerage terms, for example "One month rent on the agreement".
  final String brokerageTerms;

  /// `room`, `whole_flat`, `pg`, or `shared_space`. Empty on older drafts.
  final String listingIntent;

  /// Tower or building name. A street line still lives in [addressLine].
  final String buildingName;

  /// `apartment`, `house`, `pg`, `villa`, or `floor`.
  final String buildingKind;

  /// `1rk`, `1bhk`, `2bhk`, `3bhk`, `4bhk`, or `4plus`.
  final String configuration;

  /// `single`, `double`, or `entire`.
  final String rentableArea;
  final List<NearbyPlace> nearby;
  final bool nearbyEdited;

  /// `car`, `bike`, or `none`.
  final String parkingKind;
  final String propertyAgeText;

  /// `separate` or `shared`.
  final String wcType;

  /// `municipal` or `tanker`.
  final String waterSupply;
  final String waterHours;
  final List<String> inFlatAmenities;

  /// Null until the host answers. Scoring never reads these preferences.
  final bool? petsChoice;
  final bool? guestsAllowed;
  final bool? drinkingAllowed;
  final bool? nonVegChoice;
  final bool? partyingAllowed;

  /// `bachelors`, `couple`, and `married`. A host preference, not a score input.
  final List<String> suitableFor;

  /// `male`, `female`, or `any`. Shown on the listing. Not a match score input.
  final String genderPreference;

  /// `working_professional`, `student`, `actor`, or `others`.
  final String preferredOccupation;
  final bool? cookService;
  final bool? maidService;
  final String flatmatesBrief;
  final bool linkFlatmateProfiles;
  final String possessionDate;
  final String highlights;
  final String oneTimeChargesText;
  final String electricityText;
  final String waterChargeText;
  final String wifiChargeText;
  final String otherMonthlyText;

  int? get oneTimeInr => _optionalMoney(oneTimeChargesText);

  int? get electricityInr => _optionalMoney(electricityText);

  int? get waterChargeInr => _optionalMoney(waterChargeText);

  int? get wifiChargeInr => _optionalMoney(wifiChargeText);

  int? get otherMonthlyInr => _optionalMoney(otherMonthlyText);

  int? get areaSqft => _optionalBounded(areaText, min: 120, max: 20000);

  int? get floorNo => _optionalBounded(floorText, min: 0, max: 60);

  int? get totalFloors => _optionalBounded(totalFloorsText, min: 1, max: 60);

  int? get rentInr => int.tryParse(rentText.trim());

  int? get maintenanceInr => _optionalMoney(maintenanceText);

  int? get brokerageInr => _optionalMoney(brokerageText);

  /// Fields the database will accept on a draft row. Rent may be zero here.
  List<String> persistBlockers() {
    final blockers = <String>[];
    final trimmedTitle = title.trim();
    if (trimmedTitle.length < 3) {
      blockers.add('Add a title of at least 3 characters.');
    }
    if (trimmedTitle.length > 120) {
      blockers.add('Keep the title to 120 characters or fewer.');
    }
    if (city.trim().isEmpty) {
      blockers.add('Choose a city.');
    }
    if (locality.trim().isEmpty) {
      blockers.add('Add a locality.');
    }
    final rent = rentInr;
    if (rentText.trim().isNotEmpty && !_plainAmount(rentText)) {
      blockers.add('Enter the rent as a whole number without leading zeros.');
    } else if (rent == null || rent < 0) {
      blockers.add('Enter a monthly rent in rupees.');
    }
    final depositText = this.depositText.trim();
    if (depositText.isNotEmpty && !_plainAmount(depositText)) {
      blockers.add(
        'Enter the deposit as a whole number without leading zeros.',
      );
    } else if (depositText.isNotEmpty) {
      final deposit = int.tryParse(depositText);
      if (deposit == null || deposit < 0) {
        blockers.add('Enter a deposit in rupees, or leave it blank.');
      }
    }
    if (maintenanceText.trim().isNotEmpty && !_plainAmount(maintenanceText)) {
      blockers.add(
        'Enter maintenance as a whole number without leading zeros.',
      );
    } else if (maintenanceText.trim().isNotEmpty && maintenanceInr == null) {
      blockers.add('Enter maintenance in rupees, or leave it blank.');
    }
    if (brokerageText.trim().isNotEmpty && !_plainAmount(brokerageText)) {
      blockers.add(
        'Enter other charges as a whole number without leading zeros.',
      );
    } else if (brokerageText.trim().isNotEmpty && brokerageInr == null) {
      blockers.add(
        'Enter other monthly charges in rupees, or leave them blank.',
      );
    }
    final maintenance = maintenanceInr;
    if (rent != null && rent > 0 && maintenance != null && maintenance > rent) {
      blockers.add('Maintenance cannot be higher than the monthly rent.');
    }
    if (occupancy < 1 || occupancy > 20) {
      blockers.add('Occupancy must be between 1 and 20.');
    }
    if (amenities.any((item) => !listingAmenities.contains(item))) {
      blockers.add('Choose amenities from the list.');
    }
    if (restrictions.any((item) => !listingRestrictions.contains(item))) {
      blockers.add('Choose restrictions from the list.');
    }
    if (suitability.any((item) => !listingSuitability.contains(item))) {
      blockers.add('Choose who the home suits from the list.');
    }
    if (addressLine.trim().length > 160) {
      blockers.add('Keep the street address to 160 characters.');
    }
    if (areaText.trim().isNotEmpty && !_plainAmount(areaText)) {
      blockers.add('Enter the area as a whole number without leading zeros.');
    } else if (areaText.trim().isNotEmpty && areaSqft == null) {
      blockers.add(
        'Enter built-up area between 120 and 20000 sq ft, or leave it blank.',
      );
    }
    if (floorText.trim().isNotEmpty && floorNo == null) {
      blockers.add('Enter a floor from 0 to 60, or leave it blank.');
    }
    if (totalFloorsText.trim().isNotEmpty && totalFloors == null) {
      blockers.add('Enter total floors from 1 to 60, or leave it blank.');
    }
    final floor = floorNo;
    final building = totalFloors;
    if (floor != null && building != null && floor > building) {
      blockers.add('Floor cannot be above the top floor.');
    }
    if (preferredTenants.any((item) => !preferredTenantKeys.contains(item))) {
      blockers.add('Choose preferred tenants from the list.');
    }
    if (listedBy != 'host' && listedBy != 'broker') {
      blockers.add('Choose host or broker for who is listing.');
    }
    if (brokerageTerms.trim().length > 160) {
      blockers.add('Keep brokerage terms to 160 characters.');
    }
    _checkOptionalMoney(
      blockers,
      oneTimeChargesText,
      'Enter one-time charges as a whole number without leading zeros.',
    );
    _checkOptionalMoney(
      blockers,
      electricityText,
      'Enter electricity as a whole number without leading zeros.',
    );
    _checkOptionalMoney(
      blockers,
      waterChargeText,
      'Enter water charges as a whole number without leading zeros.',
    );
    _checkOptionalMoney(
      blockers,
      wifiChargeText,
      'Enter the Wi-Fi charge as a whole number without leading zeros.',
    );
    _checkOptionalMoney(
      blockers,
      otherMonthlyText,
      'Enter other monthly charges as a whole number without leading zeros.',
    );
    final age = propertyAgeText.trim();
    if (age.isNotEmpty &&
        (!_plainAmount(age) || (int.tryParse(age) ?? 81) > 80)) {
      blockers.add('Enter the property age in years from 0 to 80.');
    }
    if (buildingName.trim().length > 80) {
      blockers.add('Keep the building name to 80 characters.');
    }
    if (waterHours.trim().length > 40) {
      blockers.add('Keep water hours to 40 characters.');
    }
    if (flatmatesBrief.trim().length > 240) {
      blockers.add('Keep the flatmate note to 240 characters.');
    }
    if (highlights.trim().length > 280) {
      blockers.add('Keep highlights to 280 characters.');
    }
    if (possessionDate.trim().length > 40) {
      blockers.add('Keep the possession date to 40 characters.');
    }
    if (inFlatAmenities.any((item) => !inFlatAmenityKeys.contains(item))) {
      blockers.add('Choose in-flat amenities from the list.');
    }
    for (final photo in photos) {
      final issue = listingCaptionRejection(photo.caption);
      if (issue != null && !blockers.contains(issue)) {
        blockers.add(issue);
      }
    }
    return blockers;
  }

  List<String> publishBlockers() {
    final blockers = [...persistBlockers()];
    final rent = rentInr;
    if ((rent == null || rent <= 0) &&
        !blockers.contains('Enter a monthly rent in rupees.')) {
      blockers.add('Enter a monthly rent in rupees.');
    }
    if (photos.length < 3) {
      blockers.add('Add at least 3 photos.');
    }
    if (photos.isNotEmpty && !photos.any((photo) => photo.isPrimary)) {
      blockers.add('Mark a primary photo.');
    }
    if (photos.length >= 3 &&
        !photos.any((photo) => photo.isPrimary && photo.isRoom)) {
      blockers.add('Mark a room as the primary photo.');
    }
    return blockers;
  }

  ListingDraft copyWith({
    String? id,
    String? title,
    String? city,
    String? locality,
    String? rentText,
    String? depositText,
    String? maintenanceText,
    String? brokerageText,
    String? furnishing,
    String? propertyType,
    int? occupancy,
    List<String>? amenities,
    List<String>? restrictions,
    List<String>? suitability,
    String? addressLine,
    String? landmark,
    List<PhotoSlot>? photos,
    String? areaText,
    List<String>? preferredTenants,
    bool? parking,
    bool? petsAllowed,
    bool? nonVegAllowed,
    bool? gatedSociety,
    String? floorText,
    String? totalFloorsText,
    String? listedBy,
    String? brokerageTerms,
    String? listingIntent,
    String? buildingName,
    String? buildingKind,
    String? configuration,
    String? rentableArea,
    List<NearbyPlace>? nearby,
    bool? nearbyEdited,
    String? parkingKind,
    String? propertyAgeText,
    String? wcType,
    String? waterSupply,
    String? waterHours,
    List<String>? inFlatAmenities,
    bool? petsChoice,
    bool? guestsAllowed,
    bool? drinkingAllowed,
    bool? nonVegChoice,
    bool? partyingAllowed,
    List<String>? suitableFor,
    String? genderPreference,
    String? preferredOccupation,
    bool? cookService,
    bool? maidService,
    String? flatmatesBrief,
    bool? linkFlatmateProfiles,
    String? possessionDate,
    String? highlights,
    String? oneTimeChargesText,
    String? electricityText,
    String? waterChargeText,
    String? wifiChargeText,
    String? otherMonthlyText,
  }) {
    return ListingDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      rentText: rentText ?? this.rentText,
      depositText: depositText ?? this.depositText,
      maintenanceText: maintenanceText ?? this.maintenanceText,
      brokerageText: brokerageText ?? this.brokerageText,
      furnishing: furnishing ?? this.furnishing,
      propertyType: propertyType ?? this.propertyType,
      occupancy: occupancy ?? this.occupancy,
      amenities: amenities ?? this.amenities,
      restrictions: restrictions ?? this.restrictions,
      suitability: suitability ?? this.suitability,
      addressLine: addressLine ?? this.addressLine,
      landmark: landmark ?? this.landmark,
      photos: photos ?? this.photos,
      areaText: areaText ?? this.areaText,
      preferredTenants: preferredTenants ?? this.preferredTenants,
      parking: parking ?? this.parking,
      petsAllowed: petsAllowed ?? this.petsAllowed,
      nonVegAllowed: nonVegAllowed ?? this.nonVegAllowed,
      gatedSociety: gatedSociety ?? this.gatedSociety,
      floorText: floorText ?? this.floorText,
      totalFloorsText: totalFloorsText ?? this.totalFloorsText,
      listedBy: listedBy ?? this.listedBy,
      brokerageTerms: brokerageTerms ?? this.brokerageTerms,
      listingIntent: listingIntent ?? this.listingIntent,
      buildingName: buildingName ?? this.buildingName,
      buildingKind: buildingKind ?? this.buildingKind,
      configuration: configuration ?? this.configuration,
      rentableArea: rentableArea ?? this.rentableArea,
      nearby: nearby ?? this.nearby,
      nearbyEdited: nearbyEdited ?? this.nearbyEdited,
      parkingKind: parkingKind ?? this.parkingKind,
      propertyAgeText: propertyAgeText ?? this.propertyAgeText,
      wcType: wcType ?? this.wcType,
      waterSupply: waterSupply ?? this.waterSupply,
      waterHours: waterHours ?? this.waterHours,
      inFlatAmenities: inFlatAmenities ?? this.inFlatAmenities,
      petsChoice: petsChoice ?? this.petsChoice,
      guestsAllowed: guestsAllowed ?? this.guestsAllowed,
      drinkingAllowed: drinkingAllowed ?? this.drinkingAllowed,
      nonVegChoice: nonVegChoice ?? this.nonVegChoice,
      partyingAllowed: partyingAllowed ?? this.partyingAllowed,
      suitableFor: suitableFor ?? this.suitableFor,
      genderPreference: genderPreference ?? this.genderPreference,
      preferredOccupation: preferredOccupation ?? this.preferredOccupation,
      cookService: cookService ?? this.cookService,
      maidService: maidService ?? this.maidService,
      flatmatesBrief: flatmatesBrief ?? this.flatmatesBrief,
      linkFlatmateProfiles: linkFlatmateProfiles ?? this.linkFlatmateProfiles,
      possessionDate: possessionDate ?? this.possessionDate,
      highlights: highlights ?? this.highlights,
      oneTimeChargesText: oneTimeChargesText ?? this.oneTimeChargesText,
      electricityText: electricityText ?? this.electricityText,
      waterChargeText: waterChargeText ?? this.waterChargeText,
      wifiChargeText: wifiChargeText ?? this.wifiChargeText,
      otherMonthlyText: otherMonthlyText ?? this.otherMonthlyText,
    );
  }
}

void _checkOptionalMoney(List<String> blockers, String text, String message) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return;
  }
  if (!_plainAmount(trimmed) || _optionalMoney(trimmed) == null) {
    blockers.add(message);
  }
}

int? _optionalBounded(String text, {required int min, required int max}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final amount = int.tryParse(trimmed);
  if (amount == null || amount < min || amount > max) {
    return null;
  }
  return amount;
}

int? _optionalMoney(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return 0;
  }
  if (!_plainAmount(trimmed)) {
    return null;
  }
  final amount = int.tryParse(trimmed);
  if (amount == null || amount < 0) {
    return null;
  }
  return amount;
}

/// Digits only. `0` is allowed. `055` and `00` are not.
bool _plainAmount(String text) {
  final trimmed = text.trim();
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
    return false;
  }
  if (trimmed.length > 1 && trimmed.startsWith('0')) {
    return false;
  }
  return true;
}
