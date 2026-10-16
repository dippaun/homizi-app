import 'package:homizi/features/chat/domain/thread_state.dart';

/// Shared rules for chat and visit requests.
/// The database enforces the same contact check. This copy keeps the device
/// from showing a number while the request is still on the way.
final _email = RegExp(r'[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}');
final _digitRun = RegExp(r'(^|[^0-9])[0-9]{10,}([^0-9]|$)');

const contactEchoKeys = <String>{
  'phone',
  'email',
  'address_line',
  'landmark',
  'latitude',
  'longitude',
  'aadhaar',
};

bool containsContactText(String body) {
  final lower = body.toLowerCase();
  if (_email.hasMatch(lower)) {
    return true;
  }
  final compact = lower.replaceAll(RegExp(r'[\s\-.()]'), '');
  return _digitRun.hasMatch(compact);
}

String displayMessageBody(String body) {
  if (containsContactText(body)) {
    return 'This message was hidden because it included contact details.';
  }
  return body;
}

/// A realtime or table row becomes a message only when it is still sent.
/// Contact text is replaced before the screen can paint it. A hidden row is dropped.
ChatMessage? chatMessageFromRealtime(Map<String, dynamic> row, String userId) {
  final status = row['status'];
  if (status != null && status != 'sent') {
    return null;
  }
  final id = row['id'];
  final senderId = row['sender_id'];
  final body = row['body'];
  if (id is! String || senderId is! String || body is! String) {
    return null;
  }
  if (id.isEmpty || senderId.isEmpty) {
    return null;
  }
  final created = DateTime.tryParse('${row['created_at']}');
  return ChatMessage(
    id: id,
    senderId: senderId,
    body: displayMessageBody(body),
    createdAt: created?.toUtc() ?? DateTime.utc(2026, 10, 16),
    mine: senderId == userId,
  );
}

/// One to three start times. The map has no address or contact keys.
List<Map<String, String>> visitSlotPayload(List<DateTime> slots) {
  if (slots.isEmpty || slots.length > 3) {
    throw ArgumentError('Choose one to three visit times.');
  }
  return [
    for (final slot in slots) {'starts_at': slot.toUtc().toIso8601String()},
  ];
}

List<DateTime> defaultVisitSlots(DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  return [
    start.add(const Duration(days: 1, hours: 11)),
    start.add(const Duration(days: 2, hours: 16)),
    start.add(const Duration(days: 3, hours: 11)),
  ];
}

List<DateTime> slotsFromJson(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final times = <DateTime>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final start = item['starts_at'];
    final parsed = start is String ? DateTime.tryParse(start) : null;
    if (parsed != null) {
      times.add(parsed.toUtc());
    }
  }
  return times;
}

Map<String, dynamic>? threadRpcMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

/// Drops contact and address keys before the app keeps an RPC payload.
Map<String, dynamic> publicThreadFields(Object? raw) {
  final body = threadRpcMap(raw);
  if (body == null) {
    return const {};
  }
  return {
    for (final entry in body.entries)
      if (!contactEchoKeys.contains(entry.key)) entry.key: entry.value,
  };
}

String formatVisitSlot(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]}, $hour:$minute';
}

String threadErrorMessage(String? code) {
  switch (code) {
    case 'contact':
      return 'Remove the phone number or email before sending. Chat cannot carry contact details.';
    case 'body':
      return 'Write a message of 1 to 4000 characters, without contact details.';
    case 'unauthenticated':
      return 'Sign in before continuing.';
    case 'not_participant':
      return 'Chat and visits are only available on an active match.';
    case 'blocked':
      return 'Chat is closed because one of you blocked the other.';
    case 'slots':
      return 'Choose one to three visit times. Do not include an address or a phone number.';
    case 'not_allowed':
      return 'You cannot set that visit status.';
    case 'closed':
      return 'This visit request is already decided.';
    default:
      return 'The server did not save that.';
  }
}

String safeThreadError(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty || trimmed.length > 180 || containsContactText(trimmed)) {
    return threadErrorMessage('contact');
  }
  return trimmed;
}
