import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/features/search_properties/search_draft.dart';

const propertySearchPreferenceKey = 'flutter.homizi.property_search';

abstract interface class PropertySearchStore {
  Future<PropertySearch?> read();

  Future<void> write(PropertySearch search);

  /// Removes the saved search so the next Search tap opens the wizard.
  Future<void> clear();
}

class MemorySearchStore implements PropertySearchStore {
  PropertySearch? saved;

  @override
  Future<PropertySearch?> read() async => saved;

  @override
  Future<void> write(PropertySearch search) async {
    saved = search;
  }

  @override
  Future<void> clear() async {
    saved = null;
  }
}

class DeviceSearchStore implements PropertySearchStore {
  const DeviceSearchStore();

  @override
  Future<PropertySearch?> read() async {
    final raw = await readDeviceString(propertySearchPreferenceKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return PropertySearch.tryParse(raw);
  }

  @override
  Future<void> write(PropertySearch search) async {
    await writeDeviceString(propertySearchPreferenceKey, search.encode());
  }

  @override
  Future<void> clear() async {
    await removeDeviceString(propertySearchPreferenceKey);
  }
}

final propertySearchStoreProvider = Provider<PropertySearchStore>(
  (ref) => const DeviceSearchStore(),
);

/// The search saved by Find My Best Matches. Null until one is saved.
final savedPropertySearchProvider = FutureProvider<PropertySearch?>((ref) {
  return ref.watch(propertySearchStoreProvider).read();
});

/// The search currently on screen, set before navigation so the results bar
/// does not wait on device storage.
class ShownPropertySearch extends Notifier<PropertySearch?> {
  @override
  PropertySearch? build() => null;

  void replace(PropertySearch? search) => state = search;
}

final shownPropertySearchProvider =
    NotifierProvider<ShownPropertySearch, PropertySearch?>(
      ShownPropertySearch.new,
    );
