const _months = <String>[
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

/// Clock time on a bubble, such as `9:40 AM`.
String formatChatClock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

/// Day chip between bubbles. [now] is injectable so tests do not depend on the clock.
String formatChatDay(DateTime value, DateTime now) {
  final local = value.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    return 'Today';
  }
  if (diff == 1) {
    return 'Yesterday';
  }
  return '${local.day} ${_months[local.month - 1]}';
}

/// Time on a conversation row: a clock for today, otherwise the day label.
String formatChatListTime(DateTime value, DateTime now) {
  final local = value.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) {
    return formatChatClock(value);
  }
  return formatChatDay(value, now);
}

/// A later message from the other person counts as a read receipt.
bool chatMessageWasRead({
  required DateTime createdAt,
  required bool mine,
  required List<DateTime> laterFromOther,
  DateTime? readAt,
}) {
  if (!mine) {
    return false;
  }
  if (readAt != null) {
    return true;
  }
  for (final other in laterFromOther) {
    if (other.isAfter(createdAt)) {
      return true;
    }
  }
  return false;
}
