import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/maps/domain/geo.dart';
import 'package:homizi/features/maps/map_pins.dart';
import 'package:homizi/features/maps/map_runtime.dart';
import 'package:latlong2/latlong.dart';

class ExploreMapView extends StatefulWidget {
  const ExploreMapView({
    required this.listings,
    required this.tileUrl,
    required this.userAgent,
    required this.onOpenListing,
    this.loadTiles,
    super.key,
  });

  final List<Listing> listings;
  final String tileUrl;
  final String userAgent;
  final ValueChanged<String> onOpenListing;

  /// Null follows [suppressMapTiles], which is true inside widget tests.
  final bool? loadTiles;

  @override
  State<ExploreMapView> createState() => _ExploreMapViewState();
}

class _ExploreMapViewState extends State<ExploreMapView> {
  late double _zoom;

  @override
  void initState() {
    super.initState();
    _zoom = _frame.zoom;
  }

  bool get _tiles => widget.loadTiles ?? !suppressMapTiles;

  List<MapPin> get _pins {
    final pins = <MapPin>[];
    for (final listing in widget.listings) {
      final point = publicPin(
        storedLatitude: listing.approxLatitude,
        storedLongitude: listing.approxLongitude,
        city: listing.city,
        locality: listing.locality,
        salt: listing.id,
      );
      if (point == null) {
        continue;
      }
      pins.add(
        MapPin(
          listingId: listing.id,
          rentInr: listing.rentInr,
          title: listing.title,
          point: point,
        ),
      );
    }
    return pins;
  }

  MapFrame get _frame => frameFor([for (final pin in _pins) pin.point]);

  List<PinGroup> get _groups =>
      clusterPins(_pins, cellDegrees: clusterCellForZoom(_zoom));

  void _tapGroup(PinGroup group) {
    if (!group.isCluster) {
      widget.onOpenListing(group.pins.first.listingId);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final pin in group.pins)
                ListTile(
                  title: Text(homiziText(context, pin.title)),
                  subtitle: Text(formatInr(pin.rentInr)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onOpenListing(pin.listingId);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pins = _pins;
    if (pins.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            homiziText(
              context,
              'No homes in this view have a locality point yet.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final groups = _groups;
    return Stack(
      children: [
        Positioned.fill(
          child: _tiles
              ? _OsmMap(
                  frame: _frame,
                  groups: groups,
                  tileUrl: widget.tileUrl,
                  userAgent: widget.userAgent,
                  onZoom: (zoom) {
                    if ((zoom - _zoom).abs() < 0.25) {
                      return;
                    }
                    setState(() => _zoom = zoom);
                  },
                  onTapGroup: _tapGroup,
                )
              : _FallbackMap(groups: groups, onTapGroup: _tapGroup),
        ),
        const MapAttribution(),
      ],
    );
  }
}

Map<String, String> osmTileHeaders(String userAgent) {
  if (kIsWeb) {
    return const {};
  }
  return {
    'User-Agent': userAgent.isEmpty ? AppConfig.defaultOsmUserAgent : userAgent,
  };
}

class _OsmMap extends StatelessWidget {
  const _OsmMap({
    required this.frame,
    required this.groups,
    required this.tileUrl,
    required this.userAgent,
    required this.onZoom,
    required this.onTapGroup,
  });

  final MapFrame frame;
  final List<PinGroup> groups;
  final String tileUrl;
  final String userAgent;
  final ValueChanged<double> onZoom;
  final ValueChanged<PinGroup> onTapGroup;

  @override
  Widget build(BuildContext context) {
    final url = validOsmTileUrl(tileUrl)
        ? tileUrl
        : AppConfig.defaultOsmTileUrl;
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(frame.center.latitude, frame.center.longitude),
        initialZoom: frame.zoom,
        minZoom: 4,
        maxZoom: 17,
        backgroundColor: HomiziColors.mist,
        onPositionChanged: (camera, _) => onZoom(camera.zoom),
      ),
      children: [
        TileLayer(
          urlTemplate: url,
          userAgentPackageName: 'in.homizi.app',
          tileProvider: NetworkTileProvider(headers: osmTileHeaders(userAgent)),
        ),
        MarkerLayer(
          markers: [
            for (final group in groups)
              Marker(
                point: LatLng(group.point.latitude, group.point.longitude),
                width: group.isCluster ? 56 : 96,
                height: 40,
                alignment: Alignment.center,
                child: PricePin(
                  rentInr: group.pins.first.rentInr,
                  count: group.isCluster ? group.pins.length : null,
                  onTap: () => onTapGroup(group),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FallbackMap extends StatelessWidget {
  const _FallbackMap({required this.groups, required this.onTapGroup});

  final List<PinGroup> groups;
  final ValueChanged<PinGroup> onTapGroup;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final points = [for (final group in groups) group.point];
        return ColoredBox(
          color: HomiziColors.mist,
          child: Stack(
            children: [
              for (final group in groups)
                Positioned(
                  left: _x(group.point, points, constraints.maxWidth) - 40,
                  top: _y(group.point, points, constraints.maxHeight) - 16,
                  child: PricePin(
                    rentInr: group.pins.first.rentInr,
                    count: group.isCluster ? group.pins.length : null,
                    onTap: () => onTapGroup(group),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _x(GeoPoint point, List<GeoPoint> points, double width) {
    final min = points
        .map((item) => item.longitude)
        .reduce((a, b) => a < b ? a : b);
    final max = points
        .map((item) => item.longitude)
        .reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < 0.0001 ? 1.0 : (max - min);
    return 48 + ((point.longitude - min) / span) * (width - 96);
  }

  double _y(GeoPoint point, List<GeoPoint> points, double height) {
    final min = points
        .map((item) => item.latitude)
        .reduce((a, b) => a < b ? a : b);
    final max = points
        .map((item) => item.latitude)
        .reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < 0.0001 ? 1.0 : (max - min);
    return 48 + (1 - (point.latitude - min) / span) * (height - 96);
  }
}
