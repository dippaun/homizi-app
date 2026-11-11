import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/profile/domain/profile_contact.dart';
import 'package:homizi/features/profile/profile_hub_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _ReadySession extends SessionController {
  _ReadySession(this.contact);

  final String contact;

  @override
  SessionState build() {
    return SessionState(
      phase: SessionPhase.ready,
      contact: contact,
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHub(
    WidgetTester tester, {
    required String contact,
    TenantProfile? profile,
    GoRouter? router,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accounts = DemoAccountGateway();
    if (profile != null) {
      await accounts.saveTenantProfile(profile);
    }
    final child = router == null
        ? MaterialApp(
            theme: HomiziTheme.light(),
            home: const ProfileHubScreen(),
          )
        : MaterialApp.router(theme: HomiziTheme.light(), routerConfig: router);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _ReadySession(contact)),
          accountGatewayProvider.overrideWithValue(accounts),
        ],
        child: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) {
    return tester.scrollUntilVisible(
      finder.hitTestable(),
      400,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('activity is one row per category and hides the long lists', (
    tester,
  ) async {
    await pumpHub(
      tester,
      contact: 'ananya@example.test',
      profile: const TenantProfile(
        displayName: 'Ananya Iyer',
        occupation: 'Product designer',
        bio: 'Looking for a quiet furnished room in Koramangala.',
        preferences: TenantPreferences(
          budgetMinInr: 18000,
          budgetMaxInr: 28000,
          localities: ['Koramangala'],
        ),
      ),
    );

    expect(find.byKey(const Key('profile-name')), findsOneWidget);
    expect(find.text('Ananya Iyer'), findsWidgets);
    expect(find.byKey(const Key('profile-role')), findsOneWidget);
    expect(find.text('My top priorities'), findsOneWidget);
    expect(find.text('Sunlit 2BHK in Koramangala'), findsNothing);
    expect(find.text('Studio near Indiranagar metro'), findsNothing);
    expect(find.text('Bengaluru · ₹18,000 to ₹28,000'), findsNothing);
    expect(find.text('Requested · 2026-10-12'), findsNothing);
    expect(find.text('Rohan M.'), findsNothing);
    expect(find.text('Verified via Digio'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('activity-saved'))).data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('activity-matches'))).data,
      '4',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-aadhaar-status'))).data,
      'Not verified',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-selfie-status'))).data,
      'Not verified',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-phone'))).data,
      'Not added',
    );
    expect(find.text('Koramangala'), findsWidgets);
    expect(find.textContaining('18,000'), findsWidgets);
  });

  testWidgets('a phone on the account is masked on the profile', (
    tester,
  ) async {
    await pumpHub(
      tester,
      contact: '+919845012321',
      profile: const TenantProfile(displayName: 'Kabir Shah'),
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('profile-phone'))).data,
      contains('2321'),
    );
    expect(find.textContaining('98450'), findsNothing);
    expect(find.textContaining('9845012321'), findsNothing);
    expect(containsFullIndianMobile('+91 ••••• 2321'), isFalse);
  });

  testWidgets(
    'empty offline profile shows the sample and keeps storage empty',
    (tester) async {
      final accounts = DemoAccountGateway();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(
              () => _ReadySession('qa+tenant@homizi.in'),
            ),
            accountGatewayProvider.overrideWithValue(accounts),
          ],
          child: MaterialApp(
            theme: HomiziTheme.light(),
            home: const ProfileHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Priya Nair'), findsWidgets);
      expect(find.text(profileShowcaseEmail), findsNothing);
      expect(find.textContaining('984'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('profile-aadhaar-status')))
            .data,
        'Not verified',
      );
      expect((await accounts.loadTenantProfile()).displayName, isEmpty);
    },
  );

  testWidgets('activity rows open the existing lists and share confirms', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutePaths.profile,
      routes: [
        GoRoute(
          path: RoutePaths.profile,
          builder: (context, state) => const ProfileHubScreen(),
        ),
        GoRoute(
          path: RoutePaths.saved,
          builder: (context, state) =>
              const Scaffold(body: Text('Saved homes')),
        ),
        GoRoute(
          path: RoutePaths.recentlyViewed,
          builder: (context, state) =>
              const Scaffold(body: Text('Viewed homes')),
        ),
        GoRoute(
          path: RoutePaths.matches,
          builder: (context, state) => const Scaffold(body: Text('Match list')),
        ),
        GoRoute(
          path: RoutePaths.tenantProfile,
          builder: (context, state) =>
              const Scaffold(body: Text('Tenant editor')),
        ),
        GoRoute(
          path: RoutePaths.demoDone,
          builder: (context, state) => DemoSuccessScreen(
            title: state.uri.queryParameters['title'] ?? '',
            detail: state.uri.queryParameters['detail'] ?? '',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpHub(
      tester,
      contact: 'ananya@example.test',
      profile: const TenantProfile(displayName: 'Ananya Iyer'),
      router: router,
    );

    await reveal(tester, find.byKey(const Key('activity-saved')));
    await tester.tap(find.byKey(const Key('activity-saved')));
    await tester.pumpAndSettle();
    expect(find.text('Saved homes'), findsOneWidget);

    router.go(RoutePaths.profile);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('profile-see-all')));
    await tester.tap(find.byKey(const Key('profile-see-all')));
    await tester.pumpAndSettle();
    expect(find.text('Match list'), findsOneWidget);

    router.go(RoutePaths.profile);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('profile-primary-action')));
    await tester.tap(find.byKey(const Key('profile-primary-action')));
    await tester.pumpAndSettle();
    expect(find.text('Tenant editor'), findsOneWidget);

    router.go(RoutePaths.profile);
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-share')));
    await tester.pumpAndSettle();
    expect(find.text('Profile link ready'), findsOneWidget);
    expect(find.text('Your phone number stays hidden.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DemoSuccessScreen),
        matching: find.textContaining('@'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DemoSuccessScreen),
        matching: find.textContaining('+91'),
      ),
      findsNothing,
    );
  });

  testWidgets('the photo badge opens choose and remove stays available', (
    tester,
  ) async {
    await pumpHub(
      tester,
      contact: 'ananya@example.test',
      profile: const TenantProfile(
        displayName: 'Ananya Iyer',
        avatarUrl: 'photo-set',
      ),
    );

    expect(find.byKey(const Key('avatar-gallery')), findsNothing);
    await tester.tap(find.byKey(const Key('avatar-change')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('avatar-gallery')), findsOneWidget);
    expect(find.byKey(const Key('avatar-remove')), findsOneWidget);
  });
}
