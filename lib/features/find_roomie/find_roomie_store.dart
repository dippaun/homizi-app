import 'dart:convert';

import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/find_roomie/find_roomie_models.dart';

const findRoomieStoreKey = 'flutter.homizi.find_roomie';

class FindRoomieSnapshot {
  const FindRoomieSnapshot({
    this.links = const [],
    this.shortlists = const [],
    this.joints = const [],
  });

  final List<FindRoomieLink> links;
  final List<FindRoomieShortlist> shortlists;
  final List<FindRoomieJoint> joints;

  Map<String, Object> toJson() {
    return {
      'links': [for (final link in links) link.toJson()],
      'shortlists': [for (final row in shortlists) row.toJson()],
      'joints': [for (final row in joints) row.toJson()],
    };
  }

  static FindRoomieSnapshot decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const FindRoomieSnapshot();
    }
    try {
      final body = jsonDecode(raw);
      if (body is! Map) {
        return const FindRoomieSnapshot();
      }
      return FindRoomieSnapshot(
        links: _rows(body['links'], FindRoomieLink.fromJson),
        shortlists: _rows(body['shortlists'], FindRoomieShortlist.fromJson),
        joints: _rows(body['joints'], FindRoomieJoint.fromJson),
      );
    } on FormatException {
      return const FindRoomieSnapshot();
    }
  }
}

List<Object?> _list(Object? raw) {
  if (raw is List) {
    return raw;
  }
  return const [];
}

List<T> _rows<T>(Object? raw, T? Function(Object? item) parse) {
  return [
    for (final item in _list(raw))
      if (parse(item) case final T value) value,
  ];
}

abstract interface class FindRoomieLocal {
  Future<FindRoomieSnapshot> read();

  Future<void> write(FindRoomieSnapshot snapshot);
}

class MemoryFindRoomieLocal implements FindRoomieLocal {
  FindRoomieSnapshot snapshot = const FindRoomieSnapshot();

  @override
  Future<FindRoomieSnapshot> read() async => snapshot;

  @override
  Future<void> write(FindRoomieSnapshot next) async {
    snapshot = next;
  }
}

class DeviceFindRoomieLocal implements FindRoomieLocal {
  FindRoomieSnapshot? _cache;

  @override
  Future<FindRoomieSnapshot> read() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final next = FindRoomieSnapshot.decode(
      await readDeviceString(findRoomieStoreKey),
    );
    _cache = next;
    return next;
  }

  @override
  Future<void> write(FindRoomieSnapshot snapshot) async {
    _cache = snapshot;
    await writeDeviceString(findRoomieStoreKey, jsonEncode(snapshot.toJson()));
  }
}
