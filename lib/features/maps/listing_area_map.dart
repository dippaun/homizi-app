import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/place_label.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/map_mount.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/maps/domain/geo.dart';

/// One map for a listing.
///
/// With a Maps key on the web, Google draws the locality circle. Otherwise
/// a single fallback stands in. The street address is never drawn.
class ListingAreaMap extends ConsumerWidget {
  const ListingAreaMap({
    required this.listing,
    this.showPin = false,
    this.height = 220,
    this.showCaption = true,
    super.key,
  });

  final Listing listing;

  /// Marks the centre of the locality circle. Still not the building.
  final bool showPin;

  /// Thumbnail height. The full nearby page keeps the tall map.
  final double height;

  /// The locality sentence under the map. A thumbnail on the detail page
  /// draws that sentence once, next to the card, so it is not repeated.
  final bool showCaption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(appConfigProvider).mapsApiKey.trim();
    final point = publicPin(
      storedLatitude: listing.approxLatitude,
      storedLongitude: listing.approxLongitude,
      city: listing.city,
      locality: listing.locality,
      salt: listing.id,
    );
    final place = [
      listing.locality,
      listing.city,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    final canDraw = key.isNotEmpty && point != null && kIsWeb;
    final km = aboutKmFromCityCentre(listing.locality);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            key: const Key('listing-area-map'),
            height: height,
            width: double.infinity,
            child: canDraw
                ? HtmlElementView.fromTagName(
                    key: const Key('listing-area-google'),
                    tagName: 'div',
                    onElementCreated: (element) {
                      mountAreaMap(
                        element,
                        key,
                        point.latitude,
                        point.longitude,
                        approximateAreaRadiusMeters,
                        showPin: showPin,
                      );
                    },
                  )
                : _AreaFallback(label: place.isEmpty ? 'Locality' : place),
          ),
        ),
        if (showCaption && km != null) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'About $km km'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: HomiziColors.ink),
          ),
        ],
        if (showCaption) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'The circle is the locality, not the building. The exact point stays hidden until a visit is agreed.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: HomiziColors.muted),
          ),
        ],
      ],
    );
  }
}

class _AreaFallback extends StatelessWidget {
  const _AreaFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('listing-area-fallback'),
      color: const Color(0xFFF4F1EA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxHeight < 160;
          return Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(child: _Roads()),
              if (!tight)
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HomiziColors.logoOrange.withValues(alpha: 0.16),
                    border: Border.all(
                      color: HomiziColors.logoOrange,
                      width: 2,
                    ),
                  ),
                ),
              if (tight)
                const Icon(
                  Icons.location_on,
                  color: HomiziColors.logoOrange,
                  size: 28,
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: HomiziColors.logoOrange,
                      size: 36,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: HomiziColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: HomiziColors.shadowSoft,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
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
            ],
          );
        },
      ),
    );
  }
}

class _Roads extends StatelessWidget {
  const _Roads();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RoadPainter());
  }
}

class _RoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = HomiziColors.white
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.46),
      Offset(size.width, size.height * 0.58),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.34, 0),
      Offset(size.width * 0.46, size.height),
      road,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.14, 64, 42),
        const Radius.circular(8),
      ),
      Paint()..color = HomiziColors.successWash,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
