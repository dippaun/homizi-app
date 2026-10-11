import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/safety/domain/safety_rules.dart';
import 'package:homizi/features/safety/safety_gateway.dart';

class StoredSafetyReport {
  const StoredSafetyReport({
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.blockedUserId,
    this.details,
  });

  final String targetType;
  final String targetId;
  final String reason;
  final String? details;
  final String? blockedUserId;
}

/// Device-only reports used when the project URL or public key is empty.
class DemoSafetyGateway implements SafetyGateway {
  final List<StoredSafetyReport> reports = [];

  @override
  Future<SafetyResult> submit({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
    String? blockedUserId,
    bool alsoBlock = false,
  }) async {
    final trimmed = details?.trim() ?? '';
    if (containsContactText(trimmed)) {
      throw const SafetyFailure(
        'Remove the phone number or email before submitting. A report cannot carry contact details.',
      );
    }
    final normalized = normalizeReportTarget(targetType);
    if (normalized == null ||
        !reportReasonValues.contains(reason) ||
        !safetySubjectIdOk(targetId)) {
      throw const SafetyFailure('That report could not be stored.');
    }
    final safeBlock =
        alsoBlock && blockedUserId != null && safetySubjectIdOk(blockedUserId)
        ? blockedUserId
        : null;
    reports.add(
      StoredSafetyReport(
        targetType: normalized,
        targetId: targetId,
        reason: reason,
        details: trimmed.isEmpty ? null : trimmed,
        blockedUserId: safeBlock,
      ),
    );
    final blocked = safeBlock != null;
    return SafetyResult(
      storedOnServer: false,
      message: blocked
          ? 'Kept on this device, and the account is blocked here. The server was not updated. A moderator queue is not connected.'
          : 'Kept on this device. The server was not updated. A moderator queue is not connected.',
    );
  }
}
