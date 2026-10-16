import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/moderation/domain/moderation_queue.dart';
import 'package:homizi/features/moderation/moderation_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff calls. The payload is parsed down to ids, a reason, and a status.
class SupabaseModerationGateway implements ModerationGateway {
  SupabaseModerationGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> isStaff() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return false;
    }
    try {
      final rows = await _client.from('staff_roles').select('user_id').limit(1);
      return rows.isNotEmpty;
    } catch (error) {
      final offline = offlineFailureMessage(error);
      if (offline != null) {
        throw ModerationFailure(offline);
      }
      return false;
    }
  }

  @override
  Future<List<ModerationReport>> listReports() async {
    final body = await _rpc('staff_list_reports', const {});
    return reportsFromPayload(body);
  }

  @override
  Future<ModerationResult> reviewReport(String reportId, String status) async {
    if (!moderationReviewStatuses.contains(status)) {
      throw const ModerationFailure('That action is not available.');
    }
    await _rpc('staff_review_report', {
      'p_report_id': reportId,
      'p_status': status,
    });
    return const ModerationResult(message: 'Report updated.');
  }

  @override
  Future<ModerationResult> hideListing(String propertyId) async {
    await _rpc('staff_hide_listing', {'p_property_id': propertyId});
    return const ModerationResult(
      message: 'The listing is hidden from the feed.',
    );
  }

  @override
  Future<ModerationResult> suspendUser(String userId) async {
    await _rpc('staff_suspend_user', {'p_user_id': userId});
    return const ModerationResult(message: 'The account is suspended.');
  }

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    if (_client.auth.currentUser == null) {
      throw const ModerationFailure('Sign in before continuing.');
    }
    try {
      final raw = await _client.rpc<dynamic>(name, params: params);
      final body = publicThreadFields(raw);
      if (body['ok'] != true) {
        throw ModerationFailure(
          moderationErrorMessage(
            body['error'] is String ? body['error'] as String : null,
          ),
        );
      }
      return body;
    } on ModerationFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw ModerationFailure(_safe(error.message));
    } catch (error) {
      throw ModerationFailure(describedFailure(error));
    }
  }
}

String _safe(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty || trimmed.length > 180 || containsContactText(trimmed)) {
    return 'The server did not save that.';
  }
  return trimmed;
}
