import 'dart:convert';

import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_seed.dart';
import 'package:homizi/features/search_properties/search_store.dart';

/// Writes the completed wizard locally and, when a gateway is available, to
/// `saved_searches`. The full wizard lives in `filters.wizard`. No new column.
Future<PropertySearch> persistPropertySearch({
  required PropertySearchStore store,
  required ExploreGateway? gateway,
  required PropertySearch draft,
}) async {
  await store.write(draft);
  if (gateway == null) {
    return draft;
  }
  try {
    final previous = draft.serverId;
    if (previous != null && previous.isNotEmpty) {
      await gateway.deleteSavedSearch(previous);
    }
    final summary = propertySearchSummary(draft);
    final label = summary.length > 80 ? summary.substring(0, 80) : summary;
    final saved = await gateway.saveSearch(
      label: label,
      filters: draft.toListingFilters(),
      extras: {'wizard': draft.toJson(includeServer: false)},
    );
    final stored = draft.copyWith(serverId: saved.id);
    await store.write(stored);
    return stored;
  } on Object {
    return draft;
  }
}

/// Local search, then a server wizard row, then onboarding preferences.
Future<PropertySearch?> loadEntrySearch({
  required PropertySearchStore store,
  required ExploreGateway? gateway,
  required Personalization personal,
  required TenantPreferences? tenant,
}) async {
  final local = await store.read();
  if (local != null) {
    return local;
  }
  final remote = await _fromServer(store, gateway);
  if (remote != null) {
    return remote;
  }
  final seeded = propertySearchSeededFrom(personal: personal, tenant: tenant);
  if (seeded == null) {
    return null;
  }
  return persistPropertySearch(store: store, gateway: gateway, draft: seeded);
}

Future<PropertySearch?> _fromServer(
  PropertySearchStore store,
  ExploreGateway? gateway,
) async {
  if (gateway == null) {
    return null;
  }
  try {
    final rows = await gateway.savedSearches();
    for (final row in rows) {
      final wizard = row.rawFilters['wizard'];
      if (wizard is! Map) {
        continue;
      }
      final parsed = PropertySearch.tryParse(jsonEncode(wizard));
      if (parsed == null) {
        continue;
      }
      final restored = parsed.copyWith(serverId: row.id);
      await store.write(restored);
      return restored;
    }
  } on Object {
    return null;
  }
  return null;
}
