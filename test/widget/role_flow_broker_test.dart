import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_auth.dart';
import 'package:homizi/features/broker/broker_links.dart';
import 'package:homizi/features/broker/broker_providers.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/profile/profile_hub_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _SignedOut extends SessionController {
  _SignedOut({this.consent = true});

  final bool consent;

  @override
  SessionState build() {
    return SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: consent ? '2026-10-11-draft' : null,
    );
  }
}

class _BrokerReady extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'meenal@homizi.in',
      role: AccountRole.host,
      homiziWire: 'broker',
      policyVersion: '2026-10-11-draft',
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
  SessionController Function() create,
) async {
  _phone(tester);
  final container = ProviderContainer(
    overrides: [sessionProvider.overrideWith(create)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HomiziApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

String _path(ProviderContainer container) {
  return container.read(routerProvider).state.uri.path;
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 30; i++) {
    if (ready()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('contact-field')),
    'qa+broker@homizi.in',
  );
  await tester.enterText(find.byKey(const Key('otp-field')), '000000');
  await tester.ensureVisible(find.byKey(const Key('verify-code')));
  await tester.tap(find.byKey(const Key('verify-code')));
  await tester.pump();
  await _until(
    tester,
    () => find.byKey(const Key('login-continue')).evaluate().isNotEmpty,
  );
  await tester.tap(find.byKey(const Key('login-continue')));
  await tester.pump();
  await _until(
    tester,
    () => find.byKey(const Key('broker-name')).evaluate().isNotEmpty,
  );
}

Future<void> _home(WidgetTester tester, ProviderContainer container) async {
  container.read(routerProvider).go(RoutePaths.home);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Finder _nav(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

void main() {
  test('broker return paths stay inside the broker area', () {
    final signedOut = brokerReturnRedirect(
      decided: RoutePaths.login,
      phase: SessionPhase.signedOut,
      path: RoutePaths.brokerRegister,
      query: const {},
    );
    expect(signedOut, isNotNull);
    expect(
      Uri.parse(signedOut!).queryParameters['next'],
      RoutePaths.brokerRegister,
    );

    expect(
      brokerReturnRedirect(
        decided: RoutePaths.role,
        phase: SessionPhase.needsRole,
        path: RoutePaths.brokerRegister,
        query: const {},
      ),
      isNull,
    );
    expect(
      brokerReturnRedirect(
        decided: RoutePaths.home,
        phase: SessionPhase.ready,
        path: RoutePaths.login,
        query: const {
          'next': RoutePaths.brokerRegister,
          'back': RoutePaths.home,
        },
      ),
      startsWith(RoutePaths.brokerRegister),
    );
    expect(
      brokerReturnRedirect(
        decided: RoutePaths.home,
        phase: SessionPhase.ready,
        path: RoutePaths.login,
        query: const {'next': 'https://example.com'},
      ),
      RoutePaths.home,
    );
    expect(
      brokerReturnRedirect(
        decided: RoutePaths.login,
        phase: SessionPhase.signedOut,
        path: RoutePaths.role,
        query: const {},
      ),
      isNull,
    );
    expect(
      brokerReturnRedirect(
        decided: null,
        phase: SessionPhase.ready,
        path: RoutePaths.brokerHome,
        query: const {},
      ),
      RoutePaths.home,
    );
  });

  testWidgets('create profile goes through sign-in, the profile, then home', (
    tester,
  ) async {
    final container = await _pump(tester, () => _SignedOut(consent: false));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('welcome-create-profile')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('welcome-create-profile')));
    await tester.tap(find.byKey(const Key('welcome-create-profile')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('contact-field')).evaluate().isNotEmpty,
    );
    expect(_path(container), RoutePaths.login);
    expect(
      container.read(routerProvider).state.uri.queryParameters['next'],
      RoutePaths.brokerRegister,
    );

    await _signIn(tester);
    expect(find.text('Broker registration'), findsOneWidget);
    expect(find.byKey(const Key('broker-registration-screen')), findsOneWidget);
    expect(
      tester
          .widget<Scaffold>(find.byKey(const Key('broker-registration-screen')))
          .backgroundColor,
      HomiziColors.white,
    );

    await tester.enterText(
      find.byKey(const Key('broker-name')),
      'Meenal Deshpande',
    );
    await tester.enterText(
      find.byKey(const Key('broker-agency')),
      'Deshpande Realty',
    );
    await tester.ensureVisible(find.byKey(const Key('broker-city-Bengaluru')));
    await tester.tap(find.byKey(const Key('broker-city-Bengaluru')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('broker-locality')),
      'Koramangala',
    );
    await tester.tap(find.text('Add locality'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('broker-phone')), '9876543210');
    await tester.ensureVisible(find.byKey(const Key('broker-save')));
    await tester.tap(find.byKey(const Key('broker-save')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Your broker profile is saved.'), findsOneWidget);
    final saved = await container.read(brokerGatewayProvider).load();
    expect(saved, isNotNull);
    expect(saved!.cities, contains('Bengaluru'));
    expect(saved.localities, contains('Koramangala'));
    expect(saved.fullName, 'Meenal Deshpande');

    await tester.ensureVisible(find.byKey(const Key('broker-profile-back')));
    await tester.tap(find.byKey(const Key('broker-profile-back')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('broker-home-screen')).evaluate().isNotEmpty,
    );
    expect(_path(container), RoutePaths.home);
    expect(find.byKey(const Key('broker-home-screen')), findsOneWidget);
    expect(find.textContaining('NoBroker'), findsNothing);
  });

  testWidgets('choosing Broker before sign-in opens the profile after 000000', (
    tester,
  ) async {
    final container = await _pump(tester, _SignedOut.new);
    expect(find.byKey(const Key('login-pick-role')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('login-pick-role')));
    await tester.tap(find.byKey(const Key('login-pick-role')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('role-card-broker')), findsOneWidget);
    await tester.tap(find.byKey(const Key('role-card-broker')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_path(container), RoutePaths.login);
    expect(
      container.read(routerProvider).state.uri.queryParameters['next'],
      RoutePaths.brokerRegister,
    );
    await _signIn(tester);
    expect(find.byKey(const Key('broker-name')), findsOneWidget);
    expect(container.read(sessionProvider).homiziWire, 'broker');
    await tester.ensureVisible(find.byKey(const Key('broker-profile-back')));
    await tester.tap(find.byKey(const Key('broker-profile-back')));
    await tester.pump();
    await _until(tester, () => _path(container) == RoutePaths.home);
    expect(find.byKey(const Key('broker-home-screen')), findsOneWidget);
  });

  testWidgets('every broker entry opens a real screen', (tester) async {
    final container = await _pump(tester, _BrokerReady.new);
    expect(_path(container), RoutePaths.home);
    expect(find.byKey(const Key('broker-home-screen')), findsOneWidget);
    expect(
      tester
          .widget<Scaffold>(find.byKey(const Key('broker-home-screen')))
          .backgroundColor,
      HomiziColors.white,
    );
    expect(find.textContaining('NoBroker'), findsNothing);

    for (final link in brokerLinks) {
      await tester.ensureVisible(find.byKey(Key(link.tileKey)));
      await tester.tap(find.byKey(Key(link.tileKey)));
      await tester.pump();
      await _until(tester, () => _path(container) == link.location);
      expect(_path(container), link.location);
      await _until(
        tester,
        () => find.byKey(Key(link.screenKey)).evaluate().isNotEmpty,
      );
      expect(find.byKey(Key(link.screenKey)), findsWidgets);
      await _home(tester, container);
      expect(_path(container), RoutePaths.home);
    }

    await tester.tap(find.byKey(const Key('broker-open-notifications')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_path(container), RoutePaths.notifications);
    expect(find.text('Notifications'), findsWidgets);
    await _home(tester, container);

    await tester.tap(find.byKey(const Key('broker-open-settings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_path(container), RoutePaths.settings);
    expect(find.text('Settings'), findsWidgets);
    await _home(tester, container);

    await tester.tap(find.byKey(const Key('broker-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('broker-menu-broker-tile-leads')));
    await tester.pump();
    await _until(tester, () => _path(container) == RoutePaths.brokerLeads);
    expect(find.byKey(const Key('broker-leads-screen')), findsOneWidget);
    await _home(tester, container);

    const nav = <(String, String)>[
      ('Seekers', RoutePaths.seekers),
      ('Listings', RoutePaths.listings),
      ('Matches', RoutePaths.matches),
      ('Profile', RoutePaths.profile),
      ('Home', RoutePaths.home),
    ];
    for (final (label, path) in nav) {
      await tester.tap(_nav(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_path(container), path);
      if (label == 'Matches') {
        expect(find.byType(MatchesScreen), findsOneWidget);
      }
      if (label == 'Profile') {
        expect(find.byType(ProfileHubScreen), findsOneWidget);
      }
    }
    await _home(tester, container);

    await tester.tap(find.byKey(const Key('broker-tile-briefs')));
    await tester.pump();
    await _until(
      tester,
      () => find
          .byKey(const Key('broker-brief-card-ananya'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('broker-brief-card-ananya')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('broker-brief-chat')).evaluate().isNotEmpty,
    );
    expect(_path(container), RoutePaths.brokerBrief('ananya'));
    expect(find.text('Ananya Iyer'), findsWidgets);
    await tester.tap(find.byKey(const Key('broker-brief-chat')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('chat-send')).evaluate().isNotEmpty,
    );
    expect(find.text('Ananya Iyer'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('chat-body')),
      'Saturday works for a visit.',
    );
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Saturday works for a visit.'), findsOneWidget);
    await _home(tester, container);

    await tester.tap(find.byKey(const Key('broker-tile-listings')));
    await tester.pump();
    await _until(
      tester,
      () => find
          .byKey(const Key('broker-listing-card-demo-own-koramangala'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(
      find.byKey(const Key('broker-listing-card-demo-own-koramangala')),
    );
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('broker-listing-edit')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('broker-listing-edit')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('listing-title')).evaluate().isNotEmpty,
    );
    expect(_path(container), RoutePaths.listingEditor);
    await _home(tester, container);

    await tester.tap(find.byKey(const Key('broker-tile-listings')));
    await tester.pump();
    await _until(
      tester,
      () => find
          .byKey(const Key('broker-listing-card-demo-own-koramangala'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(
      find.byKey(const Key('broker-listing-card-demo-own-koramangala')),
    );
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('broker-listing-stats')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('broker-listing-stats')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('listing-stats-screen')).evaluate().isNotEmpty,
    );
    expect(_path(container), RoutePaths.listingStats('demo-own-koramangala'));
    await _home(tester, container);

    await tester.tap(find.byKey(const Key('broker-tile-listings')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('broker-new-listing')).evaluate().isNotEmpty,
    );
    await tester.ensureVisible(find.byKey(const Key('broker-new-listing')));
    await tester.tap(find.byKey(const Key('broker-new-listing')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('listing-title')).evaluate().isNotEmpty,
    );
    expect(find.text('List your property'), findsOneWidget);
    await _home(tester, container);

    await tester.tap(find.byKey(const Key('broker-tile-leads')));
    await tester.pump();
    await _until(
      tester,
      () => find
          .byKey(const Key('broker-lead-card-demo-lead-meera'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('broker-lead-card-demo-lead-meera')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('broker-lead-reply')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('broker-lead-reply')));
    await tester.pump();
    await _until(
      tester,
      () => find.textContaining('Replied').evaluate().isNotEmpty,
    );
    expect(find.textContaining('Replied'), findsWidgets);
    await tester.tap(find.byKey(const Key('broker-lead-chat')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('chat-send')).evaluate().isNotEmpty,
    );
    expect(find.text('Meera K.'), findsWidgets);
    await _home(tester, container);

    await tester.tap(find.byKey(const Key('broker-tile-chats')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('broker-chat-card-broker-rohan')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('chat-send')).evaluate().isNotEmpty,
    );
    expect(find.text('Rohan Mehta'), findsWidgets);
    await _home(tester, container);

    await tester.tap(find.byKey(const Key('broker-tile-visits')));
    await tester.pump();
    await _until(
      tester,
      () => find
          .byKey(const Key('broker-visit-card-demo-lead-arjun'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('broker-schedule-visit')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Visit requested for'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('broker-visit-card-demo-lead-arjun')),
    );
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('broker-visit-confirm')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('broker-visit-confirm')));
    await tester.pump();
    await _until(
      tester,
      () => find.textContaining('Replied').evaluate().isNotEmpty,
    );
    expect(find.textContaining('Replied'), findsWidgets);
    await tester.tap(find.byKey(const Key('broker-visit-chat')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('chat-send')).evaluate().isNotEmpty,
    );
    expect(find.text('Arjun P.'), findsWidgets);
    await _home(tester, container);

    expect(find.byKey(const Key('broker-home-create-profile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('broker-home-create-profile')));
    await tester.pump();
    await _until(
      tester,
      () => find.byKey(const Key('broker-name')).evaluate().isNotEmpty,
    );
    expect(_path(container), RoutePaths.brokerRegister);
    expect(find.textContaining('NoBroker'), findsNothing);
  });
}
