import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/core/storage/device_string_store.dart';

const moreRequestsPreferenceKey = 'flutter.homizi.more_requests';

class MoreRequest {
  const MoreRequest({
    required this.id,
    required this.kind,
    required this.city,
    required this.locality,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String city;
  final String locality;
  final String note;
  final DateTime createdAt;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'kind': kind,
      'city': city,
      'locality': locality,
      'note': note,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  static MoreRequest? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final id = raw['id'];
    final kind = raw['kind'];
    final city = raw['city'];
    final locality = raw['locality'];
    final created = raw['createdAt'];
    if (id is! String || kind is! String || city is! String) {
      return null;
    }
    final at = created is String ? DateTime.tryParse(created) : null;
    if (at == null) {
      return null;
    }
    return MoreRequest(
      id: id,
      kind: kind,
      city: city,
      locality: locality is String ? locality : '',
      note: raw['note'] is String ? raw['note'] as String : '',
      createdAt: at,
    );
  }
}

class MoreRequestController extends Notifier<List<MoreRequest>> {
  int _generation = 0;

  @override
  List<MoreRequest> build() {
    final generation = ++_generation;
    Future<void>(() async {
      final raw = await readDeviceString(moreRequestsPreferenceKey);
      if (generation != _generation || !ref.mounted || raw == null) {
        return;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          return;
        }
        state = [
          for (final item in decoded)
            if (MoreRequest.tryParse(item) case final MoreRequest row) row,
        ];
      } on FormatException {
        return;
      }
    });
    return const [];
  }

  Future<MoreRequest> add({
    required String kind,
    required String city,
    required String locality,
    required String note,
  }) async {
    final row = MoreRequest(
      id: newLocalId(),
      kind: kind,
      city: city.trim(),
      locality: locality.trim(),
      note: note.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    state = [row, ...state];
    await writeDeviceString(
      moreRequestsPreferenceKey,
      jsonEncode([for (final item in state) item.toJson()]),
    );
    return row;
  }
}

final moreRequestProvider =
    NotifierProvider<MoreRequestController, List<MoreRequest>>(
      MoreRequestController.new,
    );

String moreRequestLabel(String kind) {
  return switch (kind) {
    'appliance' => 'Appliance service',
    'pest' => 'Pest control',
    'residential' => 'Residential plan',
    'commercial' => 'Commercial plan',
    _ => kind,
  };
}
