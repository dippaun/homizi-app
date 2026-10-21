import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roommates/domain/roommate_profile_row.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Writes the roommate brief onto `roommate_profiles`.
/// `listing_requirements` is saved by the inventory gateway first.
abstract interface class RoommateProfileGateway {
  Future<void> save(
    RequirementDraft draft, {
    Map<String, dynamic> lifestyle = const {},
  });
}

class DemoRoommateProfileGateway implements RoommateProfileGateway {
  RequirementDraft? lastDraft;
  Map<String, dynamic>? lastRow;

  @override
  Future<void> save(
    RequirementDraft draft, {
    Map<String, dynamic> lifestyle = const {},
  }) async {
    lastDraft = draft;
    lastRow = {...roommateProfileRow(draft), ...lifestyle};
  }
}

class SupabaseRoommateProfileGateway implements RoommateProfileGateway {
  SupabaseRoommateProfileGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<void> save(
    RequirementDraft draft, {
    Map<String, dynamic> lifestyle = const {},
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const RoommateFailure('Sign in before saving.');
    }
    final merged = {...roommateProfileRow(draft), ...lifestyle};
    final lifestyleRow = _roommateLifestyleRow(user.id, merged);
    final row = _roommateProfileWrite(merged)..['user_id'] = user.id;
    try {
      await _client.from('roommate_profiles').upsert(row);
      if (lifestyleRow != null) {
        await _client.from('roommate_lifestyle').upsert(lifestyleRow);
      }
    } catch (error) {
      if (error is RoommateFailure) {
        rethrow;
      }
      throw RoommateFailure(describedFailure(error));
    }
  }
}

/// Lifestyle columns live on `roommate_lifestyle`, not `roommate_profiles`.
Map<String, dynamic> _roommateProfileWrite(Map<String, dynamic> merged) {
  return {
    for (final entry in merged.entries)
      if (!entry.key.startsWith('lifestyle_')) entry.key: entry.value,
  };
}

const _lifestyleColumns = <String, String>{
  'lifestyle_smoking': 'smoking',
  'lifestyle_drinking': 'drinking',
  'lifestyle_food': 'food',
  'lifestyle_guests': 'guests',
  'lifestyle_cooking': 'cooking',
  'lifestyle_note': 'note',
};

Map<String, dynamic>? _roommateLifestyleRow(
  String userId,
  Map<String, dynamic> merged,
) {
  if (!_lifestyleColumns.keys.any(merged.containsKey)) {
    return null;
  }
  return {
    'user_id': userId,
    for (final entry in _lifestyleColumns.entries)
      entry.value: entry.key == 'lifestyle_note'
          ? (merged[entry.key] ?? '')
          : merged[entry.key],
  };
}
