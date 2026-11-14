import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/payments/demo_payment_gateway.dart';
import 'package:homizi/features/payments/payment_gateway.dart';
import 'package:homizi/features/tools/domain/smart_split.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const rentSplitPreferenceKey = 'flutter.homizi.rent_splits';

abstract interface class RentSplitLocalStore {
  Future<List<SavedRentSplit>> read();

  Future<void> write(List<SavedRentSplit> splits);
}

class MemoryRentSplitStore implements RentSplitLocalStore {
  List<SavedRentSplit> splits = [];

  @override
  Future<List<SavedRentSplit>> read() async => [...splits];

  @override
  Future<void> write(List<SavedRentSplit> next) async {
    splits = [...next];
  }
}

/// Keeps finished splits on this device. A missing plugin keeps memory only.
class DeviceRentSplitStore implements RentSplitLocalStore {
  List<SavedRentSplit>? _cache;

  @override
  Future<List<SavedRentSplit>> read() async {
    final cached = _cache;
    if (cached != null) {
      return [...cached];
    }
    final raw = await readDeviceString(rentSplitPreferenceKey);
    final splits = raw == null || raw.isEmpty
        ? <SavedRentSplit>[]
        : decodeSplits(raw);
    _cache = splits;
    return [...splits];
  }

  @override
  Future<void> write(List<SavedRentSplit> splits) async {
    _cache = [...splits];
    await writeDeviceString(rentSplitPreferenceKey, encodeSplits(splits));
  }
}

/// Server copy in public.rent_splits. Returns false when the table is not
/// there yet (migration pending) or nobody is signed in; the device copy
/// still holds the split.
abstract interface class RentSplitRemote {
  Future<bool> save(SavedRentSplit split);
}

class SkippingRentSplitRemote implements RentSplitRemote {
  const SkippingRentSplitRemote();

  @override
  Future<bool> save(SavedRentSplit split) async => false;
}

class SupabaseRentSplitRemote implements RentSplitRemote {
  const SupabaseRentSplitRemote();

  @override
  Future<bool> save(SavedRentSplit split) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return false;
      }
      await client.from('rent_splits').insert({
        'owner_id': userId,
        'property_label': split.home.bhk,
        'locality': split.home.locality,
        'total_rent_inr': split.home.rentInr,
        'bills_inr': split.home.billsInr,
        'mode': split.mode.wire,
        'rooms': [for (final r in split.rooms) r.toJson()],
        'shares': [for (final s in split.shares) s.toJson()],
        'agreed': split.agreed,
        'finalized_at': split.finalizedAt.toUtc().toIso8601String(),
      });
      return true;
    } on Object {
      return false;
    }
  }
}

class RentSplitRepository {
  RentSplitRepository({required this.local, required this.remote});

  final RentSplitLocalStore local;
  final RentSplitRemote remote;

  Future<List<SavedRentSplit>> list() => local.read();

  /// Saves on this device first, then tries the server. Returns whether the
  /// server copy was saved.
  Future<bool> save(SavedRentSplit split) async {
    final current = await local.read();
    await local.write([split, ...current.where((s) => s.id != split.id)]);
    return remote.save(split);
  }
}

final rentSplitRepositoryProvider = Provider<RentSplitRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final demo = ref.watch(forceDemoModeProvider);
  return RentSplitRepository(
    local: DeviceRentSplitStore(),
    remote: config.connectsToSupabase && !demo
        ? const SupabaseRentSplitRemote()
        : const SkippingRentSplitRemote(),
  );
});

/// Rent split payments always use the demo gateway: no money moves.
final rentSplitPaymentsProvider = Provider<PaymentGateway>(
  (ref) => DemoPaymentGateway(),
);
