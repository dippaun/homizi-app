import 'package:homizi/features/chat/domain/chat_rules.dart';

const reportReasonValues = <String>[
  'spam',
  'harassment',
  'scam',
  'fake_listing',
  'inappropriate',
  'other',
];

const reportTargetValues = <String>[
  'user',
  'property',
  'listing_requirement',
  'message',
];

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _safeToken = RegExp(r'^[A-Za-z0-9_-]{1,80}$');

String reportReasonLabel(String reason) {
  return switch (reason) {
    'spam' => 'Spam',
    'harassment' => 'Harassment',
    'scam' => 'Scam',
    'fake_listing' => 'Fake listing',
    'inappropriate' => 'Inappropriate',
    'other' => 'Other',
    _ => 'Other',
  };
}

/// `listing` is the screen word for a property row.
String? normalizeReportTarget(String raw) {
  final value = raw == 'listing' ? 'property' : raw;
  if (!reportTargetValues.contains(value)) {
    return null;
  }
  return value;
}

/// A UUID is an id even when it contains a long digit run.
bool safetySubjectIdOk(String value) {
  if (_uuid.hasMatch(value)) {
    return true;
  }
  return _safeToken.hasMatch(value) && !containsContactText(value);
}

bool safetySubjectIsUuid(String value) => _uuid.hasMatch(value);

/// Columns the signed-in person may insert. Status stays the database default.
Map<String, String> reportInsertRow({
  required String reporterId,
  required String targetType,
  required String targetId,
  required String reason,
  String? details,
}) {
  final normalized = normalizeReportTarget(targetType);
  final trimmed = details?.trim() ?? '';
  if (normalized == null ||
      !reportReasonValues.contains(reason) ||
      !safetySubjectIdOk(reporterId) ||
      !safetySubjectIdOk(targetId) ||
      containsContactText(trimmed)) {
    throw ArgumentError('Report fields are not acceptable.');
  }
  return {
    'reporter_id': reporterId,
    'target_type': normalized,
    'target_id': targetId,
    'reason': reason,
    if (trimmed.isNotEmpty) 'details': trimmed,
  };
}

Map<String, String> blockInsertRow({
  required String blockerId,
  required String blockedUserId,
}) {
  if (!safetySubjectIdOk(blockerId) ||
      !safetySubjectIdOk(blockedUserId) ||
      blockerId == blockedUserId) {
    throw ArgumentError('Block fields are not acceptable.');
  }
  return {'blocker_id': blockerId, 'blocked_user_id': blockedUserId};
}
