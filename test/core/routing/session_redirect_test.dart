import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/routing/session_redirect.dart';
import 'package:homizi/core/routing/sign_in_gate.dart';
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

  test('profile create stays open with no session', () {
    for (final phase in SessionPhase.values) {
      expect(
        sessionRedirect(
          phase: phase,
          location: RoutePaths.profileCreate,
          hasConsent: false,
        ),
        isNull,
        reason: '$phase',
      );
    }
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

  test('consent allows login, and private screens stay for the gate', () {
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
        location: RoutePaths.notifications,
        hasConsent: true,
      ),
      isNull,
    );
  });

  test('visitors can browse homes before they register', () {
    for (final hasConsent in [false, true]) {
      for (final path in [
        RoutePaths.home,
        RoutePaths.explore,
        RoutePaths.filters,
        '/listing/lst_koramangala',
      ]) {
        expect(
          sessionRedirect(
            phase: SessionPhase.signedOut,
            location: path,
            hasConsent: hasConsent,
          ),
          isNull,
          reason: '$path consent $hasConsent',
        );
      }
    }
    expect(
      sessionRedirect(
        phase: SessionPhase.needsConsent,
        location: RoutePaths.explore,
        hasConsent: false,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.profile,
        hasConsent: true,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.priorities,
        hasConsent: false,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.roommate,
        hasConsent: false,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.searchStart,
        hasConsent: false,
      ),
      isNull,
    );
  });

  test('a chosen role leaves the auth screens', () {
    expect(
      sessionRedirect(
        phase: SessionPhase.needsRole,
        location: RoutePaths.explore,
        hasConsent: true,
      ),
      isNull,
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
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: '/matches/demo-match/chat',
        hasConsent: true,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.booting,
        location: RoutePaths.chats,
        hasConsent: false,
      ),
      RoutePaths.splash,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: '/chats/demo-chat-ananya',
        hasConsent: false,
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.settings,
        hasConsent: true,
      ),
      RoutePaths.login,
    );
  });

  test('staging web launch opens Home instead of sign-in', () {
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.splash,
        hasConsent: false,
        skipLogin: true,
      ),
      RoutePaths.home,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.login,
        hasConsent: true,
        skipLogin: true,
      ),
      RoutePaths.home,
    );
    expect(
      sessionRedirect(
        phase: SessionPhase.needsConsent,
        location: RoutePaths.welcome,
        hasConsent: false,
        skipLogin: true,
      ),
      RoutePaths.home,
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
      RoutePaths.home,
    );
  });

  test('staging web opens Home before sign-in', () {
    final config = AppConfig.parse(
      rawEnvironment: 'staging',
      supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
      supabaseAnonKey: 'sb_publishable_example',
      policyVersion: '2026-10-11-draft',
    );
    expect(stagingWebSkipsLogin(config, isWeb: true), isFalse);
    expect(stagingWebSkipsLogin(config, isWeb: false), isFalse);
    expect(
      sessionRedirect(
        phase: SessionPhase.signedOut,
        location: RoutePaths.splash,
        hasConsent: true,
      ),
      RoutePaths.home,
    );
  });

  test('the sign-in gate resume target stays inside the app', () {
    expect(signInResumeTarget('/chats'), RoutePaths.chats);
    expect(
      signInResumeTarget('/matches/demo-match/chat?name=Priya'),
      '/matches/demo-match/chat?name=Priya',
    );
    expect(signInResumeTarget('https://example.test/chats'), isNull);
    expect(signInResumeTarget('//example.test/chats'), isNull);
    expect(signInResumeTarget('/login'), isNull);
    expect(signInResumeTarget('../chats'), isNull);
    expect(isPrivateScreen(RoutePaths.chats), isTrue);
    expect(isPrivateScreen(RoutePaths.profileInquiries), isTrue);
    expect(isPrivateScreen(RoutePaths.home), isFalse);
    expect(isPrivateScreen(RoutePaths.searchStart), isFalse);
    expect(isPrivateScreen(RoutePaths.priorities), isFalse);
    expect(isPrivateScreen(RoutePaths.roommate), isFalse);
    expect(isPrivateScreen('/listing/lst_koramangala'), isFalse);
  });

  test(
    'a successful sign-in can stay on the login screen for confirmation',
    () {
      expect(
        sessionRedirect(
          phase: SessionPhase.needsRole,
          location: RoutePaths.login,
          hasConsent: true,
          holdLogin: true,
        ),
        isNull,
      );
      expect(
        sessionRedirect(
          phase: SessionPhase.ready,
          location: RoutePaths.login,
          hasConsent: true,
          holdLogin: true,
        ),
        isNull,
      );
      expect(
        sessionRedirect(
          phase: SessionPhase.needsRole,
          location: RoutePaths.login,
          hasConsent: true,
        ),
        RoutePaths.role,
      );
    },
  );
}
