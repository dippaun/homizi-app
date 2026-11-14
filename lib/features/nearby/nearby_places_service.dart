import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/location/location_models.dart' as geo;
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/core/location/maps_js.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/maps/domain/geo.dart';
import 'package:homizi/features/nearby/nearby_models.dart';

/// Shared nearby-places lookup. List-a-home and listing detail both call this.
///
/// Places API (New) `searchNearby` supplies the names. Travel time comes from
/// the Maps JavaScript DistanceMatrixService on the web, because a
/// referrer-restricted key rejects the legacy Distance Matrix web service.
/// Results are cached per listing and approximate point. A missing key or a
/// failed call uses [realisticNearbyPlaces].
class NearbyPlacesService {
  NearbyPlacesService({required this.location, this.mapsApiKey = ''});

  final LocationService location;
  final String mapsApiKey;
  final Map<String, List<NearbyCommuteRow>> _cache = {};

  List<NearbyCommuteRow>? peek({
    required String cacheKey,
    double? latitude,
    double? longitude,
  }) {
    return _cache[_id(cacheKey, latitude, longitude)];
  }

  Future<List<NearbyCommuteRow>> load({
    required String cacheKey,
    required String city,
    required String locality,
    double? latitude,
    double? longitude,
  }) async {
    final id = _id(cacheKey, latitude, longitude);
    final cached = _cache[id];
    if (cached != null) {
      return cached;
    }
    final rows = await _fetch(
      city: city,
      locality: locality,
      latitude: latitude,
      longitude: longitude,
      salt: cacheKey,
    );
    _cache[id] = rows;
    return rows;
  }

  String _id(String cacheKey, double? latitude, double? longitude) {
    return nearbyCacheKey(
      id: cacheKey,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<NearbyCommuteRow>> _fetch({
    required String city,
    required String locality,
    required double? latitude,
    required double? longitude,
    required String salt,
  }) async {
    final fallback = _fallback(city: city, locality: locality);
    final point = publicPin(
      storedLatitude: latitude,
      storedLongitude: longitude,
      city: city,
      locality: locality,
      salt: salt,
    );
    if (!location.mapsEnabled || point == null) {
      return fallback;
    }
    final origin = geo.GeoFix(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    geo.NearbyResult nearby;
    try {
      nearby = await location.nearbyPlaces(origin);
    } on Object {
      return fallback;
    }
    if (nearby.manualEntry || nearby.places.isEmpty) {
      return fallback;
    }
    final picks = <String, geo.NearbyPlace>{};
    for (final hit in nearby.places) {
      final kind = listingKindForPlaceType(hit.category);
      if (kind == null || hit.name.trim().isEmpty || picks.containsKey(kind)) {
        continue;
      }
      picks[kind] = hit;
    }
    if (picks.isEmpty) {
      return fallback;
    }
    final byKind = await _measure(origin, picks, fallback);
    return [
      for (final kind in nearbyKinds) byKind[kind] ?? _rowFrom(fallback, kind),
    ];
  }

  List<NearbyCommuteRow> _fallback({
    required String city,
    required String locality,
  }) {
    return [
      for (final place in realisticNearbyPlaces(city: city, locality: locality))
        NearbyCommuteRow(
          kind: place.kind,
          name: place.name,
          km: place.km,
          minutes: place.minutes,
        ),
    ];
  }

  NearbyCommuteRow _rowFrom(List<NearbyCommuteRow> rows, String kind) {
    for (final row in rows) {
      if (row.kind == kind) {
        return row;
      }
    }
    return NearbyCommuteRow(kind: kind, name: nearbyKindLabel(kind));
  }

  Future<Map<String, NearbyCommuteRow>> _measure(
    geo.GeoFix origin,
    Map<String, geo.NearbyPlace> picks,
    List<NearbyCommuteRow> fallback,
  ) async {
    final estimates = {for (final row in fallback) row.kind: row};
    final walk = <String, geo.NearbyPlace>{};
    final drive = <String, geo.NearbyPlace>{};
    for (final entry in picks.entries) {
      final hit = entry.value;
      if (hit.latitude == null || hit.longitude == null) {
        continue;
      }
      final straight = geo.distanceKmBetween(
        origin,
        geo.GeoFix(latitude: hit.latitude!, longitude: hit.longitude!),
      );
      if (straight <= 1.5) {
        walk[entry.key] = hit;
      } else {
        drive[entry.key] = hit;
      }
    }
    final measured = <String, NearbyCommuteRow>{};
    measured.addAll(
      await _legs(origin, walk, 'WALKING', estimates, live: true),
    );
    measured.addAll(
      await _legs(origin, drive, 'DRIVING', estimates, live: true),
    );
    for (final entry in picks.entries) {
      measured.putIfAbsent(entry.key, () {
        final estimate = estimates[entry.key];
        return NearbyCommuteRow(
          kind: entry.key,
          name: entry.value.name.trim().isEmpty
              ? (estimate?.name ?? nearbyKindLabel(entry.key))
              : entry.value.name.trim(),
          km: estimate?.km,
          minutes: estimate?.minutes,
          live: entry.value.name.trim().isNotEmpty,
        );
      });
    }
    return measured;
  }

  Future<Map<String, NearbyCommuteRow>> _legs(
    geo.GeoFix origin,
    Map<String, geo.NearbyPlace> picks,
    String mode,
    Map<String, NearbyCommuteRow> estimates, {
    required bool live,
  }) async {
    if (picks.isEmpty) {
      return const {};
    }
    final kinds = picks.keys.toList();
    final points = [
      for (final kind in kinds)
        geo.GeoFix(
          latitude: picks[kind]!.latitude!,
          longitude: picks[kind]!.longitude!,
        ),
    ];
    if (kIsWeb && mapsApiKey.trim().isNotEmpty) {
      final legs = await jsMeasureDistances(
        apiKey: mapsApiKey,
        latitude: origin.latitude,
        longitude: origin.longitude,
        destinations: points,
        travelMode: mode,
      );
      if (legs != null && legs.length == kinds.length) {
        return {
          for (var i = 0; i < kinds.length; i++)
            kinds[i]: _fromLeg(
              kind: kinds[i],
              name: picks[kinds[i]]!.name,
              meters: legs[i].meters,
              seconds: legs[i].seconds,
              estimate: estimates[kinds[i]],
              live: live,
            ),
        };
      }
    }
    final rows = <String, NearbyCommuteRow>{};
    for (final kind in kinds) {
      final hit = picks[kind]!;
      final estimate = estimates[kind];
      try {
        final route = await location.commute(
          origin: geo.PlaceEndpoint(
            latitude: origin.latitude,
            longitude: origin.longitude,
          ),
          destination: geo.PlaceEndpoint(
            label: hit.name,
            latitude: hit.latitude,
            longitude: hit.longitude,
          ),
          mode: mode == 'WALKING'
              ? geo.TransportMode.walk
              : geo.TransportMode.car,
        );
        if (route.available &&
            route.distanceMeters != null &&
            route.durationSeconds != null &&
            route.durationSeconds! > 0) {
          rows[kind] = NearbyCommuteRow(
            kind: kind,
            name: hit.name.trim(),
            km: route.distanceMeters! / 1000,
            minutes: (route.durationSeconds! / 60).round(),
            live: true,
          );
          continue;
        }
      } on Object {
        // Fall through to the estimate for this row.
      }
      rows[kind] = NearbyCommuteRow(
        kind: kind,
        name: hit.name.trim().isEmpty
            ? (estimate?.name ?? nearbyKindLabel(kind))
            : hit.name.trim(),
        km: estimate?.km,
        minutes: estimate?.minutes,
        live: hit.name.trim().isNotEmpty,
      );
    }
    return rows;
  }

  NearbyCommuteRow _fromLeg({
    required String kind,
    required String name,
    required int? meters,
    required int? seconds,
    required NearbyCommuteRow? estimate,
    required bool live,
  }) {
    final minutes = seconds == null ? null : (seconds / 60).round();
    if (meters == null || minutes == null || minutes <= 0) {
      return NearbyCommuteRow(
        kind: kind,
        name: name.trim().isEmpty
            ? (estimate?.name ?? nearbyKindLabel(kind))
            : name.trim(),
        km: estimate?.km,
        minutes: estimate?.minutes,
        live: name.trim().isNotEmpty,
      );
    }
    return NearbyCommuteRow(
      kind: kind,
      name: name.trim(),
      km: meters / 1000,
      minutes: minutes,
      live: live,
    );
  }
}

final nearbyPlacesServiceProvider = Provider<NearbyPlacesService>((ref) {
  final config = ref.watch(appConfigProvider);
  return NearbyPlacesService(
    location: ref.watch(locationServiceProvider),
    mapsApiKey: config.mapsApiKey,
  );
});

/// Listing-wizard rows. The editor keeps editing [NearbyPlace] values.
Future<List<NearbyPlace>> measureNearbyCommute({
  required LocationService service,
  required geo.GeoFix origin,
  required String city,
  required String locality,
  String mapsApiKey = '',
}) async {
  final rows =
      await NearbyPlacesService(location: service, mapsApiKey: mapsApiKey).load(
        cacheKey: '${origin.latitude},${origin.longitude}',
        city: city,
        locality: locality,
        latitude: origin.latitude,
        longitude: origin.longitude,
      );
  return [
    for (final row in rows)
      NearbyPlace(
        kind: row.kind,
        name: row.name,
        km: row.km,
        minutes: row.minutes,
      ),
  ];
}

/// Maps a Google place type onto a listing nearby row.
String? listingKindForPlaceType(String category) {
  final type = category.trim().toLowerCase();
  if (type.isEmpty) {
    return null;
  }
  if (type.contains('subway') || type.contains('metro')) {
    return 'metro';
  }
  if (type.contains('train') || type.contains('transit_station')) {
    return 'train';
  }
  if (type.contains('bus')) {
    return 'bus';
  }
  if (type.contains('airport')) {
    return 'airport';
  }
  if (type.contains('hospital')) {
    return 'hospital';
  }
  if (type.contains('supermarket') || type.contains('grocery')) {
    return 'supermarket';
  }
  if (type.contains('shopping_mall') || type == 'mall') {
    return 'mall';
  }
  if (type.contains('movie')) {
    return 'movie';
  }
  if (type.contains('gym')) {
    return 'gym';
  }
  return null;
}
