import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/office/office_location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const officePreferenceKey = 'flutter.homizi.office_locations';

abstract interface class OfficeLocalStore {
  Future<List<OfficeLocation>> read();

  Future<void> write(List<OfficeLocation> offices);
}

class MemoryOfficeStore implements OfficeLocalStore {
  MemoryOfficeStore([List<OfficeLocation> seed = const []])
    : offices = [...seed];

  List<OfficeLocation> offices;

  @override
  Future<List<OfficeLocation>> read() async => offices;

  @override
  Future<void> write(List<OfficeLocation> next) async {
    offices = [...next];
  }
}

/// Same shared_preferences channels the filter store already uses.
class DeviceOfficeStore implements OfficeLocalStore {
  const DeviceOfficeStore();

  @override
  Future<List<OfficeLocation>> read() async {
    final raw = await readDeviceString(officePreferenceKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return decodeOffices(raw);
  }

  @override
  Future<void> write(List<OfficeLocation> offices) async {
    if (offices.isEmpty) {
      await removeDeviceString(officePreferenceKey);
      return;
    }
    await writeDeviceString(officePreferenceKey, encodeOffices(offices));
  }
}

abstract interface class OfficeRemote {
  Future<List<OfficeLocation>?> load();

  Future<bool> write(List<OfficeLocation> offices);
}

class SkippingOfficeRemote implements OfficeRemote {
  const SkippingOfficeRemote();

  @override
  Future<List<OfficeLocation>?> load() async => null;

  @override
  Future<bool> write(List<OfficeLocation> offices) async => false;
}

class SupabaseOfficeRemote implements OfficeRemote {
  const SupabaseOfficeRemote();

  @override
  Future<List<OfficeLocation>?> load() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return null;
      }
      final rows = await client
          .from('office_locations')
          .select()
          .eq('user_id', userId);
      return [
        for (final row in rows)
          if (OfficeLocation.tryParse(row) != null)
            OfficeLocation.tryParse(row)!,
      ];
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> write(List<OfficeLocation> offices) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return false;
      }
      await client.from('office_locations').delete().eq('user_id', userId);
      if (offices.isNotEmpty) {
        await client.from('office_locations').insert([
          for (final office in offices) office.toRow(userId),
        ]);
      }
      return true;
    } on Object {
      return false;
    }
  }
}

class OfficeRepository {
  OfficeRepository({required this.local, required this.remote});

  final OfficeLocalStore local;
  final OfficeRemote remote;
  List<OfficeLocation> offices = const [];
  bool savedRemotely = false;

  OfficeLocation? get primary {
    for (final office in offices) {
      if (office.primary) {
        return office;
      }
    }
    return offices.isEmpty ? null : offices.first;
  }

  Future<void> load() async {
    final remoteOffices = await remote.load();
    if (remoteOffices != null) {
      offices = _withPrimary(remoteOffices);
      savedRemotely = true;
      await local.write(offices);
      return;
    }
    offices = _withPrimary(await local.read());
    savedRemotely = false;
  }

  Future<OfficeSave> save(OfficeLocation office) async {
    final next = [
      for (final existing in offices)
        if (existing.id != office.id) existing.copyWith(primary: false),
      office.copyWith(primary: true),
    ];
    return _commit(next);
  }

  Future<OfficeSave> remove(String id) async {
    final next = [
      for (final office in offices)
        if (office.id != id) office,
    ];
    return _commit(_withPrimary(next));
  }

  Future<OfficeSave> _commit(List<OfficeLocation> next) async {
    offices = next;
    await local.write(offices);
    savedRemotely = await remote.write(offices);
    return OfficeSave(offices: offices, remote: savedRemotely);
  }
}

class OfficeSave {
  const OfficeSave({required this.offices, required this.remote});

  final List<OfficeLocation> offices;
  final bool remote;
}

List<OfficeLocation> _withPrimary(List<OfficeLocation> offices) {
  if (offices.isEmpty || offices.any((office) => office.primary)) {
    return offices;
  }
  return [offices.first.copyWith(primary: true), ...offices.skip(1)];
}

final officeRepositoryProvider = Provider<OfficeRepository>((ref) {
  return OfficeRepository(
    local: const DeviceOfficeStore(),
    remote: const SupabaseOfficeRemote(),
  );
});

/// Bumped after an office is saved so match scores recompute the commute.
class OfficeRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final officeRevisionProvider = NotifierProvider<OfficeRevision, int>(
  OfficeRevision.new,
);
