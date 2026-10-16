import 'dart:io';

/// Socket and TLS failures on VM, Android, and iOS.
bool isDroppedConnection(Object error) {
  return error is SocketException ||
      error is HandshakeException ||
      error is TlsException;
}
