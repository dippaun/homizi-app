import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roommates/domain/roommate_profile_row.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Writes the roommate brief onto `roommate_profiles`.
/// `listing_requirements` is saved by the inventory gateway first.
abstract interface class RoommateProfileGateway {
  Future<void> save(RequirementDraft draft);
}

class DemoRoommateProfileGateway implements RoommateProfileGateway {
  RequirementDraft? lastDraft;
  Map<String, dynamic>? lastRow;

  @override
  Future<void> save(RequirementDraft draft) async {
    lastDraft = draft;
    lastRow = roommateProfileRow(draft);
  }
}

class SupabaseRoommateProfileGateway implements RoommateProfileGateway {
  SupabaseRoommateProfileGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<void> save(RequirementDraft draft) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const RoommateFailure('Sign in before saving.');
    }
    final row = roommateProfileRow(draft)..['user_id'] = user.id;
    try {
      await _client.from('roommate_profiles').upsert(row);
    } catch (error) {
      if (error is RoommateFailure) {
        rethrow;
      }
      throw RoommateFailure(describedFailure(error));
    }
  }
}
