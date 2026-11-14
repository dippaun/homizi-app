import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/map_mount.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/maps/domain/geo.dart';
import 'package:homizi/features/maps/listing_area_map.dart';
import 'package:homizi/features/nearby/nearby_models.dart';
import 'package:homizi/features/nearby/nearby_places_service.dart';
import 'package:homizi/features/nearby/nearby_row.dart';

/// Full-screen nearby commute list. One back button.
///
/// The map is the approximate area. The pin sits on that circle, not on a
/// building. Rows come from [NearbyPlacesService], so a preview that already
/// loaded this listing does not call Google again.
class NearbyPlacesPage extends ConsumerStatefulWidget {
  const NearbyPlacesPage({
    required this.cacheKey,
    required this.city,
    required this.locality,
    this.latitude,
    this.longitude,
    this.listing,
    super.key,
  });

  final String cacheKey;
  final String city;
  final String locality;
  final double? latitude;
  final double? longitude;
  final Listing? listing;

  @override
  ConsumerState<NearbyPlacesPage> createState() => _NearbyPlacesPageState();
}

class _NearbyPlacesPageState extends ConsumerState<NearbyPlacesPage> {
  List<NearbyCommuteRow>? _rows;

  @override
  void initState() {
    super.initState();
    _rows = ref
        .read(nearbyPlacesServiceProvider)
        .peek(
          cacheKey: widget.cacheKey,
          latitude: widget.latitude,
          longitude: widget.longitude,
        );
    if (_rows == null) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final rows = await ref
        .read(nearbyPlacesServiceProvider)
        .load(
          cacheKey: widget.cacheKey,
          city: widget.city,
          locality: widget.locality,
          latitude: widget.latitude,
          longitude: widget.longitude,
        );
    if (!mounted) {
      return;
    }
    setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final place = [
      widget.locality.trim(),
      widget.city.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    return Scaffold(
      key: const Key('nearby-places-page'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        leading: const HomiziBackButton(),
        title: Text(
          homiziText(context, 'Nearby places'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (widget.listing != null)
            ListingAreaMap(listing: widget.listing!, showPin: true)
          else
            _NearbyMap(
              label: place.isEmpty ? 'Approximate area' : place,
              latitude: widget.latitude,
              longitude: widget.longitude,
            ),
          const SizedBox(height: 16),
          Text(
            homiziText(
              context,
              'Approximate distance and time from this area.',
            ),
            style: const TextStyle(color: HomiziColors.muted),
          ),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(
                  Icons.place,
                  color: HomiziColors.logoOrange,
                  size: 18,
                ),
                label: Text(homiziText(context, place)),
                backgroundColor: HomiziColors.white,
                side: const BorderSide(color: HomiziColors.line),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (rows == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  color: HomiziColors.logoOrange,
                ),
              ),
            )
          else
            for (final row in rows) NearbyCommuteTile(row: row),
        ],
      ),
    );
  }
}

class _NearbyMap extends ConsumerWidget {
  const _NearbyMap({required this.label, this.latitude, this.longitude});

  final String label;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(appConfigProvider).mapsApiKey.trim();
    final canDraw =
        key.isNotEmpty && latitude != null && longitude != null && kIsWeb;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        key: const Key('nearby-places-map'),
        height: 220,
        width: double.infinity,
        child: canDraw
            ? HtmlElementView.fromTagName(
                tagName: 'div',
                onElementCreated: (element) {
                  mountAreaMap(
                    element,
                    key,
                    latitude!,
                    longitude!,
                    approximateAreaRadiusMeters,
                    showPin: true,
                  );
                },
              )
            : _Fallback(label: label),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('nearby-map-fallback'),
      color: const Color(0xFFF4F1EA),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on,
              color: HomiziColors.logoOrange,
              size: 36,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: HomiziColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
