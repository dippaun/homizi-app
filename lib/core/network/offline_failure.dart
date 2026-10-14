import 'dart:async';
import 'dart:io';

/// Shown when a request never reaches the server. Demo mode does not use this.
const offlineMessage =
    'This device is offline. Homes already on this phone stay here. Nothing was sent.';

const _markers = [
  'SocketException',
  'ClientException',
  'HandshakeException',
  'Failed host lookup',
  'Network is unreachable',
  'Connection refused',
  'Connection reset',
  'Software caused connection abort',
];

/// Returns [offlineMessage] for a dropped connection, otherwise null.
String? offlineFailureMessage(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is TlsException) {
    return offlineMessage;
  }
  final text = error.toString();
  for (final marker in _markers) {
    if (text.contains(marker)) {
      return offlineMessage;
    }
  }
  return null;
}

bool keepHomesWhileOffline({required String? error, required bool hasHomes}) {
  return error == offlineMessage && hasHomes;
}
