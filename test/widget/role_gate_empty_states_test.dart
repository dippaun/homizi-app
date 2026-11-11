import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/role_gate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/roles/seeker_match.dart';
import 'package:homizi/features/roles/seeker_matches_screen.dart';
import 'package:homizi/features/roles/seeker_providers.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _TenantSession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'test5@homizi.in',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
      userId: 'tenant-user',
    );
  }
}

class _FixedSeekers implements SeekerMatchGateway {
  const _FixedSeekers(this.page);

  final SeekerMatchPage page;

  @override
  Future<SeekerMatchPage> load() async => page;
}

void main() {
  testWidgets('RoleGate blocks the wrong role with an empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/desk',
      routes: [
        GoRoute(
          path: RoutePaths.role,
          builder: (context, state) =>
              const Scaffold(key: Key('role-screen'), body: Text('Roles')),
        ),
        GoRoute(
          path: '/desk',
          builder: (context, state) => const RoleGate(
            allowed: {HomiziRole.broker},
            title: 'Broker chats',
            message: 'Broker chats are for the broker role.',
            child: Scaffold(key: Key('desk-ok'), body: Text('ok')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_TenantSession.new)],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('role-gate-blocked')), findsOneWidget);
    expect(find.byKey(const Key('empty-state')), findsOneWidget);
    expect(find.byKey(const Key('desk-ok')), findsNothing);
  });

  testWidgets('empty seekers board uses EmptyState with a listing CTA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seekerMatchGatewayProvider.overrideWithValue(
            const _FixedSeekers(
              SeekerMatchPage(seekers: [], basis: 'No listings yet.'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const SeekerMatchesScreen(title: 'Matching seekers'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('seekers-empty')), findsOneWidget);
    expect(find.byKey(const Key('empty-state')), findsOneWidget);
    expect(find.text('Post a listing'), findsOneWidget);
  });
}
