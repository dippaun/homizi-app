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
  return _OwnerFallback(remote, local);
});

class _OwnerFallback implements OwnerGateway {
  _OwnerFallback(this._remote, this._local);

  final OwnerGateway _remote;
  final OwnerGateway _local;

  @override
  Future<List<OwnerListing>> myListings() async {
    try {
      final rows = await _remote.myListings();
      if (rows.isEmpty) {
        return _local.myListings();
      }
      return rows;
    } catch (_) {
      return _local.myListings();
    }
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
