import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/auth/registration_finish_screen.dart';
import 'package:homizi/features/auth/registration_gate.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

void main() {
  test('a stale registration gate does not reopen the role picker', () {
    expect(
      forcedRegistrationPath(
        bypass: true,
        gateLoading: true,
        gateValue: true,
        path: RoutePaths.home,
      ),
      isNull,
    );
    expect(
      forcedRegistrationPath(
        bypass: false,
        gateLoading: true,
        gateValue: true,
        path: RoutePaths.home,
      ),
      isNull,
    );
    expect(
      forcedRegistrationPath(
        bypass: false,
        gateLoading: false,
        gateValue: false,
        path: RoutePaths.home,
      ),
      isNull,
    );
  });

  test('an unfinished account is still sent to registration', () {
    expect(
      forcedRegistrationPath(
        bypass: false,
        gateLoading: false,
        gateValue: true,
        path: RoutePaths.home,
      ),
      RoutePaths.registerFinish,
    );
    expect(
      forcedRegistrationPath(
        bypass: false,
        gateLoading: false,
        gateValue: true,
        path: RoutePaths.profileCreate,
      ),
      isNull,
    );
  });

  test('a saved name and role count as registration complete', () {
    expect(
      registrationIsComplete(displayName: 'Asha Mehta', roleWire: 'tenant'),
      isTrue,
    );
    expect(
      registrationIsComplete(displayName: 'Asha Mehta', roleWire: null),
      isFalse,
    );
    expect(
      registrationIsComplete(displayName: 'A', roleWire: 'tenant'),
      isFalse,
    );
  });

  testWidgets('a completed profile leaves the role page for Home', (
    tester,
  ) async {
    final store = ProfileCreateStore(DemoAccountGateway())
      ..draft = const ProfileCreateDraft(
        nickname: 'Asha',
        surname: 'Mehta',
        roles: ['tenant'],
      );
    final router = GoRouter(
      initialLocation: RoutePaths.registerFinish,
      routes: [
        GoRoute(
          path: RoutePaths.registerFinish,
          builder: (context, state) => const RegistrationFinishScreen(),
        ),
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) =>
              const Scaffold(key: Key('home-screen'), body: Text('Home')),
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
          sessionProvider.overrideWith(_ReadyTenant.new),
          profileCreateStoreProvider.overrideWithValue(store),
          registrationGateProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.byKey(const Key('registration-role-continue')), findsNothing);
    expect(find.text('Select Your Role'), findsNothing);
  });
}

class _ReadyTenant extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'asha@example.test',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
      userId: '11111111-1111-4111-8111-111111111111',
    );
  }
}
