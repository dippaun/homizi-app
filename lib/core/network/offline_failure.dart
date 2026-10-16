import 'dart:async';

import 'package:homizi/core/network/offline_transport.dart'
    if (dart.library.io) 'package:homizi/core/network/offline_transport_io.dart';

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
/// Emails and phone numbers are removed. The server sentence is kept.
String describedFailure(Object error) {
  final offline = offlineFailureMessage(error);
  if (offline != null) {
    return offline;
  }
  return publicErrorText(error.toString());
}

/// PostgREST `message` plus `code`, for example `42501`.
String postgrestCause({required String message, String? code}) {
  final trimmed = message.trim();
  final tag = code?.trim() ?? '';
  final combined = tag.isEmpty || trimmed.contains(tag)
      ? trimmed
      : '$trimmed ($tag)';
  final text = publicErrorText(combined);
  if (text == 'The request failed.' && tag.isNotEmpty) {
    return 'The request failed ($tag).';
  }
  return text;
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
