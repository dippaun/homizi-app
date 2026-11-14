import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';

/// One home the host can score seekers against.
///
/// Contact fields are absent. A sample row is used only when this device
/// has no listing yet.
class HostProperty {
  const HostProperty({
    required this.id,
    required this.label,
    required this.city,
    required this.locality,
    required this.rentInr,
    required this.propertyType,
    required this.furnishing,
    required this.amenities,
    this.availableFrom,
    this.petsAllowed = false,
    this.nonVegAllowed = false,
    this.noSmoking = false,
    this.photoAsset = 'assets/images/real/living.webp',
    this.sample = false,
    this.justPublished = false,
  });

  final String id;
  final String label;
  final String city;
  final String locality;
  final int rentInr;
  final String propertyType;
  final String furnishing;
  final List<String> amenities;
  final DateTime? availableFrom;
  final bool petsAllowed;
  final bool nonVegAllowed;
  final bool noSmoking;
  final String photoAsset;
  final bool sample;
  final bool justPublished;
}

/// Shown when the host has not published a home on this device.
const sampleHostProperties = <HostProperty>[
  HostProperty(
    id: 'sample-ahmedabad-2bhk',
    label: '2 BHK / 3 BHK',
    city: 'Ahmedabad',
    locality: 'Bodakdev',
    rentInr: 10000,
    propertyType: 'apartment',
    furnishing: 'semi_furnished',
    amenities: ['wifi', 'ac', 'washing_machine'],
    petsAllowed: true,
    noSmoking: true,
    sample: true,
  ),
  HostProperty(
    id: 'sample-bengaluru-2bhk',
    label: '2 BHK · Koramangala',
    city: 'Bengaluru',
    locality: 'Koramangala',
    rentInr: 28000,
    propertyType: 'apartment',
    furnishing: 'semi_furnished',
    amenities: ['wifi', 'ac', 'security', 'washing_machine'],
    noSmoking: true,
    sample: true,
  ),
];

HostProperty hostPropertyFromDraft(ListingDraft draft) {
  final photos = [
    for (final photo in draft.photos)
      if ((photo.sampleAsset ?? '').isNotEmpty) photo.sampleAsset!,
  ];
  return HostProperty(
    id: draft.id ?? '',
    label: shortListingLabel(
      title: draft.title,
      locality: draft.locality,
      configuration: draft.configuration,
    ),
    city: draft.city.trim(),
    locality: draft.locality.trim(),
    rentInr: draft.rentInr ?? 0,
    propertyType: draft.propertyType,
    furnishing: draft.furnishing,
    amenities: [...draft.amenities, ...draft.inFlatAmenities],
    petsAllowed: draft.petsAllowed,
    nonVegAllowed: draft.nonVegAllowed,
    noSmoking: draft.restrictions.contains('no_smoking'),
    photoAsset: photos.isEmpty
        ? 'assets/images/real/living.webp'
        : photos.first,
  );
}

HostProperty hostPropertyFromListing(
  Listing listing, {
  bool justPublished = false,
}) {
  return HostProperty(
    id: listing.id,
    label: shortListingLabel(
      title: listing.title,
      locality: listing.locality,
      configuration: '',
      bedrooms: listing.bedrooms,
    ),
    city: listing.city.trim(),
    locality: listing.locality.trim(),
    rentInr: listing.rentInr,
    propertyType: listing.propertyType,
    furnishing: listing.furnishing,
    amenities: listing.amenities,
    availableFrom: DateTime.tryParse(listing.availableFromIso ?? ''),
    petsAllowed: listing.petsAllowed,
    nonVegAllowed: listing.nonVegAllowed,
    noSmoking: listing.restrictions.contains('no_smoking'),
    photoAsset: listing.photoAssets.isEmpty
        ? 'assets/images/real/living.webp'
        : listing.photoAssets.first,
    justPublished: justPublished,
  );
}

String shortListingLabel({
  required String title,
  required String locality,
  required String configuration,
  int bedrooms = 0,
}) {
  final source = '${configuration.toLowerCase()} ${title.toLowerCase()}';
  final bhk = _bhkLabel(source, bedrooms);
  final place = locality.trim();
  if (bhk != null && place.isNotEmpty) {
    return '$bhk · $place';
  }
  if (bhk != null) {
    return bhk;
  }
  if (title.trim().isNotEmpty) {
    return title.trim();
  }
  if (place.isNotEmpty) {
    return place;
  }
  return 'Your property';
}

String? _bhkLabel(String source, int bedrooms) {
  if (source.contains('4bhk') || source.contains('4 bhk') || bedrooms >= 4) {
    return '4 BHK';
  }
  if (source.contains('3bhk') || source.contains('3 bhk') || bedrooms == 3) {
    return '3 BHK';
  }
  if (source.contains('2bhk') || source.contains('2 bhk') || bedrooms == 2) {
    return '2 BHK';
  }
  if (source.contains('1bhk') || source.contains('1 bhk') || bedrooms == 1) {
    return '1 BHK';
  }
  if (source.contains('1rk') || source.contains('1 rk')) {
    return '1 RK';
  }
  return null;
}

bool sameSeekerCity(String left, String right) {
  final a = left.trim().toLowerCase();
  final b = right.trim().toLowerCase();
  if (a.isEmpty || b.isEmpty) {
    return false;
  }
  if (a == b) {
    return true;
  }
  return a.startsWith('delhi') && b.startsWith('delhi');
}
