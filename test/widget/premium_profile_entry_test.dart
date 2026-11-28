import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/premium/premium_screen.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
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

void main() {
  testWidgets('Profile has a HOMIZI Premium entry that opens the paywall', (
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
        roles: ['tenant'],
        city: 'Ahmedabad, Gujarat',
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
          path: RoutePaths.premium,
          builder: (context, state) => const PremiumScreen(),
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
          profileHubGatewayProvider.overrideWithValue(_EmptyActivity()),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    // The profile photo animates forever, so pump a fixed time.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final entry = find.byKey(const Key('profile-premium-entry'));
    await tester.scrollUntilVisible(
      entry,
      250,
      scrollable: find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      ),
    );
    expect(find.text('HOMIZI Premium'), findsOneWidget);
    await tester.tap(entry);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('premium-screen')), findsOneWidget);
    expect(find.text('Unlimited owner contacts'), findsOneWidget);
  });
}
