import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/host/host_home_screen.dart';
import 'package:homizi/features/host/host_intent.dart';
import 'package:homizi/features/profile/host_profile_screen.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/public_profile.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';

class _FreshHost extends SessionController {
  @override
  SessionState build() {
    return const SessionState(phase: SessionPhase.signedOut);
  }

  @override
  Future<String?> acceptConsent() async {
    state = state.copyWith(policyVersion: '2026-10-11-draft');
    return null;
  }

  @override
  Future<String?> signIn({
    required String contact,
    required String code,
  }) async {
    if (code.trim() != '000000') {
      return 'That code is not valid.';
    }
    state = SessionState(
      phase: SessionPhase.needsRole,
      contact: contact,
      policyVersion: '2026-10-11-draft',
      userId: 'host-user',
    );
    return null;
  }

  @override
  Future<String?> selectPrimaryRole(String wire) async {
    state = state.copyWith(
      role: accountRoleForPrimaryWire(wire),
      homiziWire: wire,
      phase: SessionPhase.ready,
    );
    return null;
  }
}

class _ReadyHost extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'qa+host@homizi.in',
      role: AccountRole.host,
      homiziWire: 'host',
      policyVersion: '2026-10-11-draft',
      userId: 'host-user',
    );
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  SessionController Function() create, {
  DemoAccountGateway? accounts,
}) async {
  _phone(tester);
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(create),
      if (accounts != null)
        accountGatewayProvider.overrideWith((ref) => accounts),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(ownVerificationProvider.notifier)
      .replace(PublicProfile.verifiedDemo);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HomiziApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void _expectPath(ProviderContainer container, String path) {
  expect(container.read(routerProvider).state.uri.path, path);
}

void main() {
  test('only known host paths resume after sign-in', () {
    expect(hostResumePath(RoutePaths.hostProfile), RoutePaths.hostProfile);
    expect(
      hostResumePath('${RoutePaths.hostProfile}?from=login'),
      RoutePaths.hostProfile,
    );
    expect(hostResumePath('https://example.test'), isNull);
    expect(hostResumePath('/admin'), isNull);
  });

  testWidgets('create profile signs in, saves the host profile, then returns', (
    tester,
  ) async {
    final accounts = DemoAccountGateway();
    final container = await _pump(tester, _FreshHost.new, accounts: accounts);
    container.read(routerProvider).go(RoutePaths.welcome);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('create-profile')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('create-profile')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('consent-checkbox')));
    await tester.pump();
    await _tap(tester, find.byKey(const Key('create-profile')));
    expect(find.byKey(const Key('contact-field')), findsOneWidget);
    expect(
      container.read(hostIntentProvider).afterAuth,
      RoutePaths.hostProfile,
    );

    await _tap(tester, find.byKey(const Key('create-profile')));
    expect(find.byKey(const Key('create-profile-note')), findsOneWidget);
    expect(find.textContaining('host profile opens next'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'qa+host@homizi.in',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await _tap(tester, find.byKey(const Key('create-profile')));
    await _tap(tester, find.byKey(const Key('login-continue')));
    expect(find.byKey(const Key('role-card-host')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('role-card-host')));
    await _tap(tester, find.byKey(const Key('role-continue')));
    expect(find.byType(HostProfileScreen).hitTestable(), findsOneWidget);
    expect(find.textContaining('NoBroker'), findsNothing);
    expect(find.textContaining('99acres'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('host-company')),
      'Sharma Homes',
    );
    await _tap(tester, find.byKey(const Key('save-host-profile')));
    expect(find.byKey(const Key('host-profile-note')), findsOneWidget);
    expect((await accounts.loadHostProfile()).companyName, 'Sharma Homes');

    await _tap(tester, find.byKey(const Key('host-profile-back')));
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    _expectPath(container, RoutePaths.home);
  });

  testWidgets('the host home list is the owner dashboard', (tester) async {
    final container = await _pump(tester, _ReadyHost.new);
    container.read(routerProvider).go(RoutePaths.hostHome);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('owner-dashboard')), findsOneWidget);
    expect(find.byType(HostHomeScreen), findsNothing);
    expect(find.text('Your homes'), findsNothing);
    expect(find.textContaining('NoBroker'), findsNothing);
    expect(find.textContaining('99acres'), findsNothing);
    container.read(routerProvider).go(RoutePaths.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    Future<void> nav(String label, Finder marker, String path) async {
      await _tap(
        tester,
        find.descendant(
          of: find.byType(GlassyNavigationBar),
          matching: find.text(label),
        ),
      );
      expect(marker.hitTestable(), findsAtLeastNWidgets(1));
      _expectPath(container, path);
    }

    await nav(
      'Search',
      find.byType(SearchPropertiesScreen),
      RoutePaths.searchStart,
    );
    await nav(
      'Matches',
      find.byKey(const Key('seekers-screen')),
      RoutePaths.seekers,
    );
    await nav(
      'Chat',
      find.byKey(const Key('chat-inbox-screen')),
      RoutePaths.chats,
    );
    await nav('Home', find.byKey(const Key('home-screen')), RoutePaths.home);
  });
}
