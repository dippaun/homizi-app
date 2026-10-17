import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/maps/domain/geo.dart';
import 'package:homizi/features/maps/map_pins.dart';
import 'package:homizi/features/maps/map_runtime.dart';
import 'package:latlong2/latlong.dart';

/// Mini map for a listing. The circle is the public locality point.
/// An exact marker appears only after [address] says the visit gate is open.
class ApproximateAreaMap extends StatelessWidget {
  const ApproximateAreaMap({
    required this.listing,
    required this.address,
    required this.tileUrl,
    required this.userAgent,
    this.loadTiles,
    super.key,
  });

  final Listing listing;
  final PreciseAddress address;
  final String tileUrl;
  final String userAgent;
  final bool? loadTiles;

  @override
  Widget build(BuildContext context) {
    final point = publicPin(
      storedLatitude: listing.approxLatitude,
      storedLongitude: listing.approxLongitude,
      city: listing.city,
      locality: listing.locality,
      salt: listing.id,
    );
    if (point == null) {
      return const SizedBox.shrink();
    }
    final tiles = loadTiles ?? !suppressMapTiles;
    final showExact = address.showsExactPoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Approximate area'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            key: const Key('approximate-area-map'),
            height: 220,
            child: Stack(
              children: [
                Positioned.fill(
                  child: tiles
                      ? _Tiles(
                          point: point,
                          exact: showExact
                              ? GeoPoint(
                                  address.exactLatitude!,
                                  address.exactLongitude!,
                                )
                              : null,
                          tileUrl: tileUrl,
                          userAgent: userAgent,
                        )
                      : const ColoredBox(color: HomiziColors.mist),
                ),
                if (!tiles)
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HomiziColors.accent.withValues(alpha: 0.18),
                        border: Border.all(
                          color: HomiziColors.accent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                const MapAttribution(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            showExact
                ? 'The visit is agreed, so the point on the map is the saved location.'
                : 'The circle is the locality, not the building. The exact point stays hidden until a visit is agreed.',
          ),
        ),
      ],
    );
  }
}

Map<String, String> _headers(String userAgent) {
  if (kIsWeb) {
    return const {};
  }
  return {
    'User-Agent': userAgent.isEmpty ? AppConfig.defaultOsmUserAgent : userAgent,
  };
}

class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.point,
    required this.exact,
    required this.tileUrl,
    required this.userAgent,
  });

  final GeoPoint point;
  final GeoPoint? exact;
  final String tileUrl;
  final String userAgent;

  @override
  Widget build(BuildContext context) {
    final url = validOsmTileUrl(tileUrl)
        ? tileUrl
        : AppConfig.defaultOsmTileUrl;
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(point.latitude, point.longitude),
        initialZoom: 14,
        minZoom: 11,
        maxZoom: 16,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
        backgroundColor: HomiziColors.mist,
      ),
      children: [
        TileLayer(
          urlTemplate: url,
          userAgentPackageName: 'in.homizi.app',
          tileProvider: NetworkTileProvider(headers: _headers(userAgent)),
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: LatLng(point.latitude, point.longitude),
              radius: approximateAreaRadiusMeters,
              useRadiusInMeter: true,
              color: HomiziColors.accent.withValues(alpha: 0.18),
              borderColor: HomiziColors.accent,
              borderStrokeWidth: 2,
            ),
          ],
        ),
        if (exact != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(exact!.latitude, exact!.longitude),
                width: 18,
                height: 18,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomiziColors.ink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
