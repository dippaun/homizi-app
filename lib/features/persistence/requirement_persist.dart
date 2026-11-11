import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rows for `match_priority`. Rank 1 is the highest. No contact fields.
List<Map<String, dynamic>> priorityRows({
  required String userId,
  required SearchPriorities priorities,
}) {
  final rows = <Map<String, dynamic>>[];
  for (final entry in priorities.ranks.entries) {
    final rank = entry.value;
    if (rank < 1 || rank > 10) {
      continue;
    }
    rows.add({
      'user_id': userId,
      'side': 'tenant',
      'factor_key': entry.key.name,
      'rank': rank,
      'flexibility': 'flexible',
    });
  }
  return rows;
}

RequirementDraft requirementFromFlow(FlowPrefs prefs) {
  final stay = prefs.stay == 'roommate' ? 'roommate' : 'tenant';
  return RequirementDraft(
    budgetMinInr: prefs.budgetLow,
    budgetMaxInr: prefs.budgetHigh,
    city: prefs.city,
    locality: prefs.localities.isEmpty ? '' : prefs.localities.first,
    localities: List<String>.from(prefs.localities),
    furnishings: [prefs.furnishing],
    amenities: List<String>.from(prefs.amenities),
    aboutMe: prefs.note,
    seekerKind: stay,
    moveInDate: DateTime.now().toUtc().add(const Duration(days: 21)),
  );
}

bool _remote(WidgetRef ref) {
  final config = ref.read(appConfigProvider);
  return config.connectsToSupabase && !ref.read(forceDemoModeProvider);
}

/// Saves and publishes a requirement for the signed-in user.
/// Demo mode keeps the draft on the device and returns null.
Future<String?> persistRequirement(
  WidgetRef ref,
  RequirementDraft draft,
) async {
  if (!_remote(ref)) {
    return null;
  }
  final gateway = ref.read(inventoryGatewayProvider);
  try {
    final saved = await gateway.saveRequirement(draft);
    await gateway.publishRequirement(saved.draft);
  } on InventoryFailure catch (error) {
    return error.message;
  }
  return null;
}

Future<String?> persistFlowRequirement(WidgetRef ref, FlowPrefs prefs) {
  return persistRequirement(ref, requirementFromFlow(prefs));
}

/// Writes priority ranks onto `match_priority` for the signed-in user.
Future<String?> persistPriorities(
  WidgetRef ref,
  SearchPriorities priorities,
) async {
  if (!_remote(ref)) {
    return null;
  }
  try {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return 'Sign in before saving priorities.';
    }
    final rows = priorityRows(userId: user.id, priorities: priorities);
    if (rows.isEmpty) {
      return null;
    }
    await client.from('match_priority').upsert(rows);
  } on Object {
    return 'Priorities could not be saved.';
  }
  return null;
}

/// Like, skip, and save on the intelligent-match deck.
/// `match_decision.target_id` is text, so a catalog id is stored too.
Future<void> persistMatchDecision({
  required WidgetRef ref,
  required String targetId,
  required String decision,
  required bool saved,
}) async {
  if (!_remote(ref)) {
    return;
  }
  if (decision != 'like' && decision != 'skip') {
    return;
  }
  try {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return;
    }
    await client.from('match_decision').upsert({
      'user_id': user.id,
      'target_kind': 'listing',
      'target_id': targetId,
      'decision': decision,
      'saved': saved,
    });
  } on Object {
    // The deck still moves. The next successful write stores the decision.
  }
}
