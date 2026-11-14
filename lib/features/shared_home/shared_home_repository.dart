import 'dart:convert';

import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const occupancyNeedKey = 'flutter.homizi.occupancy_need';
const joinRequestsKey = 'flutter.homizi.shared_home_requests';
const sharedHomeDetailsKey = 'flutter.homizi.shared_home_details';

/// Device key-value store. Tests use [MemorySharedHomeLocal].
abstract interface class SharedHomeLocal {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class MemorySharedHomeLocal implements SharedHomeLocal {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class DeviceSharedHomeLocal implements SharedHomeLocal {
  final _cache = <String, String?>{};

  @override
  Future<String?> read(String key) async {
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    final value = await readDeviceString(key);
    _cache[key] = value;
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    _cache[key] = value;
    await writeDeviceString(key, value);
  }
}

/// A join request as the host sees it.
class HostJoinRequest {
  const HostJoinRequest({
    required this.id,
    required this.listingId,
    required this.firstName,
    required this.mode,
    required this.people,
    required this.shareInr,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String firstName;
  final JoinMode mode;
  final int people;
  final int shareInr;
  final JoinStatus status;
  final DateTime createdAt;
}

/// Server copy in public.shared_home_details and
/// public.shared_home_join_requests. Every call returns null or false when
/// the tables are not there yet (migration pending) or nobody is signed in.
abstract interface class SharedHomeRemote {
  Future<Map<String, HomeOccupancy>> details(List<String> listingIds);

  Future<bool> saveDetails({
    required String listingId,
    required String label,
    required HomeOccupancy occupancy,
  });

  Future<bool> sendRequest({
    required JoinRequest request,
    required String firstName,
  });

  /// Request id → status for the signed-in seeker. Null when unavailable.
  Future<Map<String, JoinStatus>?> myStatuses();

  Future<bool> setStatus(String requestId, JoinStatus status);

  /// Requests for the signed-in host's homes. Null when unavailable.
  Future<List<HostJoinRequest>?> hostRequests();
}

class SkippingSharedHomeRemote implements SharedHomeRemote {
  const SkippingSharedHomeRemote();

  @override
  Future<Map<String, HomeOccupancy>> details(List<String> listingIds) async =>
      const {};

  @override
  Future<bool> saveDetails({
    required String listingId,
    required String label,
    required HomeOccupancy occupancy,
  }) async => false;

  @override
  Future<bool> sendRequest({
    required JoinRequest request,
    required String firstName,
  }) async => false;

  @override
  Future<Map<String, JoinStatus>?> myStatuses() async => null;

  @override
  Future<bool> setStatus(String requestId, JoinStatus status) async => false;

  @override
  Future<List<HostJoinRequest>?> hostRequests() async => null;
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

class SupabaseSharedHomeRemote implements SharedHomeRemote {
  const SupabaseSharedHomeRemote();

  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId {
    final id = _client.auth.currentUser?.id;
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Future<Map<String, HomeOccupancy>> details(List<String> listingIds) async {
    final ids = [
      for (final id in listingIds)
        if (_uuid.hasMatch(id)) id,
    ];
    if (ids.isEmpty || _userId == null) {
      return const {};
    }
    try {
      final rows = await _client
          .from('shared_home_details')
          .select(
            'listing_id, total_rooms, currently_living, vacant_rooms, '
            'total_capacity, occupancy_type, housemates',
          )
          .inFilter('listing_id', ids);
      return {
        for (final row in rows)
          '${row['listing_id']}': HomeOccupancy.fromJson(
            Map<String, Object?>.from(row),
          ),
      };
    } on Object {
      return const {};
    }
  }

  @override
  Future<bool> saveDetails({
    required String listingId,
    required String label,
    required HomeOccupancy occupancy,
  }) async {
    final userId = _userId;
    if (userId == null || !_uuid.hasMatch(listingId)) {
      return false;
    }
    try {
      await _client.from('shared_home_details').upsert({
        'listing_id': listingId,
        'host_user_id': userId,
        'property_label': label,
        'total_rooms': occupancy.totalRooms,
        'currently_living': occupancy.currentlyLiving ?? 0,
        'vacant_rooms': occupancy.vacantRooms ?? 0,
        'total_capacity': occupancy.totalCapacity,
        'occupancy_type': occupancy.type.wire,
        'housemates': [for (final h in occupancy.housemates) h.toJson()],
      });
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> sendRequest({
    required JoinRequest request,
    required String firstName,
  }) async {
    final userId = _userId;
    if (userId == null || !_uuid.hasMatch(request.homeId)) {
      return false;
    }
    try {
      await _client.from('shared_home_join_requests').insert({
        'id': request.id,
        'listing_id': request.homeId,
        'requester_id': userId,
        'requester_first_name': firstName,
        'mode': request.mode.wire,
        'people': request.people,
        'share_inr': request.shareInr,
      });
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<Map<String, JoinStatus>?> myStatuses() async {
    final userId = _userId;
    if (userId == null) {
      return null;
    }
    try {
      final rows = await _client
          .from('shared_home_join_requests')
          .select('id, status')
          .eq('requester_id', userId);
      return {
        for (final row in rows)
          '${row['id']}': JoinStatus.fromWire(row['status'] as String?),
      };
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> setStatus(String requestId, JoinStatus status) async {
    if (_userId == null) {
      return false;
    }
    try {
      final rows = await _client
          .from('shared_home_join_requests')
          .update({'status': status.wire})
          .eq('id', requestId)
          .select('id');
      return rows.isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<List<HostJoinRequest>?> hostRequests() async {
    final userId = _userId;
    if (userId == null) {
      return null;
    }
    try {
      final rows = await _client
          .from('shared_home_join_requests')
          .select(
            'id, listing_id, requester_first_name, mode, people, share_inr, '
            'status, created_at',
          )
          .eq('host_user_id', userId)
          .order('created_at', ascending: false);
      return [
        for (final row in rows)
          HostJoinRequest(
            id: '${row['id']}',
            listingId: '${row['listing_id']}',
            firstName: (row['requester_first_name'] as String?) ?? 'Someone',
            mode: JoinMode.fromWire(row['mode'] as String?),
            people: (row['people'] as num?)?.toInt() ?? 1,
            shareInr: (row['share_inr'] as num?)?.toInt() ?? 0,
            status: JoinStatus.fromWire(row['status'] as String?),
            createdAt:
                DateTime.tryParse('${row['created_at']}') ?? DateTime.now(),
          ),
      ];
    } on Object {
      return null;
    }
  }
}

class SharedHomeRepository {
  SharedHomeRepository({required this.local, required this.remote});

  final SharedHomeLocal local;
  final SharedHomeRemote remote;

  Future<OccupancyNeed?> readNeed() async =>
      OccupancyNeed.decode(await local.read(occupancyNeedKey));

  Future<void> saveNeed(OccupancyNeed need) =>
      local.write(occupancyNeedKey, need.encode());

  Future<List<JoinRequest>> readRequests() async =>
      decodeJoinRequests(await local.read(joinRequestsKey));

  Future<void> writeRequests(List<JoinRequest> rows) =>
      local.write(joinRequestsKey, encodeJoinRequests(rows));

  /// Occupancy details this host saved on the device, by listing id.
  Future<Map<String, HomeOccupancy>> readLocalDetails() async {
    final raw = await local.read(sharedHomeDetailsKey);
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map) {
        return const {};
      }
      return {
        for (final entry in json.entries)
          if (entry.value is Map)
            '${entry.key}': HomeOccupancy.fromJson(
              Map<String, Object?>.from(entry.value as Map),
            ),
      };
    } on FormatException {
      return const {};
    }
  }

  /// Saves on this device first, then tries the server. Returns whether the
  /// server copy was saved.
  Future<bool> saveDetails({
    required String listingId,
    required String label,
    required HomeOccupancy occupancy,
  }) async {
    final current = {...await readLocalDetails(), listingId: occupancy};
    await local.write(
      sharedHomeDetailsKey,
      jsonEncode({
        for (final entry in current.entries) entry.key: entry.value.toJson(),
      }),
    );
    return remote.saveDetails(
      listingId: listingId,
      label: label,
      occupancy: occupancy,
    );
  }
}
