import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/network/offline_failure.dart';

void main() {
  test('a dropped connection becomes the offline message', () {
    expect(
      offlineFailureMessage(const SocketException('Failed host lookup')),
      offlineMessage,
    );
    expect(
      offlineFailureMessage(TimeoutException('timed out')),
      offlineMessage,
    );
    expect(
      offlineFailureMessage(Exception('ClientException: connection abort')),
      offlineMessage,
    );
    expect(offlineFailureMessage(Exception('row not found')), isNull);
  });

  test('cached homes stay visible only for the offline message', () {
    expect(
      keepHomesWhileOffline(error: offlineMessage, hasHomes: true),
      isTrue,
    );
    expect(
      keepHomesWhileOffline(error: offlineMessage, hasHomes: false),
      isFalse,
    );
    expect(
      keepHomesWhileOffline(
        error: 'The server refused the request.',
        hasHomes: true,
      ),
      isFalse,
    );
  });
}
