import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
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
      contact: 'test5@homizi.in',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _NoActivity implements ProfileHubGateway {
  @override
  Future<ProfileActivity> loadActivity() async => ProfileActivity.empty;
}

Future<void> _pumpProfile(WidgetTester tester, ProfileCreateDraft draft) async {
  tester.view.physicalSize = const Size(390, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = ProfileCreateStore(DemoAccountGateway())..draft = draft;
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
        profileHubGatewayProvider.overrideWithValue(_NoActivity()),
      ],
      child: MaterialApp.router(
        theme: HomiziTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  // The profile screen keeps a looping animation, so pump fixed frames
  // instead of settling.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('nickname lines up with the other account rows', (tester) async {
    await _pumpProfile(
      tester,
      const ProfileCreateDraft(nickname: 'Deep', emailVerified: true),
    );

    final row = find.byKey(const Key('profile-nickname-row'));
    expect(row, findsOneWidget);
    final label = find.descendant(of: row, matching: find.text('Nickname'));
    final value = find.descendant(of: row, matching: find.text('Deep'));
    expect(label, findsOneWidget);
    expect(value, findsOneWidget);

    final email = find.text('Email');
    final emailValue = find.text('test5@homizi.in');
    expect(email, findsOneWidget);
    expect(emailValue, findsOneWidget);

    // Labels share the left edge and values share the value column.
    expect(
      tester.getTopLeft(label).dx,
      closeTo(tester.getTopLeft(email).dx, 0.5),
    );
    expect(
      tester.getTopLeft(value).dx,
      closeTo(tester.getTopLeft(emailValue).dx, 0.5),
    );
    final text = tester.widget<Text>(value);
    expect(text.style?.color, HomiziColors.ink);
    expect(text.style?.fontWeight, FontWeight.w700);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty nickname is a link that opens the editor', (
    tester,
  ) async {
    await _pumpProfile(tester, const ProfileCreateDraft());

    final row = find.byKey(const Key('profile-nickname-row'));
    final link = find.descendant(
      of: row,
      matching: find.text('Add a nickname'),
    );
    expect(link, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.add_circle_outline)),
      findsOneWidget,
    );
    expect(tester.widget<Text>(link).style?.color, HomiziColors.brandRedOrange);
    expect(
      tester.getTopLeft(link).dx,
      closeTo(tester.getTopLeft(find.text('Not added').first).dx, 0.5),
    );

    await tester.tap(find.byKey(const Key('profile-nickname-value')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const Key('profile-edit-nick')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
