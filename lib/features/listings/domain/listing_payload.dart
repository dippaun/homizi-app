import 'package:homizi/features/listings/domain/listing_draft.dart';

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
  'occupancy_max',
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
  'occupancy_max',
];

const photoSlotColumns = <String>[
  'property_id',
  'storage_path',
  'sort_order',
  'photo_type',
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
      return 'exterior';
    default:
      return 'other';
  }
}

String labelForPhotoType(String photoType) {
  switch (photoType) {
    case 'living':
      return 'Living room';
    case 'bedroom':
      return 'Bedroom';
    case 'kitchen':
      return 'Kitchen';
    case 'bathroom':
      return 'Bathroom';
    case 'exterior':
      return 'Exterior';
    default:
      return 'Other';
  }
}

/// Primary slot first so it is stored at sort_order 0. There is no is_primary column.
List<PhotoSlot> orderedPhotoSlots(List<PhotoSlot> photos) {
  final primaryIndex = photos.indexWhere((photo) => photo.isPrimary);
  if (primaryIndex <= 0) {
    return photos;
  }
  return [
    photos[primaryIndex],
    for (var index = 0; index < photos.length; index++)
      if (index != primaryIndex) photos[index],
  ];
}

String photoSlotPath({
  required String userId,
  required String propertyId,
  required int sortOrder,
}) {
  return '$userId/$propertyId/$sortOrder.slot';
}

int depositInrFor(ListingDraft draft) {
  final text = draft.depositText.trim();
  if (text.isEmpty) {
    return 0;
  }
  return int.tryParse(text) ?? 0;
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
    'address_visibility': 'locality_only',
    'property_type': draft.propertyType,
    'furnishing': draft.furnishing,
    'rent_inr': draft.rentInr ?? 0,
    'deposit_inr': depositInrFor(draft),
    'occupancy_max': 1,
  };
}

Map<String, dynamic> propertyUpdatePayload(ListingDraft draft) {
  return {
    'title': draft.title.trim(),
    'locality': draft.locality.trim(),
    'city': draft.city.trim(),
    'address_visibility': 'locality_only',
    'property_type': draft.propertyType,
    'furnishing': draft.furnishing,
    'rent_inr': draft.rentInr ?? 0,
    'deposit_inr': depositInrFor(draft),
    'occupancy_max': 1,
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
        'storage_path': photoSlotPath(
          userId: userId,
          propertyId: propertyId,
          sortOrder: index,
        ),
        'sort_order': index,
        'photo_type': photoTypeForLabel(ordered[index].label),
      },
  ];
}

ListingDraft listingDraftFromRow(
  Map<String, dynamic> row,
  List<Map<String, dynamic>> photos,
) {
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
    furnishing: _furnishingValues.contains(furnishing)
        ? furnishing
        : 'semi_furnished',
    propertyType: _propertyTypeValues.contains(propertyType)
        ? propertyType
        : 'apartment',
    photos: [
      for (final photo in ordered)
        PhotoSlot(
          label: labelForPhotoType(_text(photo['photo_type'])),
          isPrimary: _asInt(photo['sort_order']) == 0,
        ),
    ],
  );
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

String _text(Object? value) => value is String ? value : '';

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
