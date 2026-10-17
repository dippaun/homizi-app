import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/session/session_lifecycle.dart';

void main() {
  const now = 1_700_000_000;

  test('a fresh session is kept and an expiring one is refreshed', () {
    expect(
      sessionRecovery(
        hasSession: true,
        expiresAtUnix: now + 3600,
        hasRefreshToken: true,
        nowUnix: now,
      ),
      SessionRecovery.keep,
    );
    expect(
      sessionRecovery(
        hasSession: true,
        expiresAtUnix: now + sessionRefreshLeadSeconds,
        hasRefreshToken: true,
        nowUnix: now,
      ),
      SessionRecovery.refresh,
    );
    expect(
      sessionRecovery(
        hasSession: true,
        expiresAtUnix: now - 1,
        hasRefreshToken: true,
        nowUnix: now,
      ),
      SessionRecovery.refresh,
    );
  });

  test('a missing session or refresh token signs out for recovery', () {
    expect(
      sessionRecovery(
        hasSession: false,
        expiresAtUnix: now + 3600,
        hasRefreshToken: true,
        nowUnix: now,
      ),
      SessionRecovery.signOut,
    );
    expect(
      sessionRecovery(
        hasSession: true,
        expiresAtUnix: now - 5,
        hasRefreshToken: false,
        nowUnix: now,
      ),
      SessionRecovery.signOut,
    );
    expect(
      sessionRecovery(
        hasSession: true,
        expiresAtUnix: null,
        hasRefreshToken: false,
        nowUnix: now,
      ),
      SessionRecovery.keep,
    );
  });
}
