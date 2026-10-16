import 'dart:async';

import 'package:homizi/core/network/offline_transport.dart'
    if (dart.library.io) 'package:homizi/core/network/offline_transport_io.dart';

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
  'Failed to fetch',
  'XMLHttpRequest',
  'NetworkError',
];

/// Returns [offlineMessage] for a dropped connection, otherwise null.
///
/// Browser storage and auth calls surface as fetch failures rather than
/// [SocketException]. Those strings are matched here so web does not crash.
String? offlineFailureMessage(Object error) {
  if (isDroppedConnection(error) || error is TimeoutException) {
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
