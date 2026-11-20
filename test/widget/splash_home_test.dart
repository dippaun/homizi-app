import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _NeedsRole extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.needsRole,
      contact: 'ananya.iyer@homizi.in',
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _Ready extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'meera.nair@homizi.in',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _FirstVisit extends SessionController {
  @override
  SessionState build() => const SessionState(phase: SessionPhase.signedOut);
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  SessionController Function()? session,
) async {
  _phone(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [if (session != null) sessionProvider.overrideWith(session)],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
}

void _expectHome(WidgetTester tester) {
  expect(find.byKey(const Key('home-screen')), findsOneWidget);
  expect(find.text('Find a place.'), findsOneWidget);
  expect(find.text('Create Your Profile'), findsWidgets);
  expect(find.text('Explore rentals'), findsOneWidget);
  expect(find.byKey(const Key('splash-search')), findsNothing);
  expect(find.byKey(const Key('role-onboarding-screen')), findsNothing);
  expect(find.byKey(const Key('welcome-screen')), findsNothing);
  expect(find.byKey(const Key('contact-field')), findsNothing);
  expect(find.text('How will you use HOMIZI?'), findsNothing);
  expect(find.text('Agree and continue'), findsNothing);
}

void main() {
  testWidgets('splash opens Home for a first visit', (tester) async {
    await _pump(tester, null);
    expect(find.byKey(const Key('splash-search')), findsOneWidget);
    expect(
      GoRouter.of(
        tester.element(find.byKey(const Key('splash-search'))),
      ).state.uri.path,
      RoutePaths.splash,
    );

    await tester.tap(find.byKey(const Key('splash-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    _expectHome(tester);
    expect(
      GoRouter.of(
        tester.element(find.byKey(const Key('home-screen'))),
      ).state.uri.path,
      RoutePaths.home,
    );
  });

  testWidgets('splash opens Home when a role is still unset', (tester) async {
    await _pump(tester, _NeedsRole.new);
    await tester.pump(const Duration(milliseconds: 50));
    _expectHome(tester);
  });

  testWidgets('splash opens Home for a signed-in tenant', (tester) async {
    await _pump(tester, _Ready.new);
    await tester.pump(const Duration(milliseconds: 50));
    _expectHome(tester);
    expect(find.byKey(const Key('home-card-profile')), findsNothing);
    expect(find.byKey(const Key('home-custom-section')), findsOneWidget);
  });

  testWidgets('splash opens Home before consent', (tester) async {
    await _pump(tester, _FirstVisit.new);
    await tester.pump(const Duration(milliseconds: 50));
    _expectHome(tester);
  });
}
