import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/owner/demo_owner_gateway.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/supabase_owner_gateway.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ownerGatewayProvider = Provider<OwnerGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final local = DemoOwnerGateway(ref.watch(demoListingMemoryProvider));
  if (!config.connectsToSupabase || forceDemo) {
    return local;
  }
  final remote = SupabaseOwnerGateway(Supabase.instance.client);
  if (!config.demoSkipLogin) {
    return remote;
  }
  return _OwnerFallback(remote, local, ref.watch(demoListingMemoryProvider));
});

class _OwnerFallback implements OwnerGateway {
  _OwnerFallback(this._remote, this._local, this._memory);

  final OwnerGateway _remote;
  final OwnerGateway _local;
  final DemoListingMemory _memory;

  @override
  Future<List<OwnerListing>> myListings() async {
    List<OwnerListing> remoteRows;
    try {
      remoteRows = await _remote.myListings();
    } catch (_) {
      return _local.myListings();
    }
    if (remoteRows.isEmpty) {
      return _local.myListings();
    }
    if (_memory.publishedInDemo.isEmpty) {
      return remoteRows;
    }
    final localRows = await _local.myListings();
    final localById = {for (final row in localRows) row.id: row};
    final promoted = <OwnerListing>[];
    final rest = <OwnerListing>[];
    final seen = <String>{};
    for (final row in remoteRows) {
      seen.add(row.id);
      final local = localById[row.id];
      if (_memory.publishedInDemo.contains(row.id) && local != null) {
        promoted.add(local);
      } else {
        rest.add(row);
      }
    }
    for (final id in _memory.publishedInDemo) {
      if (seen.contains(id)) {
        continue;
      }
      final local = localById[id];
      if (local != null) {
        promoted.add(local);
      }
    }
    return [...promoted, ...rest];
  }

  @override
  Future<List<OwnerLead>> leads(String propertyId) async {
    try {
      final rows = await _remote.leads(propertyId);
      if (rows.isEmpty) {
        return _local.leads(propertyId);
      }
      return rows;
    } catch (_) {
      return _local.leads(propertyId);
    }
  }

  @override
  Future<List<InterestedTenant>> interestedTenants(String propertyId) async {
    try {
      final rows = await _remote.interestedTenants(propertyId);
      if (rows.isEmpty) {
        return _local.interestedTenants(propertyId);
      }
      return rows;
    } catch (_) {
      return _local.interestedTenants(propertyId);
    }
  }

  @override
  Future<ListingStats> stats(String propertyId) async {
    try {
      return await _remote.stats(propertyId);
    } catch (_) {
      return _local.stats(propertyId);
    }
  }

  @override
  Future<String> act(String propertyId, String action) async {
    try {
      return await _remote.act(propertyId, action);
    } catch (_) {
      return _local.act(propertyId, action);
    }
  }

  @override
  Future<ListingDraft?> loadOwnedDraft(String id) async {
    try {
      return await _remote.loadOwnedDraft(id);
    } catch (_) {
      return _local.loadOwnedDraft(id);
    }
  }

  @override
  Future<void> recordView(String propertyId) async {
    try {
      await _remote.recordView(propertyId);
    } catch (_) {
      await _local.recordView(propertyId);
    }
  }

  @override
  Future<int?> replyHours(String hostUserId) async {
    try {
      return await _remote.replyHours(hostUserId);
    } catch (_) {
      return _local.replyHours(hostUserId);
    }
  }

  @override
  Future<UserBadges> badgesFor(String userId) async {
    try {
      return await _remote.badgesFor(userId);
    } catch (_) {
      return _local.badgesFor(userId);
    }
  }

  @override
  Future<UserBadges> myBadges() async {
    try {
      return await _remote.myBadges();
    } catch (_) {
      return _local.myBadges();
    }
  }

  @override
  Future<UserBadges> setDemoIdVerified({required bool enabled}) {
    return _local.setDemoIdVerified(enabled: enabled);
  }

  @override
  Future<OwnerLead> setLeadStatus(String leadId, String status) async {
    try {
      return await _remote.setLeadStatus(leadId, status);
    } catch (_) {
      return _local.setLeadStatus(leadId, status);
    }
  }
}
