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
import 'package:homizi/features/interest/swipe_screen.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';
import 'package:homizi/features/listings/photo_manager_screen.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/owner/for_owners_screen.dart';
import 'package:homizi/features/owner/owner_overview_screen.dart';
import 'package:homizi/features/profile/host_profile_screen.dart';
import 'package:homizi/features/profile/profile_hub_screen.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/public_profile.dart';
import 'package:homizi/features/roles/seeker_matches_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/settings/settings_screen.dart';
import 'package:homizi/features/support/help_screen.dart';
import 'package:homizi/features/verification/kyc_screen.dart';

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
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await _tap(tester, find.byKey(const Key('create-profile')));
    await _tap(tester, find.byKey(const Key('login-continue')));
    expect(find.byKey(const Key('role-card-host')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('role-card-host')));
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
    expect(find.byType(HostHomeScreen).hitTestable(), findsOneWidget);
    _expectPath(container, RoutePaths.home);
  });

  testWidgets('every host entry point opens a real screen', (tester) async {
    final container = await _pump(tester, _ReadyHost.new);
    expect(find.byType(HostHomeScreen).hitTestable(), findsOneWidget);
    expect(find.textContaining('NoBroker'), findsNothing);
    expect(find.textContaining('99acres'), findsNothing);

    Future<void> open(String key, Finder marker, String path) async {
      await _tap(tester, find.byKey(Key(key)));
      expect(marker.hitTestable(), findsAtLeastNWidgets(1));
      _expectPath(container, path);
      container.read(routerProvider).go(RoutePaths.home);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(HostHomeScreen).hitTestable(), findsOneWidget);
    }

    await open(
      'host-create-profile',
      find.byType(HostProfileScreen),
      RoutePaths.hostProfile,
    );
    await open(
      'host-see-seekers',
      find.byType(SeekerMatchesScreen),
      RoutePaths.hostSeekers,
    );
    await open(
      'host-post-property',
      find.byType(ListingEditorScreen),
      RoutePaths.listingEditor,
    );
    await open(
      'host-tile-dashboard',
      find.byType(OwnerOverviewScreen),
      RoutePaths.ownerOverview,
    );
    await open(
      'host-tile-listings',
      find.byKey(const Key('owner-dashboard')),
      RoutePaths.listings,
    );
    await open(
      'host-tile-leads',
      find.byKey(const Key('host-leads-screen')),
      RoutePaths.hostLeads,
    );
    await open(
      'host-tile-photos',
      find.byType(PhotoManagerScreen),
      RoutePaths.photoManager,
    );
    await open(
      'host-tile-visits',
      find.byKey(const Key('host-visits-screen')),
      RoutePaths.hostVisits,
    );
    await open(
      'host-tile-chats',
      find.byType(MatchesScreen),
      RoutePaths.matches,
    );
    await open(
      'host-tile-verify',
      find.byType(KycScreen),
      RoutePaths.verifyIdentity,
    );
    await open(
      'host-tile-profile',
      find.byType(ProfileHubScreen),
      RoutePaths.profile,
    );
    await open(
      'host-tile-options',
      find.text('How do you want to start?'),
      RoutePaths.hostOptions,
    );
    await open(
      'host-tile-owners',
      find.byType(ForOwnersScreen),
      RoutePaths.forOwners,
    );
    await open(
      'host-tile-seekers',
      find.byKey(const Key('seekers-screen')),
      RoutePaths.seekers,
    );
    await open(
      'host-tile-swipe',
      find.byType(SwipeScreen),
      RoutePaths.discover,
    );
    await open(
      'host-tile-settings',
      find.byType(SettingsScreen),
      RoutePaths.settings,
    );
    await open(
      'host-tile-notifications',
      find.text('Notifications'),
      RoutePaths.notifications,
    );
    await open('host-tile-help', find.byType(HelpScreen), RoutePaths.help);

    Future<void> nav(String label, Finder marker, String path) async {
      await _tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      expect(marker.hitTestable(), findsAtLeastNWidgets(1));
      _expectPath(container, path);
    }

    await nav(
      'Seekers',
      find.byKey(const Key('seekers-screen')),
      RoutePaths.seekers,
    );
    await nav('Swipe', find.byType(SwipeScreen), RoutePaths.discover);
    await nav('Matches', find.byType(MatchesScreen), RoutePaths.matches);
    await nav(
      'Listings',
      find.byKey(const Key('owner-dashboard')),
      RoutePaths.listings,
    );
    await nav('Home', find.byType(HostHomeScreen), RoutePaths.home);
  });
}
