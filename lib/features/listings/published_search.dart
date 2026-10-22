import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';

/// A home published from this device. Search reads [listing].
class PublishedHome {
  const PublishedHome({
    required this.listing,
    required this.cost,
    required this.photosVerified,
  });

  final Listing listing;
  final RentingCost cost;
  final bool photosVerified;
}

class PublishedSearch extends Notifier<List<PublishedHome>> {
  @override
  List<PublishedHome> build() => const [];

  void remember(ListingDraft draft) {
    final home = publishedHomeFromDraft(draft);
    if (home == null) {
      return;
    }
    state = [
      home,
      for (final item in state)
        if (item.listing.id != home.listing.id) item,
    ];
  }

  PublishedHome? byId(String id) {
    for (final home in state) {
      if (home.listing.id == id) {
        return home;
      }
    }
    return null;
  }
}

final publishedSearchProvider =
    NotifierProvider<PublishedSearch, List<PublishedHome>>(PublishedSearch.new);

PublishedHome? publishedHomeFromDraft(ListingDraft draft) {
  final id = draft.id;
  if (id == null || id.isEmpty) {
    return null;
  }
  final photosVerified = draftPhotosVerified(draft);
  final point = approxPointFor(draft.city, draft.locality);
  final deposit = int.tryParse(draft.depositText.trim()) ?? 0;
  return PublishedHome(
    photosVerified: photosVerified,
    cost: RentingCost.fromDraft(draft),
    listing: Listing(
      id: id,
      hostUserId: 'demo-host-rohan',
      title: draft.title.trim().isEmpty ? 'Untitled home' : draft.title.trim(),
      city: draft.city.trim(),
      locality: draft.locality.trim(),
      rentInr: draft.rentInr ?? 0,
      depositInr: deposit < 0 ? 0 : deposit,
      furnishing: draft.furnishing,
      propertyType: storedPropertyType(draft),
      hostDisplayName: 'Rohan S.',
      amenities: [for (final key in draft.amenities) listingAmenityLabel(key)],
      summary: _summary(draft),
      bedrooms: _bedrooms(draft.configuration),
      maintenanceInr: draft.maintenanceInr ?? 0,
      brokerageInr: draft.brokerageInr ?? 0,
      occupancyMax: draft.occupancy,
      availableFromIso: _possession(draft.possessionDate),
      restrictions: _rules(draft),
      suitability: [
        for (final key in draft.suitableFor) _suitableLabel(key),
        if (draft.preferredOccupation.isNotEmpty)
          _occupation(draft.preferredOccupation),
      ],
      photoAssets: [
        for (final photo in orderedPhotoSlots(draft.photos))
          if (photo.moderationStatus != 'rejected') assetForPhoto(photo),
      ],
      hostAvatarUrl: 'assets/avatars/avatar_01.webp',
      hostVerified: true,
      hostOccupation: _occupation(draft.preferredOccupation),
      hostKind: draft.listingIntent == 'shared_space' ? 'Flatmate' : 'Owner',
      areaSqft: draft.areaSqft,
      parking: storedParking(draft),
      petsAllowed: draft.petsChoice ?? draft.petsAllowed,
      nonVegAllowed: draft.nonVegChoice ?? draft.nonVegAllowed,
      gatedSociety: draft.gatedSociety,
      floorNo: draft.floorNo,
      totalFloors: draft.totalFloors,
      publishedAtIso: DateTime.now().toUtc().toIso8601String(),
      approxLatitude: point.$1,
      approxLongitude: point.$2,
      listingVerified: photosVerified,
    ),
  );
}

DiscoveryState withPublishedHomes(
  DiscoveryState state,
  List<PublishedHome> homes,
) {
  if (homes.isEmpty) {
    return state;
  }
  final ids = <String>{for (final home in homes) home.listing.id};
  return state.copyWith(
    listings: [
      for (final home in homes) home.listing,
      for (final listing in state.listings)
        if (!ids.contains(listing.id)) listing,
    ],
  );
}

List<Listing> mergePublishedListings(List<Listing> extra, List<Listing> rows) {
  if (extra.isEmpty) {
    return rows;
  }
  final ids = <String>{for (final listing in extra) listing.id};
  return [
    ...extra,
    for (final listing in rows)
      if (!ids.contains(listing.id)) listing,
  ];
}

String _summary(ListingDraft draft) {
  final highlights = draft.highlights.trim();
  if (highlights.isNotEmpty) {
    return highlights;
  }
  final place = [
    if (draft.locality.trim().isNotEmpty) draft.locality.trim(),
    if (draft.city.trim().isNotEmpty) draft.city.trim(),
  ].join(', ');
  final building = draft.buildingName.trim();
  final where = building.isEmpty ? place : '$building, $place';
  return 'Listed on Homizi. $where. Rent, rules, and nearby places are declared by the host.';
}

int _bedrooms(String configuration) => switch (configuration) {
  '1rk' || '1bhk' => 1,
  '2bhk' => 2,
  '3bhk' => 3,
  '4bhk' => 4,
  '4plus' => 5,
  _ => 1,
};

String? _possession(String raw) {
  final text = raw.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return text;
  }
  return null;
}

String _suitableLabel(String key) => switch (key) {
  'bachelors' => 'Bachelors',
  'couple' => 'Couple',
  'married' => 'Married',
  _ => key,
};

String _occupation(String key) => switch (key) {
  'working_professional' => 'Working professional',
  'student' => 'Student',
  'actor' => 'Actor / actress',
  'others' => 'Others',
  _ => '',
};

List<String> _rules(ListingDraft draft) {
  final rules = <String>[];
  void add(bool? allowed, String whenNo) {
    if (allowed == false) {
      rules.add(whenNo);
    }
  }

  add(draft.petsChoice, 'No pets');
  add(draft.guestsAllowed, 'No guests');
  add(draft.nonVegChoice, 'No non-veg');
  add(draft.drinkingAllowed, 'No drinking');
  add(draft.partyingAllowed, 'No partying');
  return rules;
}
