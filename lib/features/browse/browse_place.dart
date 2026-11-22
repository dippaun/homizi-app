import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/account/live_account_sync.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/maps/domain/geo.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

const browsePlaceStoreKey = 'flutter.homizi.browse_place';

/// City, locality chips, and a radius the rest of the app filters with.
class BrowsePlace {
  const BrowsePlace({
    this.city = 'Ahmedabad',
    this.localities = const [],
    this.radiusKm = 8,
  });

  final String city;
  final List<String> localities;

  /// Used when a chip does not match the name but the place is nearby.
  final double radiusKm;

  bool get isSet => city.trim().isNotEmpty;

  BrowsePlace copyWith({
    String? city,
    List<String>? localities,
    double? radiusKm,
  }) {
    return BrowsePlace(
      city: city ?? this.city,
      localities: localities ?? this.localities,
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }

  Map<String, dynamic> toJson() => {
    'city': city,
    'localities': localities,
    'radiusKm': radiusKm,
  };

  static BrowsePlace fromJson(Map<String, dynamic> json) {
    final raw = json['localities'];
    final places = raw is List
        ? [
            for (final item in raw)
              if (item.toString().trim().isNotEmpty) item.toString().trim(),
          ]
        : const <String>[];
    final radius = json['radiusKm'];
    return BrowsePlace(
      city: json['city'] is String && (json['city'] as String).trim().isNotEmpty
          ? (json['city'] as String).trim()
          : 'Ahmedabad',
      localities: places,
      radiusKm: radius is num ? radius.toDouble().clamp(2, 40) : 8,
    );
  }
}

final browsePlaceProvider =
    NotifierProvider<BrowsePlaceController, BrowsePlace>(
      BrowsePlaceController.new,
    );

class BrowsePlaceController extends Notifier<BrowsePlace> {
  @override
  BrowsePlace build() {
    unawaited(_restore());
    return const BrowsePlace();
  }

  Future<void> _restore() async {
    final raw = await readDeviceString(browsePlaceStoreKey);
    if (!ref.mounted) {
      return;
    }
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          state = BrowsePlace.fromJson(Map<String, dynamic>.from(decoded));
          return;
        }
      } on Object {
        // Keep the header city when the stored row is unreadable.
      }
    }
    final personal = ref.read(personalizationProvider).city.trim();
    if (personal.isNotEmpty) {
      state = BrowsePlace(city: personal);
    }
  }

  Future<void> setPlace(BrowsePlace place) async {
    final city = place.city.trim().isEmpty ? state.city : place.city.trim();
    final next = place.copyWith(city: city);
    state = next;
    await writeDeviceString(browsePlaceStoreKey, jsonEncode(next.toJson()));
    final places = [next.city, ...next.localities];
    await LiveAccountSync.browseLocalities(places);
  }
}

/// Homes, posts, and demo rows in [place]. An empty city shows nothing.
List<Listing> listingsInBrowsePlace(List<Listing> listings, BrowsePlace place) {
  return [
    for (final listing in listings)
      if (listingInBrowsePlace(listing, place)) listing,
  ];
}

bool listingInBrowsePlace(Listing listing, BrowsePlace place) {
  return placeFits(
    place: place,
    city: listing.city,
    localities: [listing.locality],
    latitude: listing.approxLatitude,
    longitude: listing.approxLongitude,
  );
}

bool traitsInBrowsePlace(RoommateTraits traits, BrowsePlace place) {
  final home = traits.localities.isEmpty ? '' : traits.localities.first;
  final point = _point(traits.city, home);
  return placeFits(
    place: place,
    city: traits.city,
    localities: traits.localities,
    latitude: point?.latitude,
    longitude: point?.longitude,
  );
}

bool placeFits({
  required BrowsePlace place,
  required String city,
  required List<String> localities,
  double? latitude,
  double? longitude,
}) {
  if (!place.isSet || !samePlaceCity(city, place.city)) {
    return false;
  }
  final chips = [
    for (final name in place.localities)
      if (name.trim().isNotEmpty) name.trim(),
  ];
  if (chips.isEmpty) {
    return true;
  }
  final spots = [city, ...localities];
  for (final chip in chips) {
    final key = chip.toLowerCase();
    for (final spot in spots) {
      final have = spot.trim().toLowerCase();
      if (have.isNotEmpty && (have.contains(key) || key.contains(have))) {
        return true;
      }
    }
  }
  if (latitude == null || longitude == null) {
    return false;
  }
  final here = GeoFix(latitude: latitude, longitude: longitude);
  for (final chip in chips) {
    final pin = _point(place.city, chip);
    if (pin == null) {
      continue;
    }
    final km = distanceKmBetween(
      here,
      GeoFix(latitude: pin.latitude, longitude: pin.longitude),
    );
    if (km <= place.radiusKm) {
      return true;
    }
  }
  return false;
}

bool samePlaceCity(String a, String b) {
  final left = a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final right = b.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (left.isEmpty || right.isEmpty) {
    return false;
  }
  return left == right || left.contains(right) || right.contains(left);
}

GeoPoint? _point(String city, String locality) {
  if (locality.trim().isNotEmpty) {
    final named = localityCentroids[localityKey(city, locality)];
    if (named != null) {
      return named;
    }
  }
  final centre = cityCentreFor(city);
  if (centre == null) {
    return null;
  }
  return GeoPoint(centre.latitude, centre.longitude);
}

/// Label for a card whose city is not the viewer's. Null when it is the
/// same city, or when either city is missing.
String? differentCityNote(String itemCity, String viewerCity) {
  final item = itemCity.trim();
  final viewer = viewerCity.trim();
  if (item.isEmpty || viewer.isEmpty || samePlaceCity(item, viewer)) {
    return null;
  }
  return 'Different city · $item';
}

/// Same city first, then every other city. Each group keeps [matchScores]
/// order when scores are passed, otherwise the incoming order.
List<Listing> orderListingsByCity(
  List<Listing> listings,
  String viewerCity, {
  Map<String, int> matchScores = const {},
}) {
  final local = <Listing>[];
  final other = <Listing>[];
  for (final listing in listings) {
    if (viewerCity.trim().isEmpty || samePlaceCity(listing.city, viewerCity)) {
      local.add(listing);
    } else {
      other.add(listing);
    }
  }
  if (matchScores.isNotEmpty) {
    int byScore(Listing a, Listing b) {
      return (matchScores[b.id] ?? 0).compareTo(matchScores[a.id] ?? 0);
    }

    local.sort(byScore);
    other.sort(byScore);
  }
  return [...local, ...other];
}

/// Feed the home, explore, and swipe decks actually paint.
///
/// Live rows win when the gateway returned any. Same-city homes come first.
/// Homes from other cities stay in the list, after them.
final locatedListingsProvider = Provider<List<Listing>>((ref) {
  final discovery = ref.watch(discoveryProvider);
  final place = ref.watch(browsePlaceProvider);
  final source = discovery.listings.isEmpty
      ? DemoCatalog.listings
      : discovery.listings;
  return orderListingsByCity(source, place.city);
});
