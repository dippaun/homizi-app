import 'package:homizi/features/listings/domain/listing_wizard.dart';

/// One commute row. [km] and [minutes] are null only when nothing was measured
/// and no estimate exists.
class NearbyCommuteRow {
  const NearbyCommuteRow({
    required this.kind,
    required this.name,
    this.km,
    this.minutes,
    this.live = false,
  });

  /// metro, train, bus, airport, hospital, supermarket, mall, movie, gym.
  final String kind;
  final String name;
  final double? km;
  final int? minutes;

  /// True when Places returned this name. Estimates stay false.
  final bool live;

  String get label => nearbyKindLabel(kind);

  String get kmLabel {
    final value = km;
    if (value == null || value < 0) {
      return '';
    }
    final text = value.toStringAsFixed(1);
    final shown = text.endsWith('.0')
        ? text.substring(0, text.length - 2)
        : text;
    return '$shown km';
  }

  String get minutesLabel {
    final value = minutes;
    if (value == null || value <= 0) {
      return '';
    }
    return '$value min';
  }
}

/// Cache key for one listing at one approximate point.
String nearbyCacheKey({
  required String id,
  double? latitude,
  double? longitude,
}) {
  final lat = latitude == null ? '' : latitude.toStringAsFixed(3);
  final lng = longitude == null ? '' : longitude.toStringAsFixed(3);
  return '$id@$lat,$lng';
}
