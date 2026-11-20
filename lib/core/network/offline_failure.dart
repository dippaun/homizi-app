import 'dart:async';
import 'dart:developer' as developer;

import 'package:homizi/core/network/offline_transport.dart'
    if (dart.library.io) 'package:homizi/core/network/offline_transport_io.dart';
import 'package:homizi/core/supabase/missing_relation.dart';

/// Shown when a request never reaches the server. Demo mode does not use this.
const offlineMessage =
    'This device is offline. Homes already on this phone stay here. Nothing was sent.';

const _transportMarkers = [
  'SocketException',
  'HandshakeException',
  'Failed host lookup',
  'Network is unreachable',
  'Connection refused',
  'Connection reset',
  'connection abort',
];

/// Returns [offlineMessage] for a dropped connection, otherwise null.
///
/// A browser `Failed to fetch`, `XMLHttpRequest`, or `ClientException` is not
/// rewritten. Those strings also wrap permission, CORS, and schema failures.
/// The caller shows [describedFailure] so the screen keeps the real cause.
String? offlineFailureMessage(Object error) {
  if (isDroppedConnection(error) || error is TimeoutException) {
    return offlineMessage;
  }
  final text = error.toString();
  for (final marker in _transportMarkers) {
    if (text.contains(marker)) {
      return offlineMessage;
    }
  }
  return null;
}

/// User-facing cause. Transport drops stay as [offlineMessage].
/// Database sentences are replaced with a short line and logged.
String describedFailure(Object error) {
  final offline = offlineFailureMessage(error);
  if (offline != null) {
    return offline;
  }
  return userFacingError(error.toString());
}

/// PostgREST `message` plus `code`, mapped to a line a person can read.
String postgrestCause({required String message, String? code}) {
  final trimmed = message.trim();
  final tag = code?.trim() ?? '';
  final combined = tag.isEmpty || trimmed.contains(tag)
      ? trimmed
      : '$trimmed ($tag)';
  return userFacingError(combined);
}

/// Hides Postgres and PostgREST text. Ordinary sentences pass through
/// with emails and phone numbers removed.
String userFacingError(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return 'The request failed.';
  }
  if (trimmed == unavailableYetMessage ||
      isMissingRelation(Exception(trimmed))) {
    _logHidden(trimmed);
    return unavailableYetMessage;
  }
  final mapped = _friendlyDatabase(trimmed);
  if (mapped != null) {
    _logHidden(trimmed);
    return mapped;
  }
  return publicErrorText(trimmed);
}

String? _friendlyDatabase(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('invalid input syntax') ||
      lower.contains('22p02') ||
      lower.contains('23503') ||
      lower.contains('foreign key')) {
    return 'That item is not available right now.';
  }
  if (lower.contains('23505') || lower.contains('duplicate key')) {
    return 'That is already saved.';
  }
  if (lower.contains('42501') ||
      lower.contains('permission denied') ||
      lower.contains('row-level security') ||
      lower.contains('row level security')) {
    return 'You do not have access to that.';
  }
  if (lower.contains('jwt') ||
      lower.contains('pgrst301') ||
      lower.contains('invalid claim')) {
    return 'Sign in and try again.';
  }
  if (lower.contains('23502') ||
      lower.contains('23514') ||
      lower.contains('violates') ||
      lower.contains('syntax error') ||
      lower.contains('operator does not exist') ||
      lower.contains('postgrest')) {
    return 'Something went wrong. Please try again.';
  }
  return null;
}

void _logHidden(String raw) {
  if (raw == unavailableYetMessage) {
    return;
  }
  developer.log(publicErrorText(raw), name: 'homizi.db');
}

String publicErrorText(String raw) {
  var text = raw.trim();
  text = text.replaceAll(
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    'email',
  );
  text = text.replaceAll(RegExp(r'\+?\d[\d\s().-]{8,}\d'), 'phone');
  if (text.isEmpty) {
    return 'The request failed.';
  }
  if (text.length > 180) {
    return text.substring(0, 177);
  }
  return text;
}

bool keepHomesWhileOffline({required String? error, required bool hasHomes}) {
  return error == offlineMessage && hasHomes;
}
