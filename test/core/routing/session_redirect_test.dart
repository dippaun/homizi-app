import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/routing/session_redirect.dart';
import 'package:homizi/features/session/session_state.dart';

void main() {
  test('public legal pages skip the session guard', () {
    const paths = [
      RoutePaths.privacy,
      RoutePaths.terms,
      RoutePaths.support,
      RoutePaths.deleteAccount,
    ];
    for (final phase in SessionPhase.values) {
      for (final path in paths) {
        expect(
          sessionRedirect(phase: phase, location: path, hasConsent: false),
          isNull,
          reason: '$phase $path',
        );
      }
    }
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: '${RoutePaths.privacy}?from=play',
        hasConsent: false,
      ),
      isNull,
    );
  });

  test('boot stays on the splash route', () {
    expect(
      sessionRedirect(
        phase: SessionPhase.booting,
        location: RoutePaths.splash,
        hasConsent: false,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.booting,
        location: RoutePaths.explore,
        hasConsent: false,
      ),
      RoutePaths.splash,
    );
  });

  test('signed-out users without consent only see welcome', () {
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.login,
        hasConsent: false,
      ),
      RoutePaths.welcome,
    );
  });

  test('consent allows the login route and blocks the shell', () {
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.login,
        hasConsent: true,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.explore,
        hasConsent: true,
      ),
      RoutePaths.login,
    );
  });

  test('a chosen role leaves the auth screens', () {
    expect(
      sessionRedirect(
        phase: SessionPhase.needsRole,
        location: RoutePaths.explore,
        hasConsent: true,
      ),
      RoutePaths.role,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.ready,
        location: RoutePaths.login,
        hasConsent: true,
      ),
      RoutePaths.home,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.ready,
        location: RoutePaths.home,
        hasConsent: true,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.ready,
        location: RoutePaths.login,
        hasConsent: true,
        resume: RoutePaths.hostProfile,
      ),
      RoutePaths.hostProfile,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.ready,
        location: RoutePaths.explore,
        hasConsent: true,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.ready,
        location: '/listing/lst_koramangala',
        hasConsent: true,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.ready,
        location: '/matches/demo-match/chat',
        hasConsent: true,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.ready,
        location: RoutePaths.notifications,
        hasConsent: true,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.notifications,
        hasConsent: true,
      ),
      RoutePaths.login,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: '/matches/demo-match/chat',
        hasConsent: true,
      ),
      RoutePaths.login,
    );
  });

  test('staging web launch opens the role chooser instead of sign-in', () {
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.splash,
        hasConsent: false,
        skipLogin: true,
      ),
      RoutePaths.role,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.login,
        hasConsent: true,
        skipLogin: true,
      ),
      RoutePaths.role,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.needsConsent,
        location: RoutePaths.welcome,
        hasConsent: false,
        skipLogin: true,
      ),
      RoutePaths.role,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.login,
        hasConsent: true,
        resume: RoutePaths.hostProfile,
        skipLogin: true,
      ),
      RoutePaths.hostProfile,
    );
  });

  test('staging web keeps a route that would have redirected to login', () {
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.explore,
        hasConsent: true,
        skipLogin: true,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: '/matches/demo-match/chat',
        hasConsent: true,
        skipLogin: true,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.needsRole,
        location: RoutePaths.brokerRegister,
        hasConsent: true,
        skipLogin: true,
      ),
      isNull,
    );
    expect(
      avoidLoginRedirect(
        decided: '${RoutePaths.login}?next=${RoutePaths.brokerRegister}',
        path: RoutePaths.brokerRegister,
        query: const {},
      ),
      RoutePaths.brokerRegister,
    );
    expect(
      avoidLoginRedirect(
        decided: RoutePaths.login,
        path: RoutePaths.notifications,
        query: const {},
      ),
      isNull,
    );
    expect(
      avoidLoginRedirect(
        decided: RoutePaths.login,
        path: RoutePaths.splash,
        query: const {},
      ),
      RoutePaths.role,
    );
  });
}
