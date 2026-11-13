import 'dart:convert';

import 'package:homizi/core/location/location_models.dart';

/// One saved workplace. Coordinates exist only after a maps lookup or a
/// browser fix. A typed address keeps them null.
class OfficeLocation {
  const OfficeLocation({
    required this.id,
    required this.label,
    required this.transport,
    required this.maxCommuteMinutes,
    this.placeId,
    this.latitude,
    this.longitude,
    this.primary = false,
    this.nearbyNotes = const [],
  });

  final String id;
  final String label;
  final String? placeId;
  final double? latitude;
  final double? longitude;
  final TransportMode transport;
  final int maxCommuteMinutes;
  final bool primary;
  final List<String> nearbyNotes;

  bool get hasCoordinates => latitude != null && longitude != null;

  PlaceEndpoint get endpoint => PlaceEndpoint(
    label: label,
    placeId: placeId,
    latitude: latitude,
    longitude: longitude,
  );

  OfficeLocation copyWith({
    bool? primary,
    TransportMode? transport,
    int? maxCommuteMinutes,
  }) {
    return OfficeLocation(
      id: id,
      label: label,
      placeId: placeId,
      latitude: latitude,
      longitude: longitude,
      transport: transport ?? this.transport,
      maxCommuteMinutes: maxCommuteMinutes ?? this.maxCommuteMinutes,
      primary: primary ?? this.primary,
      nearbyNotes: nearbyNotes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'label': label,
      if (placeId != null) 'place_id': placeId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'transport': transport.wire,
      'max_commute_minutes': maxCommuteMinutes,
      'primary': primary,
      if (nearbyNotes.isNotEmpty) 'nearby': nearbyNotes,
    };
  }

  Map<String, Object?> toRow(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'place_id': placeId,
      'latitude': latitude,
      'longitude': longitude,
      'transport_mode': transport.wire,
      'max_commute_minutes': maxCommuteMinutes,
      'is_primary': primary,
      'nearby_notes': nearbyNotes,
    };
  }

  static OfficeLocation? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final label = raw['label'];
    final id = raw['id'];
    if (label is! String || label.trim().length < 2) {
      return null;
    }
    if (id is! String || id.trim().isEmpty) {
      return null;
    }
    final minutes = raw['max_commute_minutes'] ?? raw['maxCommuteMinutes'];
    final minute = minutes is int ? minutes : int.tryParse('$minutes');
    final notes = raw['nearby'] ?? raw['nearby_notes'];
    return OfficeLocation(
      id: id.trim(),
      label: label.trim(),
      placeId: raw['place_id'] is String ? raw['place_id'] as String : null,
      latitude: _double(raw['latitude']),
      longitude: _double(raw['longitude']),
      transport: TransportMode.fromWire(
        raw['transport'] is String
            ? raw['transport'] as String
            : raw['transport_mode'] as String?,
      ),
      maxCommuteMinutes: minute != null && commuteMinuteChoices.contains(minute)
          ? minute
          : 30,
      primary: raw['primary'] == true || raw['is_primary'] == true,
      nearbyNotes: notes is List
          ? [
              for (final item in notes)
                if (item is String && item.trim().isNotEmpty) item.trim(),
            ]
          : const [],
    );
  }
}

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int _officeSeq = 0;

String newOfficeId() {
  _officeSeq += 1;
  final tail = (DateTime.now().microsecondsSinceEpoch + _officeSeq)
      .toRadixString(16)
      .padLeft(12, '0');
  final slice = tail.substring(tail.length - 12);
  return 'a1111111-1111-4111-8111-$slice';
}

String encodeOffices(List<OfficeLocation> offices) {
  return jsonEncode([for (final office in offices) office.toJson()]);
}

List<OfficeLocation> decodeOffices(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final item in decoded)
        if (OfficeLocation.tryParse(item) != null)
          OfficeLocation.tryParse(item)!,
    ];
  } on FormatException {
    return const [];
  }
}
