import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/priorities_handoff.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_providers.dart';
import 'package:homizi/features/profile/profile_me_screen.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _Ready extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _EmptyActivity implements ProfileHubGateway {
  @override
  Future<ProfileActivity> loadActivity() async => ProfileActivity.empty;
}

class _KnownActivity implements ProfileHubGateway {
  @override
  Future<ProfileActivity> loadActivity() async {
    return const ProfileActivity(
      savedCount: 2,
      viewedAvailable: true,
      viewedCount: 5,
      requestCount: 1,
      visitCount: 0,
      matchCount: 3,
    );
  }
}

void main() {
  testWidgets('dashboard shows real counts, a computed percent, and edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ProfileCreateStore(DemoAccountGateway())
      ..draft = const ProfileCreateDraft(
        nickname: 'Rohan',
        surname: 'Sharma',
        occupation: 'Working professional',
        roles: ['tenant', 'host'],
        city: 'Ahmedabad, Gujarat',
        mobileVerified: true,
        emailVerified: true,
      );
    final router = GoRouter(
      initialLocation: RoutePaths.profileMe,
      routes: [
        GoRoute(
          path: RoutePaths.profile,
          builder: (context, state) => const ProfileMeScreen(),
          routes: [
            GoRoute(
              path: 'me',
              builder: (context, state) => const ProfileMeScreen(),
            ),
          ],
        ),
        GoRoute(
          path: RoutePaths.profileCreate,
          builder: (context, state) =>
              const Scaffold(body: Text('Wizard opened')),
        ),
        GoRoute(
          path: RoutePaths.notifications,
          builder: (context, state) => const Scaffold(body: Text('Bell')),
        ),
        GoRoute(
          path: RoutePaths.settings,
          builder: (context, state) => const Scaffold(body: Text('Settings')),
        ),
        GoRoute(
          path: RoutePaths.listingEditor,
          builder: (context, state) => const Scaffold(body: Text('Listing')),
        ),
        GoRoute(
          path: RoutePaths.priorities,
          builder: (context, state) => const PrioritiesHandoff(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              supabaseUrl: '',
              supabaseAnonKey: '',
              policyVersion: '2026-10-11-draft',
              demoSkipLogin: true,
            ),
          ),
          sessionProvider.overrideWith(_Ready.new),
          profileCreateStoreProvider.overrideWith((ref) => store),
          profileHubGatewayProvider.overrideWithValue(_KnownActivity()),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-me-screen')), findsOneWidget);
    expect(find.text('Rohan Sharma'), findsOneWidget);
    expect(find.text('Tenant'), findsWidgets);
    expect(find.byKey(const Key('profile-me-verified')), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byKey(const Key('profile-completeness')), findsOneWidget);
    expect(find.text('92%'), findsNothing);

    await tester.tap(find.byKey(const Key('profile-role-switch')));
    await tester.pumpAndSettle();
    expect(find.text('Host (Owner)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-role-switch')));
    await tester.pumpAndSettle();
    expect(find.text('Tenant'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const Key('profile-tab-My Listings')),
    );
    await tester.tap(find.byKey(const Key('profile-tab-My Listings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-listings-empty')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('profile-tab-Verification')),
    );
    await tester.tap(find.byKey(const Key('profile-tab-Verification')));
    await tester.pumpAndSettle();
    expect(find.text('Mobile Verified'), findsOneWidget);
    expect(find.text('Aadhaar not verified'), findsOneWidget);
    expect(find.text('Aadhaar not started'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('profile-tab-My Profile')));
    await tester.tap(find.byKey(const Key('profile-tab-My Profile')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-edit-about')),
      250,
      scrollable: find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      ),
    );
    await tester.tap(find.byKey(const Key('profile-edit-about')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-edit-about-field')),
      'Software engineer working in Ahmedabad. Looking for a clean flat.',
    );
    await tester.tap(find.byKey(const Key('profile-edit-save')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Software engineer working in Ahmedabad. Looking for a clean flat.',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-add-document')),
      250,
      scrollable: find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      ),
    );
    await tester.tap(find.byKey(const Key('profile-add-document')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-document-name')),
      'PAN Card',
    );
    await tester.tap(find.byKey(const Key('profile-edit-save')));
    await tester.pumpAndSettle();
    expect(find.text('PAN Card'), findsOneWidget);
    expect(find.byKey(const Key('profile-doc-aadhaar')), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('profile-tab-Preferences')),
    );
    await tester.tap(find.byKey(const Key('profile-tab-Preferences')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-my-priorities')),
      250,
      scrollable: find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      ),
    );
    await tester.tap(find.byKey(const Key('profile-my-priorities')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('priorities-handoff')), findsOneWidget);
    expect(find.text('Set My Priorities'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-complete-now')));
    await tester.pumpAndSettle();
    expect(find.text('Wizard opened'), findsOneWidget);
  });

  testWidgets('missing activity is zero', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              supabaseUrl: '',
              supabaseAnonKey: '',
              policyVersion: '2026-10-11-draft',
              demoSkipLogin: true,
            ),
          ),
          sessionProvider.overrideWith(_Ready.new),
          profileHubGatewayProvider.overrideWithValue(_EmptyActivity()),
        ],
        child: const MaterialApp(home: ProfileMeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-stat-matches')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-stat-matches'))).data,
      '0',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-stat-saved'))).data,
      '0',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-stat-views'))).data,
      '0',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-stat-inquiries'))).data,
      '0',
    );
    expect(find.text('Your profile'), findsOneWidget);
  });
}
