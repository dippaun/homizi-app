import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:homizi/core/location/map_mount.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Map preview. Google Maps JavaScript draws the pin on the web when a key
/// and a real point exist. Every other case is a placeholder, with no route
/// and no made-up distance.
class HomiziMapView extends StatelessWidget {
  const HomiziMapView({
    required this.mapsEnabled,
    this.apiKey = '',
    this.latitude,
    this.longitude,
    this.label = 'My Office',
    super.key,
  });

  final bool mapsEnabled;
  final String apiKey;
  final double? latitude;
  final double? longitude;
  final String label;

  bool get _hasPoint => latitude != null && longitude != null;

  bool get _canDraw =>
      mapsEnabled && apiKey.trim().isNotEmpty && _hasPoint && kIsWeb;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: _canDraw
            ? HtmlElementView.fromTagName(
                key: const Key('office-map-google'),
                tagName: 'div',
                onElementCreated: (element) {
                  mountOfficeMap(element, apiKey, latitude!, longitude!, label);
                },
              )
            : _MapPlaceholder(
                label: label,
                mapsReady: mapsEnabled && apiKey.trim().isNotEmpty,
                hasPoint: _hasPoint,
              ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({
    required this.label,
    required this.mapsReady,
    required this.hasPoint,
  });

  final String label;
  final bool mapsReady;
  final bool hasPoint;

  @override
  Widget build(BuildContext context) {
    final caption = !mapsReady
        ? 'Map preview'
        : hasPoint
        ? 'Google Maps opens in the browser'
        : 'Search a place to drop the pin';
    return ColoredBox(
      key: const Key('office-map-placeholder'),
      color: const Color(0xFFE7F0E4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: HomiziColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: _MapGrid()),
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
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: HomiziColors.white,
                    borderRadius: BorderRadius.circular(8),
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
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w800,
                      color: HomiziColors.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  caption,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: HomiziColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGrid extends StatelessWidget {
  const _MapGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = const Color(0xFFF7F4EA)
      ..strokeWidth = 10;
    canvas.drawLine(
      Offset(0, size.height * 0.42),
      Offset(size.width, size.height * 0.55),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, 0),
      Offset(size.width * 0.48, size.height),
      road,
    );
    final park = Paint()..color = const Color(0xFFD5E8C8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.12, 70, 48),
        const Radius.circular(8),
      ),
      park,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
