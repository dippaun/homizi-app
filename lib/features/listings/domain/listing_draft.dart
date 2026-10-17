import 'dart:typed_data';

import 'package:homizi/features/discovery/domain/listing.dart';

class PhotoSlot {
  const PhotoSlot({
    required this.label,
    required this.isPrimary,
    this.bytes,
    this.contentType,
    this.storagePath,
    this.moderationStatus = 'pending',
    this.transferProgress,
    this.transferError,
    this.transferAttempt = 0,
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

  /// 0 while an upload is starting, 1 when the file is stored or ready.
  final double? transferProgress;

  /// Set when the last upload failed. Cleared by a retry.
  final String? transferError;
  final int transferAttempt;

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
    double? transferProgress,
    bool clearTransferProgress = false,
    String? transferError,
    bool clearTransferError = false,
    int? transferAttempt,
  }) {
    return PhotoSlot(
      label: label ?? this.label,
      isPrimary: isPrimary ?? this.isPrimary,
      bytes: clearBytes ? null : (bytes ?? this.bytes),
      contentType: clearContentType ? null : (contentType ?? this.contentType),
      storagePath: clearStoragePath ? null : (storagePath ?? this.storagePath),
      moderationStatus: moderationStatus ?? this.moderationStatus,
      transferProgress: clearTransferProgress
          ? null
          : (transferProgress ?? this.transferProgress),
      transferError: clearTransferError
          ? null
          : (transferError ?? this.transferError),
      transferAttempt: transferAttempt ?? this.transferAttempt,
    );
  }
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

  int? get areaSqft => _optionalBounded(areaText, min: 50, max: 20000);

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
    if (rent == null || rent < 0) {
      blockers.add('Enter a monthly rent in rupees.');
    }
    final depositText = this.depositText.trim();
    if (depositText.isNotEmpty) {
      final deposit = int.tryParse(depositText);
      if (deposit == null || deposit < 0) {
        blockers.add('Enter a deposit in rupees, or leave it blank.');
      }
    }
    if (maintenanceText.trim().isNotEmpty && maintenanceInr == null) {
      blockers.add('Enter maintenance in rupees, or leave it blank.');
    }
    if (brokerageText.trim().isNotEmpty && brokerageInr == null) {
      blockers.add(
        'Enter other monthly charges in rupees, or leave them blank.',
      );
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
    if (areaText.trim().isNotEmpty && areaSqft == null) {
      blockers.add(
        'Enter built-up area between 50 and 20000 sq ft, or leave it blank.',
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
    );
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
  final amount = int.tryParse(trimmed);
  if (amount == null || amount < 0) {
    return null;
  }
  return amount;
}
