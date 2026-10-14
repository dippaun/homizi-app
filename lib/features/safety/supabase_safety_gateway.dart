import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/safety/domain/safety_rules.dart';
import 'package:homizi/features/safety/safety_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inserts a report for the signed-in person, then a block when asked.
/// Status is left to the database default. The payload has no contact fields.
class SupabaseSafetyGateway implements SafetyGateway {
  SupabaseSafetyGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<SafetyResult> submit({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
    String? blockedUserId,
    bool alsoBlock = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const SafetyFailure('Sign in before sending a report.');
    }
    final trimmed = details?.trim() ?? '';
    if (containsContactText(trimmed)) {
      throw const SafetyFailure(
        'Remove the phone number or email before submitting. A report cannot carry contact details.',
      );
    }
    if (!safetySubjectIsUuid(targetId)) {
      throw const SafetyFailure(
        'That report needs a server id. Demo listings stay on the device.',
      );
    }
    late final Map<String, String> reportRow;
    try {
      reportRow = reportInsertRow(
        reporterId: user.id,
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        details: trimmed,
      );
    } on ArgumentError {
      throw const SafetyFailure('That report could not be stored.');
    }
    if (reportRow.keys.any(
      (key) => key == 'status' || contactEchoKeys.contains(key),
    )) {
      throw const SafetyFailure(
        'A report cannot change status or carry contact details.',
      );
    }
    await _guard(() => _client.from('reports').insert(reportRow));

    final canBlock =
        alsoBlock &&
        blockedUserId != null &&
        safetySubjectIsUuid(blockedUserId) &&
        blockedUserId != user.id;
    if (canBlock) {
      final blockRow = blockInsertRow(
        blockerId: user.id,
        blockedUserId: blockedUserId,
      );
      await _guard(() => _client.from('blocks').insert(blockRow));
    }
    return SafetyResult(
      storedOnServer: true,
      message: canBlock
          ? 'Report stored, and the account is blocked. A moderator queue is not connected.'
          : 'Report stored. A moderator queue is not connected.',
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on SafetyFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw SafetyFailure(_safe(error.message));
    } catch (error) {
      final offline = offlineFailureMessage(error);
      if (offline != null) {
        throw SafetyFailure(offline);
      }
      rethrow;
    }
  }
}

String _safe(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty || trimmed.length > 180 || containsContactText(trimmed)) {
    return 'The report was not stored. Contact details stay on the server.';
  }
  return trimmed;
}
