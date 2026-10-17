import 'package:homizi/features/chat/domain/chat_rules.dart';

const noticePayloadKeys = <String>{
  'match_id',
  'visit_id',
  'conversation_id',
  'property_id',
};

final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,80}$');

/// A real match id is a UUID. Digit runs inside that UUID are not a phone.
final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool noticeIdOk(String value) {
  if (_uuid.hasMatch(value)) {
    return true;
  }
  return _safeId.hasMatch(value) && !containsContactText(value);
}

class InboxNotice {
  const InboxNotice({
    required this.id,
    required this.type,
    required this.createdAt,
    this.matchId,
    this.propertyId,
    this.readAt,
  });

  final String id;
  final String type;
  final String? matchId;
  final String? propertyId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;
}

class InboxSnapshot {
  const InboxSnapshot({required this.items, this.note});

  final List<InboxNotice> items;
  final String? note;
}

abstract final class InboxCopy {
  static const demoMarked = 'Kept on this device. The server was not updated.';
  static const serverMarked = 'Marked read.';
  static const empty =
      'No notifications yet. A like, match, message, or visit will show up here.';
  static const safety =
      'A notification never includes a phone number, an email address, or a street address.';
  static const demoDismissed =
      'Removed on this device. The server was not updated.';
  static const serverDismissed = 'Dismissed.';
  static const preferencesSaved = 'Notification preferences saved.';
}

/// Only `read_at` is granted to the client. Nothing else belongs in the write.
Map<String, String> notificationReadPatch(DateTime when) {
  return {'read_at': when.toUtc().toIso8601String()};
}

/// Drops contact keys, street-address keys, and any value that is not a safe id.
Map<String, String> sanitizeNoticePayload(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  final clean = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString();
    if (!noticePayloadKeys.contains(key) || contactEchoKeys.contains(key)) {
      continue;
    }
    final value = entry.value;
    if (value is! String || !noticeIdOk(value)) {
      continue;
    }
    clean[key] = value;
  }
  return clean;
}

String noticeSentence(String type) {
  if (containsContactText(type)) {
    return 'Something changed on a match.';
  }
  return switch (type) {
    'listing_interest' => 'Someone liked a listing.',
    'deposit_reminder' => 'Deposit refund reminder.',
    'match' => 'You have a new match.',
    'message' => 'New message on a match.',
    'visit_requested' => 'Someone requested a visit.',
    'visit_accepted' => 'A visit was accepted.',
    'visit_declined' => 'A visit was declined.',
    'visit_cancelled' => 'A visit was cancelled.',
    _ => 'Something changed on a match.',
  };
}

InboxNotice? noticeFromRow(Map<String, dynamic> row) {
  if (row['dismissed_at'] != null) {
    return null;
  }
  final id = row['id'];
  final type = row['type'];
  if (id is! String || type is! String) {
    return null;
  }
  final payload = sanitizeNoticePayload(row['payload_minimal']);
  final created =
      DateTime.tryParse('${row['created_at']}') ?? DateTime.now().toUtc();
  final readRaw = row['read_at'];
  return InboxNotice(
    id: id,
    type: type,
    matchId: payload['match_id'],
    propertyId: payload['property_id'],
    createdAt: created,
    readAt: readRaw == null ? null : DateTime.tryParse('$readRaw'),
  );
}
