import 'dart:typed_data';

import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/photo_caption.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';

/// Columns granted to authenticated clients on insert. Status is absent on purpose.
const propertyInsertColumns = <String>[
  'id',
  'host_user_id',
  'title',
  'locality',
  'city',
  'address_visibility',
  'property_type',
  'furnishing',
  'rent_inr',
  'deposit_inr',
  'brokerage_inr',
  'maintenance_inr',
  'occupancy_max',
  'area_sqft',
  'preferred_tenants',
  'parking',
  'pets_allowed',
  'non_veg_allowed',
  'gated_society',
  'floor_no',
  'total_floors',
  'listed_by',
  'brokerage_terms',
];

const propertyUpdateColumns = <String>[
  'title',
  'locality',
  'city',
  'address_visibility',
  'property_type',
  'furnishing',
  'rent_inr',
  'deposit_inr',
  'brokerage_inr',
  'maintenance_inr',
  'occupancy_max',
  'area_sqft',
  'preferred_tenants',
  'parking',
  'pets_allowed',
  'non_veg_allowed',
  'gated_society',
  'floor_no',
  'total_floors',
  'listed_by',
  'brokerage_terms',
];

const featureColumns = <String>['property_id', 'feature_key', 'value'];

const privateDetailColumns = <String>[
  'property_id',
  'address_line',
  'landmark',
];

const photoSlotColumns = <String>[
  'property_id',
  'storage_path',
  'sort_order',
  'photo_type',
  'caption',
];

/// Writes that must stay server-side: listing status, verification, moderation,
/// contact fields, and street address.
const forbiddenClientWriteColumns = <String>{
  'status',
  'published_at',
  'verification_status',
  'moderation_status',
  'phone',
  'email',
  'address_line',
  'landmark',
  'latitude',
  'longitude',
};

String photoTypeForLabel(String label) {
  switch (label.trim().toLowerCase()) {
    case 'living room':
    case 'living':
      return 'living';
    case 'bedroom':
      return 'bedroom';
    case 'kitchen':
      return 'kitchen';
    case 'bathroom':
      return 'bathroom';
    case 'exterior':
    case 'building exterior':
      return 'exterior';
    case 'room':
      return 'bedroom';
    case 'wc':
      return 'bathroom';
    case 'hall':
      return 'living';
    case 'balcony':
      return 'other';
    default:
      return 'other';
  }
}

String labelForPhotoType(String photoType) => roomLabelForPhotoType(photoType);

/// Rooms first, with the primary room at sort_order 0.
/// Exterior and other shots follow. There is no is_primary column.
List<PhotoSlot> orderedPhotoSlots(List<PhotoSlot> photos) {
  final rooms = <PhotoSlot>[];
  final later = <PhotoSlot>[];
  for (final photo in photos) {
    if (photo.isRoom) {
      rooms.add(photo);
    } else {
      later.add(photo);
    }
  }
  final primaryIndex = rooms.indexWhere((photo) => photo.isPrimary);
  if (primaryIndex > 0) {
    final chosen = rooms.removeAt(primaryIndex);
    rooms.insert(0, chosen);
  }
  return [...rooms, ...later];
}

String photoSlotPath({
  required String userId,
  required String propertyId,
  required int sortOrder,
}) {
  return '$userId/$propertyId/$sortOrder.slot';
}

/// Search type derived from the wizard. Older drafts keep [ListingDraft.propertyType].
String storedPropertyType(ListingDraft draft) {
  switch (draft.listingIntent) {
    case 'room':
      return draft.rentableArea == 'double' ? 'shared_room' : 'private_room';
    case 'pg':
      return 'pg';
    case 'shared_space':
      return 'shared_room';
    case 'whole_flat':
      return switch (draft.buildingKind) {
        'house' => 'independent_house',
        'villa' => 'villa',
        'pg' => 'pg',
        _ => 'apartment',
      };
    default:
      return draft.propertyType;
  }
}

bool storedParking(ListingDraft draft) {
  switch (draft.parkingKind) {
    case 'none':
      return false;
    case 'car':
    case 'bike':
      return true;
    default:
      return draft.parking;
  }
}

int depositInrFor(ListingDraft draft) {
  final text = draft.depositText.trim();
  if (text.isEmpty) {
    return 0;
  }
  return int.tryParse(text) ?? 0;
}

int _nonNegativeMoney(int? amount) => amount == null || amount < 0 ? 0 : amount;

String addressVisibilityFor(ListingDraft draft) {
  return draft.addressLine.trim().isEmpty
      ? 'locality_only'
      : 'after_visit_accept';
}

Map<String, dynamic> propertyInsertPayload({
  required String id,
  required String hostUserId,
  required ListingDraft draft,
}) {
  return {
    'id': id,
    'host_user_id': hostUserId,
    'title': draft.title.trim(),
    'locality': draft.locality.trim(),
    'city': draft.city.trim(),
    'address_visibility': addressVisibilityFor(draft),
    'property_type': storedPropertyType(draft),
    'furnishing': draft.furnishing,
    'rent_inr': draft.rentInr ?? 0,
    'deposit_inr': depositInrFor(draft),
    'brokerage_inr': _nonNegativeMoney(draft.brokerageInr),
    'maintenance_inr': _nonNegativeMoney(draft.maintenanceInr),
    'occupancy_max': draft.occupancy,
    ..._exploreColumns(draft),
  };
}

Map<String, dynamic> propertyUpdatePayload(ListingDraft draft) {
  return {
    'title': draft.title.trim(),
    'locality': draft.locality.trim(),
    'city': draft.city.trim(),
    'address_visibility': addressVisibilityFor(draft),
    'property_type': storedPropertyType(draft),
    'furnishing': draft.furnishing,
    'rent_inr': draft.rentInr ?? 0,
    'deposit_inr': depositInrFor(draft),
    'brokerage_inr': _nonNegativeMoney(draft.brokerageInr),
    'maintenance_inr': _nonNegativeMoney(draft.maintenanceInr),
    'occupancy_max': draft.occupancy,
    ..._exploreColumns(draft),
  };
}

Map<String, dynamic> _exploreColumns(ListingDraft draft) {
  return {
    'area_sqft': draft.areaSqft,
    'preferred_tenants': draft.preferredTenants,
    'parking': storedParking(draft),
    'pets_allowed': draft.petsChoice ?? draft.petsAllowed,
    'non_veg_allowed': draft.nonVegChoice ?? draft.nonVegAllowed,
    'gated_society': draft.gatedSociety,
    'floor_no': draft.floorNo,
    'total_floors': draft.totalFloors,
    'listed_by': draft.listedBy == 'broker' ? 'broker' : 'host',
    'brokerage_terms': draft.brokerageTerms.trim().isEmpty
        ? null
        : draft.brokerageTerms.trim(),
  };
}

List<Map<String, dynamic>> featureRows({
  required String propertyId,
  required ListingDraft draft,
}) {
  final rows = <Map<String, dynamic>>[];
  for (final key in draft.amenities) {
    rows.add({
      'property_id': propertyId,
      'feature_key': 'amenity:$key',
      'value': 'yes',
    });
  }
  for (final key in draft.restrictions) {
    rows.add({
      'property_id': propertyId,
      'feature_key': 'restriction:$key',
      'value': 'yes',
    });
  }
  for (final key in draft.suitability) {
    rows.add({
      'property_id': propertyId,
      'feature_key': 'suitability:$key',
      'value': 'yes',
    });
  }
  rows.addAll(wizardFeatureRows(propertyId: propertyId, draft: draft));
  return rows;
}

/// Wizard answers that are not columns on `properties`.
/// Gender is stored here as a host preference. Scoring must not read it.
List<Map<String, dynamic>> wizardFeatureRows({
  required String propertyId,
  required ListingDraft draft,
}) {
  final rows = <Map<String, dynamic>>[];
  void add(String key, String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return;
    }
    rows.add({'property_id': propertyId, 'feature_key': key, 'value': value});
  }

  void addBool(String key, bool? value) {
    if (value == null) {
      return;
    }
    add(key, value ? 'yes' : 'no');
  }

  add('wizard:intent', draft.listingIntent);
  add('wizard:tower', draft.buildingName);
  add('wizard:kind', draft.buildingKind);
  add('wizard:config', draft.configuration);
  add('wizard:rentable', draft.rentableArea);
  add('wizard:parking', draft.parkingKind);
  add('wizard:age', draft.propertyAgeText);
  add('wizard:wc', draft.wcType);
  add('wizard:water', draft.waterSupply);
  add('wizard:hours', draft.waterHours);
  addBool('wizard:pets', draft.petsChoice);
  addBool('wizard:guests', draft.guestsAllowed);
  addBool('wizard:drinking', draft.drinkingAllowed);
  addBool('wizard:nonveg', draft.nonVegChoice);
  addBool('wizard:partying', draft.partyingAllowed);
  if (draft.suitableFor.isNotEmpty) {
    add('wizard:suitable', draft.suitableFor.join(','));
  }
  add('wizard:gender', draft.genderPreference);
  add('wizard:occupation', draft.preferredOccupation);
  addBool('wizard:cook', draft.cookService);
  addBool('wizard:maid', draft.maidService);
  add('wizard:flatmates', draft.flatmatesBrief);
  if (draft.linkFlatmateProfiles) {
    add('wizard:consent', 'yes');
  }
  add('wizard:possession', draft.possessionDate);
  add('wizard:highlights', draft.highlights);
  add('wizard:onetime', draft.oneTimeChargesText);
  add('wizard:power', draft.electricityText);
  add('wizard:water_inr', draft.waterChargeText);
  add('wizard:wifi_inr', draft.wifiChargeText);
  add('wizard:other_inr', draft.otherMonthlyText);
  for (final place in draft.nearby) {
    final name = place.name.replaceAll('|', '/');
    add('near:${place.kind}', '$name|${place.km}|${place.minutes}');
  }
  return rows;
}

/// Owner-only street line. Phone and email are not columns on this table.
Map<String, dynamic>? privateDetailPayload({
  required String propertyId,
  required ListingDraft draft,
}) {
  final line = draft.addressLine.trim();
  if (line.isEmpty) {
    return null;
  }
  final landmark = draft.landmark.trim();
  return {
    'property_id': propertyId,
    'address_line': line,
    'landmark': landmark.isEmpty ? null : landmark,
  };
}

List<Map<String, dynamic>> photoSlotRows({
  required String propertyId,
  required String userId,
  required List<PhotoSlot> photos,
}) {
  final ordered = orderedPhotoSlots(photos);
  return [
    for (var index = 0; index < ordered.length; index++)
      {
        'property_id': propertyId,
        'storage_path': _photoStoragePath(
          photo: ordered[index],
          userId: userId,
          propertyId: propertyId,
          sortOrder: index,
        ),
        'sort_order': index,
        'photo_type': photoTypeForLabel(ordered[index].label),
        'caption': _captionColumn(ordered[index].caption),
      },
  ];
}

class ListingPhotoUpload {
  const ListingPhotoUpload({
    required this.path,
    required this.bytes,
    required this.contentType,
  });

  final String path;
  final Uint8List bytes;
  final String contentType;
}

class ListingPhotoPlan {
  const ListingPhotoPlan({
    required this.photos,
    required this.rows,
    required this.uploads,
  });

  /// Slots to keep after a successful save. Bytes are cleared once a private
  /// object path exists.
  final List<PhotoSlot> photos;
  final List<Map<String, dynamic>> rows;
  final List<ListingPhotoUpload> uploads;

  bool get storedFile =>
      uploads.isNotEmpty || photos.any(photoReferencesStoredFile);
}

/// Plans owner-scoped uploads and the `property_photos` rows.
/// Moderation, contact fields, and street addresses are not included.
ListingPhotoPlan planListingPhotoWrites({
  required String userId,
  required String propertyId,
  required List<PhotoSlot> photos,
  required String Function() newFileId,
}) {
  if (!_safeSegment(userId) || !_safeSegment(propertyId)) {
    throw const PhotoUploadRejection('Photo paths stay under your account.');
  }
  for (final photo in photos) {
    final issue = listingCaptionRejection(photo.caption);
    if (issue != null) {
      throw PhotoUploadRejection(issue);
    }
  }
  final ordered = orderedPhotoSlots(photos);
  final prepared = <PhotoSlot>[];
  final uploads = <ListingPhotoUpload>[];
  for (final photo in ordered) {
    final bytes = photo.bytes;
    if (bytes == null) {
      final existing = photo.storagePath;
      if (existing != null &&
          !isOwnerScopedListingPhotoPath(existing, userId)) {
        throw const PhotoUploadRejection(
          'Photo paths stay under your account.',
        );
      }
      prepared.add(photo);
      continue;
    }
    final contentType = _normalizedContentType(photo.contentType ?? '');
    assertListingPhotoFile(bytes, contentType);
    final existing = photo.storagePath;
    final path = existing != null && isStoredImagePath(existing, userId)
        ? existing
        : listingPhotoObjectPath(
            userId: userId,
            propertyId: propertyId,
            fileId: newFileId(),
            contentType: contentType,
          );
    uploads.add(
      ListingPhotoUpload(path: path, bytes: bytes, contentType: contentType),
    );
    prepared.add(
      photo.copyWith(
        storagePath: path,
        clearBytes: true,
        clearContentType: true,
        moderationStatus: 'pending',
      ),
    );
  }
  final rows = photoSlotRows(
    propertyId: propertyId,
    userId: userId,
    photos: prepared,
  );
  return ListingPhotoPlan(photos: prepared, rows: rows, uploads: uploads);
}

bool _safeSegment(String value) {
  return RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(value);
}

String _normalizedContentType(String contentType) {
  return switch (listingPhotoExtension(contentType)) {
    'jpg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => throw const PhotoUploadRejection('Use a JPEG, PNG, or WebP photo.'),
  };
}

String _photoStoragePath({
  required PhotoSlot photo,
  required String userId,
  required String propertyId,
  required int sortOrder,
}) {
  final existing = photo.storagePath;
  if (existing == null) {
    return photoSlotPath(
      userId: userId,
      propertyId: propertyId,
      sortOrder: sortOrder,
    );
  }
  if (!isOwnerScopedListingPhotoPath(existing, userId)) {
    throw const PhotoUploadRejection('Photo paths stay under your account.');
  }
  return existing;
}

ListingDraft listingDraftFromRow(
  Map<String, dynamic> row,
  List<Map<String, dynamic>> photos, {
  List<Map<String, dynamic>> features = const [],
  Map<String, dynamic>? privateDetails,
}) {
  final ordered = [
    ...photos,
  ]..sort((a, b) => _asInt(a['sort_order']).compareTo(_asInt(b['sort_order'])));
  final furnishing = _text(row['furnishing']);
  final propertyType = _text(row['property_type']);
  return ListingDraft(
    id: row['id'] as String?,
    title: _text(row['title']),
    city: _text(row['city']),
    locality: _text(row['locality']),
    rentText: _moneyText(row['rent_inr']),
    depositText: _moneyText(row['deposit_inr'], blankWhenZero: true),
    maintenanceText: _moneyText(row['maintenance_inr'], blankWhenZero: true),
    brokerageText: _moneyText(row['brokerage_inr'], blankWhenZero: true),
    furnishing: _furnishingValues.contains(furnishing)
        ? furnishing
        : 'semi_furnished',
    propertyType: _propertyTypeValues.contains(propertyType)
        ? propertyType
        : 'apartment',
    occupancy: _occupancy(row['occupancy_max']),
    areaText: _optionalMoneyText(row['area_sqft']),
    preferredTenants: _tenants(row['preferred_tenants']),
    parking: row['parking'] == true,
    petsAllowed: row['pets_allowed'] == true,
    nonVegAllowed: row['non_veg_allowed'] == true,
    gatedSociety: row['gated_society'] == true,
    floorText: _optionalMoneyText(row['floor_no']),
    totalFloorsText: _optionalMoneyText(row['total_floors']),
    listedBy: row['listed_by'] == 'broker' ? 'broker' : 'host',
    brokerageTerms: _text(row['brokerage_terms']),
    amenities: _featureKeys(features, 'amenity'),
    restrictions: _featureKeys(features, 'restriction'),
    suitability: _featureKeys(features, 'suitability'),
    addressLine: _text(privateDetails?['address_line']),
    landmark: _text(privateDetails?['landmark']),
    photos: [
      for (final photo in ordered)
        PhotoSlot(
          label: labelForPhotoType(_text(photo['photo_type'])),
          isPrimary: _asInt(photo['sort_order']) == 0,
          storagePath: _optionalText(photo['storage_path']),
          moderationStatus: _moderation(photo['moderation_status']),
          caption: _text(photo['caption']),
        ),
    ],
  ).withWizardFeatures(features);
}

extension on ListingDraft {
  ListingDraft withWizardFeatures(List<Map<String, dynamic>> features) {
    String? read(String key) {
      for (final row in features) {
        if (row['feature_key'] == key) {
          final value = row['value'];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
      return null;
    }

    bool? readBool(String key) {
      final value = read(key);
      if (value == 'yes') {
        return true;
      }
      if (value == 'no') {
        return false;
      }
      return null;
    }

    final nearby = <NearbyPlace>[];
    for (final kind in const [
      'metro',
      'train',
      'bus',
      'airport',
      'hospital',
      'supermarket',
      'mall',
      'movie',
      'gym',
    ]) {
      final raw = read('near:$kind');
      if (raw == null) {
        continue;
      }
      final parts = raw.split('|');
      if (parts.length < 3) {
        continue;
      }
      final km = double.tryParse(parts[1]);
      final minutes = int.tryParse(parts[2]);
      if (km == null || minutes == null) {
        continue;
      }
      nearby.add(
        NearbyPlace(kind: kind, name: parts[0], km: km, minutes: minutes),
      );
    }
    final suitable = read('wizard:suitable');
    final flat = [
      for (final key in amenities)
        if (inFlatAmenityKeys.contains(key)) key,
    ];
    return copyWith(
      listingIntent: read('wizard:intent') ?? listingIntent,
      buildingName: read('wizard:tower') ?? buildingName,
      buildingKind: read('wizard:kind') ?? buildingKind,
      configuration: read('wizard:config') ?? configuration,
      rentableArea: read('wizard:rentable') ?? rentableArea,
      parkingKind: read('wizard:parking') ?? parkingKind,
      propertyAgeText: read('wizard:age') ?? propertyAgeText,
      wcType: read('wizard:wc') ?? wcType,
      waterSupply: read('wizard:water') ?? waterSupply,
      waterHours: read('wizard:hours') ?? waterHours,
      petsChoice: readBool('wizard:pets') ?? petsChoice,
      guestsAllowed: readBool('wizard:guests') ?? guestsAllowed,
      drinkingAllowed: readBool('wizard:drinking') ?? drinkingAllowed,
      nonVegChoice: readBool('wizard:nonveg') ?? nonVegChoice,
      partyingAllowed: readBool('wizard:partying') ?? partyingAllowed,
      suitableFor: suitable == null
          ? suitableFor
          : [
              for (final item in suitable.split(','))
                if (item == 'bachelors' ||
                    item == 'couple' ||
                    item == 'married')
                  item,
            ],
      genderPreference: read('wizard:gender') ?? genderPreference,
      preferredOccupation: read('wizard:occupation') ?? preferredOccupation,
      cookService: readBool('wizard:cook') ?? cookService,
      maidService: readBool('wizard:maid') ?? maidService,
      flatmatesBrief: read('wizard:flatmates') ?? flatmatesBrief,
      linkFlatmateProfiles:
          read('wizard:consent') == 'yes' || linkFlatmateProfiles,
      possessionDate: read('wizard:possession') ?? possessionDate,
      highlights: read('wizard:highlights') ?? highlights,
      oneTimeChargesText: read('wizard:onetime') ?? oneTimeChargesText,
      electricityText: read('wizard:power') ?? electricityText,
      waterChargeText: read('wizard:water_inr') ?? waterChargeText,
      wifiChargeText: read('wizard:wifi_inr') ?? wifiChargeText,
      otherMonthlyText: read('wizard:other_inr') ?? otherMonthlyText,
      nearby: nearby.isEmpty ? this.nearby : nearby,
      inFlatAmenities: flat.isEmpty ? inFlatAmenities : flat,
    );
  }
}

const _furnishingValues = {'unfurnished', 'semi_furnished', 'furnished'};

const _propertyTypeValues = {
  'apartment',
  'independent_house',
  'villa',
  'pg',
  'studio',
  'shared_room',
  'private_room',
};

String? _captionColumn(String caption) {
  final issue = listingCaptionRejection(caption);
  if (issue != null) {
    throw PhotoUploadRejection(issue);
  }
  return listingCaptionForStorage(caption);
}

String _text(Object? value) => value is String ? value : '';

String? _optionalText(Object? value) {
  final text = _text(value).trim();
  if (text.isEmpty) {
    return null;
  }
  return text;
}

String _moderation(Object? value) {
  final text = _text(value);
  if (text == 'pending' || text == 'approved' || text == 'rejected') {
    return text;
  }
  return 'pending';
}

int _occupancy(Object? value) {
  final amount = _asInt(value);
  if (amount < 1 || amount > 20) {
    return 1;
  }
  return amount;
}

List<String> _featureKeys(List<Map<String, dynamic>> features, String prefix) {
  final keys = <String>[];
  for (final row in features) {
    final raw = _text(row['feature_key']);
    final marker = '$prefix:';
    if (!raw.startsWith(marker)) {
      continue;
    }
    final key = raw.substring(marker.length);
    if (key.isEmpty || keys.contains(key)) {
      continue;
    }
    keys.add(key);
  }
  return keys;
}

String _optionalMoneyText(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is int) {
    return '$value';
  }
  if (value is num) {
    return '${value.toInt()}';
  }
  if (value is String) {
    return value.trim();
  }
  return '';
}

List<String> _tenants(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is String && preferredTenantKeys.contains(item)) item,
  ];
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

String _moneyText(Object? value, {bool blankWhenZero = false}) {
  final amount = _asInt(value);
  if (blankWhenZero && amount == 0) {
    return '';
  }
  if (value == null) {
    return '';
  }
  return '$amount';
}
