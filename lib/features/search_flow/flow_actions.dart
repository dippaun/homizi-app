import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where a deck card is stored when the id belongs to a real row.
/// Catalog cards leave this null and stay on the device.
enum FlowPersistTarget { listing, person, requirement }

FlowPersistTarget? persistTargetFor(String? raw) {
  return switch (raw) {
    'listing' => FlowPersistTarget.listing,
    'person' => FlowPersistTarget.person,
    'requirement' => FlowPersistTarget.requirement,
    _ => null,
  };
}

String interestActionFor(SwipeDecision decision) {
  return switch (decision) {
    SwipeDecision.like => 'like',
    SwipeDecision.skip => 'pass',
    SwipeDecision.save => 'save',
  };
}

class FlowActionRecord {
  const FlowActionRecord({
    required this.target,
    required this.id,
    required this.action,
  });

  final FlowPersistTarget target;
  final String id;
  final String action;
}

abstract interface class FlowActions {
  Future<void> record({
    required FlowPersistTarget target,
    required String id,
    required String action,
    Listing? listing,
    RoommateSeeker? person,
  });
}

class MemoryFlowActions implements FlowActions {
  final List<FlowActionRecord> records = [];

  @override
  Future<void> record({
    required FlowPersistTarget target,
    required String id,
    required String action,
    Listing? listing,
    RoommateSeeker? person,
  }) async {
    records.add(FlowActionRecord(target: target, id: id, action: action));
  }
}

class SupabaseFlowActions implements FlowActions {
  SupabaseFlowActions(this._ref);

  final Ref _ref;

  @override
  Future<void> record({
    required FlowPersistTarget target,
    required String id,
    required String action,
    Listing? listing,
    RoommateSeeker? person,
  }) async {
    switch (target) {
      case FlowPersistTarget.listing:
        final home = listing;
        if (home == null) {
          return;
        }
        final gateway = _ref.read(discoveryGatewayProvider);
        if (action == 'pass') {
          await gateway.passListing(home);
        } else if (action == 'save') {
          await gateway.saveListing(home);
        } else {
          await gateway.likeListing(home);
        }
      case FlowPersistTarget.person:
        final seeker = person;
        if (seeker == null) {
          return;
        }
        final gateway = _ref.read(roommateGatewayProvider);
        if (action == 'pass') {
          await gateway.pass(seeker);
        } else {
          await gateway.like(seeker);
        }
      case FlowPersistTarget.requirement:
        final client = Supabase.instance.client;
        await client.rpc<dynamic>(
          'create_interest',
          params: interestParams(
            targetId: id,
            action: action == 'save' ? 'like' : action,
            targetType: 'listing_requirement',
          ),
        );
    }
  }
}

final flowActionsProvider = Provider<FlowActions>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return MemoryFlowActions();
  }
  return SupabaseFlowActions(ref);
});
