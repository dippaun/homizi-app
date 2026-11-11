import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/role_gate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/roles/role_provider.dart';

class _Desk {
  const _Desk(this.name, this.allowed, this.allowedRole, this.wrongRoles);
  final String name;
  final Set<HomiziRole> allowed;
  final HomiziRole allowedRole;
  final List<HomiziRole?> wrongRoles;
}

const _hostOrBroker = {HomiziRole.host, HomiziRole.broker};

final _desks = <_Desk>[
  const _Desk('Host leads', _hostOrBroker, HomiziRole.host, [
    HomiziRole.tenant,
    HomiziRole.roommate,
    null,
  ]),
  const _Desk('Owner dashboard', _hostOrBroker, HomiziRole.host, [
    HomiziRole.tenant,
    HomiziRole.roommate,
    null,
  ]),
  const _Desk('Owner dashboard (broker)', _hostOrBroker, HomiziRole.broker, [
    HomiziRole.tenant,
  ]),
  const _Desk(
    'Broker leads',
    {HomiziRole.broker},
    HomiziRole.broker,
    [HomiziRole.host, HomiziRole.tenant, HomiziRole.roommate, null],
  ),
];

Future<void> _pump(WidgetTester tester, _Desk desk, HomiziRole? role) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/desk',
    routes: [
      GoRoute(
        path: RoutePaths.role,
        builder: (c, s) =>
            const Scaffold(key: Key('role-screen'), body: Text('Roles')),
      ),
      GoRoute(
        path: '/desk',
        builder: (c, s) => RoleGate(
          allowed: desk.allowed,
          title: desk.name,
          message: '${desk.name} is role-only.',
          child: const Scaffold(key: Key('desk-ok'), body: Text('ok')),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentRoleProvider.overrideWithValue(role)],
      child: MaterialApp.router(
        theme: HomiziTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final desk in _desks) {
    testWidgets('${desk.name}: allowed role ${desk.allowedRole.name} opens', (
      tester,
    ) async {
      await _pump(tester, desk, desk.allowedRole);
      expect(find.byKey(const Key('desk-ok')), findsOneWidget);
      expect(find.byKey(const Key('role-gate-blocked')), findsNothing);
    });
    for (final wrong in desk.wrongRoles) {
      testWidgets('${desk.name}: wrong role ${wrong?.name ?? 'none'} blocked', (
        tester,
      ) async {
        await _pump(tester, desk, wrong);
        expect(find.byKey(const Key('role-gate-blocked')), findsOneWidget);
        expect(find.byKey(const Key('desk-ok')), findsNothing);
        await tester.tap(find.text('Choose a role'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('role-screen')), findsOneWidget);
      });
    }
  }
}
