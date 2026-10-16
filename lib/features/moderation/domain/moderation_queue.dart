import 'package:homizi/features/safety/domain/safety_rules.dart';

const moderationReviewStatuses = <String>{'reviewing', 'resolved', 'dismissed'};

class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String reason;
  final String status;

  bool get canHideListing => targetType == 'property';

  bool get canSuspendUser => targetType == 'user';
}

String moderationTargetLabel(String targetType) {
  return switch (targetType) {
    'user' => 'Account',
    'property' => 'Listing',
    'listing_requirement' => 'Requirement',
    'message' => 'Message',
    _ => 'Report',
  };
}

String moderationErrorMessage(String? code) {
  switch (code) {
    case 'not_staff':
      return 'You are not a staff account.';
    case 'unauthenticated':
      return 'Sign in before continuing.';
    case 'missing':
      return 'That report or listing is not available.';
    case 'not_allowed':
      return 'That action is not available.';
    default:
      return 'The server did not save that.';
  }
}

/// Keeps id, target, reason, and status. Contact keys and free text are dropped.
List<ModerationReport> reportsFromPayload(Object? raw) {
  final body = _map(raw);
  final reports = body['reports'];
  if (reports is! List) {
    return const [];
  }
  final rows = <ModerationReport>[];
  for (final item in reports) {
    final row = _map(item);
    final id = row['id'];
    final targetType = row['target_type'];
    final targetId = row['target_id'];
    final reason = row['reason'];
    final status = row['status'];
    if (id is! String ||
        targetType is! String ||
        targetId is! String ||
        reason is! String ||
        status is! String) {
      continue;
    }
    if (!safetySubjectIsUuid(id) || !safetySubjectIsUuid(targetId)) {
      continue;
    }
    if (!reportTargetValues.contains(targetType) ||
        !reportReasonValues.contains(reason)) {
      continue;
    }
    rows.add(
      ModerationReport(
        id: id,
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        status: status,
      ),
    );
  }
  return rows;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}
