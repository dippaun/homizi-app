import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';

final viewPreviewProvider =
    NotifierProvider.family<ViewPreviewController, ViewStatus, String>(
      ViewPreviewController.new,
    );

class ViewPreviewController extends Notifier<ViewStatus> {
  ViewPreviewController(this.scope);

  final String scope;

  @override
  ViewStatus build() {
    if (scope.isEmpty) {
      throw ArgumentError.value(scope, 'scope', 'Preview scope is required.');
    }
    return ViewStatus.ready;
  }

  void setStatus(ViewStatus status) => state = status;
}

/// Last applied filters, stored on this device. Not a saved search.
const appliedFiltersPreferenceKey = 'flutter.homizi.applied_filters';

abstract class AppliedFilterStore {
  Future<ListingFilters?> read();

  Future<void> write(ListingFilters filters);
}

/// On-device copy of the last applied filters.
///
/// Android and Apple use the shared_preferences plugin that supabase_flutter
/// already links. No new package is added. A missing plugin keeps the
/// in-memory filters for this process only.
class DeviceAppliedFilterStore implements AppliedFilterStore {
  const DeviceAppliedFilterStore();

  @override
  Future<ListingFilters?> read() async {
    final raw = await readDeviceString(appliedFiltersPreferenceKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return ListingFilters.tryParseApplied(raw);
  }

  @override
  Future<void> write(ListingFilters filters) async {
    if (filters.isDefault) {
      await removeDeviceString(appliedFiltersPreferenceKey);
      return;
    }
    await writeDeviceString(
      appliedFiltersPreferenceKey,
      filters.toAppliedJson(),
    );
  }
}

final appliedFilterStoreProvider = Provider<AppliedFilterStore>(
  (ref) => const DeviceAppliedFilterStore(),
);

final listingFilterProvider =
    NotifierProvider<ListingFilterController, ListingFilters>(
      ListingFilterController.new,
    );

class ListingFilterController extends Notifier<ListingFilters> {
  int _generation = 0;
  Future<void> _persistence = Future<void>.value();

  /// Completes when the latest on-device read or write finishes.
  Future<void> get persistence => _persistence;

  @override
  ListingFilters build() {
    final generation = ++_generation;
    final store = ref.read(appliedFilterStoreProvider);
    _persistence = _restore(store, generation);
    return const ListingFilters();
  }

  void replace(ListingFilters filters) => _commit(filters);

  void setQuery(String query) => _commit(state.copyWith(query: query));

  void reset() => _commit(const ListingFilters());

  void _commit(ListingFilters filters) {
    _generation++;
    state = filters;
    _persistence = ref.read(appliedFilterStoreProvider).write(filters);
  }

  Future<void> _restore(AppliedFilterStore store, int generation) async {
    final saved = await store.read();
    if (generation != _generation || !ref.mounted) {
      return;
    }
    if (saved == null || saved.isDefault) {
      return;
    }
    state = saved;
  }
}
