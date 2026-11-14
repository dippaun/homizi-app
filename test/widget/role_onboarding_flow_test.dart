import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/roles/role_flow.dart';
import 'package:homizi/features/roles/role_provider.dart';
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

class _SignedOut extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _ReadyHost extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'rahul.sharma@homizi.in',
      role: AccountRole.host,
      homiziWire: 'host',
      policyVersion: '2026-10-11-draft',
    );
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
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

void _expectNotLegacy(String path) {
  expect(legacyRolePaths.contains(path), isFalse, reason: path);
}

void _expectNoLegacyCopy() {
  expect(find.text('What you need'), findsNothing);
  expect(find.text('Step 1 of 13'), findsNothing);
  expect(find.text('Your tenant home'), findsNothing);
  expect(find.text('Your broker desk'), findsNothing);
  expect(find.text('Your homes'), findsNothing);
  expect(find.text('City and localities'), findsNothing);
}

Future<void> _choose(WidgetTester tester, String wire) async {
  await tester.tap(find.byKey(Key('role-card-$wire')));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('role-continue')));
  await tester.tap(find.byKey(const Key('role-continue')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('the role page is the first screen after sign-in', (
    tester,
  ) async {
    final container = await _pump(tester, _NeedsRole.new);
    expect(_path(container), RoutePaths.role);
    expect(find.byKey(const Key('role-onboarding-screen')), findsOneWidget);
    expect(find.text('How will you use HOMIZI?'), findsWidgets);
    expect(find.byKey(const Key('personalize-screen')), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    _expectNoLegacyCopy();
  });

  testWidgets('signed-out onboarding starts on the role page', (tester) async {
    final container = await _pump(tester, _SignedOut.new);
    container.read(routerProvider).go(RoutePaths.role);
    await tester.pump();
    await tester.pump();
    expect(_path(container), RoutePaths.role);
    expect(find.byKey(const Key('role-onboarding-screen')), findsOneWidget);
    await _choose(tester, 'tenant');
    expect(_path(container), RoutePaths.personalize);
    expect(find.byKey(const Key('personalize-screen')), findsOneWidget);
    expect(container.read(currentRoleProvider), HomiziRole.tenant);
  });

  testWidgets('the preferences screen has no role question', (tester) async {
    final container = await _pump(tester, _NeedsRole.new);
    await _choose(tester, 'tenant');
    expect(find.byKey(const Key('personalize-screen')), findsOneWidget);
    expect(find.text('How will you use HOMIZI?'), findsNothing);
    expect(find.text('Tenant / Home-Seeker'), findsNothing);
    expect(find.text('Host / Owner'), findsNothing);
    expect(find.text('Property Partner'), findsNothing);
    expect(find.text('Home-Sharer'), findsNothing);
    expect(find.text('Language'), findsNothing);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Preferred city'), findsOneWidget);
    expect(find.text('What are you looking for?'), findsOneWidget);
    expect(find.text('A whole home'), findsOneWidget);
    expect(find.text('Indicative budget'), findsOneWidget);
    expect(find.text('When do you move?'), findsOneWidget);
    expect(find.text('Optional preferences'), findsOneWidget);
    expect(find.text('Use my location'), findsOneWidget);
    expect(find.byKey(const Key('personalize-skip')), findsNothing);
    _expectNotLegacy(_path(container));
    _expectNoLegacyCopy();
  });

  testWidgets('preferences stay off the other roles', (tester) async {
    final container = await _pump(tester, _ReadyHost.new);
    container.read(routerProvider).go(RoutePaths.personalize);
    await tester.pump();
    await tester.pump();
    expect(_path(container), RoutePaths.ownerSetup);
    expect(find.byKey(const Key('owner-setup-screen')), findsOneWidget);
    expect(find.byKey(const Key('personalize-screen')), findsNothing);
    expect(find.text('How will you use HOMIZI?'), findsNothing);
    _expectNoLegacyCopy();
  });

  testWidgets('a tenant setup ends on the home feed', (tester) async {
    final container = await _pump(tester, _NeedsRole.new);
    await _choose(tester, 'tenant');
    await tester.tap(find.byKey(const Key('personalize-city-Bengaluru')));
    await tester.pump();
    await tester.tap(find.text('A whole home'));
    await tester.tap(find.text('Within a month'));
    await tester.ensureVisible(find.byKey(const Key('personalize-save')));
    await tester.tap(find.byKey(const Key('personalize-save')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('role-ready-screen')), findsOneWidget);
    expect(find.text("You're all set"), findsWidgets);
    _expectNotLegacy(_path(container));
    _expectNoLegacyCopy();
    await tester.tap(find.byKey(const Key('role-ready-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_path(container), RoutePaths.home);
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(container.read(sessionProvider).homiziWire, 'tenant');
    _expectNoLegacyCopy();
  });

  testWidgets('a host setup offers list your property, then the dashboard', (
    tester,
  ) async {
    final container = await _pump(tester, _NeedsRole.new);
    await _choose(tester, 'host');
    expect(find.byKey(const Key('owner-setup-screen')), findsOneWidget);
    expect(find.byKey(const Key('personalize-screen')), findsNothing);
    await tester.tap(find.byKey(const Key('owner-city-Pune')));
    await tester.tap(find.text('Apartment'));
    await tester.tap(find.text('Just one'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('owner-setup-continue')));
    await tester.tap(find.byKey(const Key('owner-setup-continue')));
    await tester.pump();
    await tester.pump();
    expect(find.text("You're all set"), findsWidgets);
    expect(find.text('List your property'), findsOneWidget);
    _expectNotLegacy(_path(container));
    _expectNoLegacyCopy();
    await tester.tap(find.byKey(const Key('role-ready-dashboard')));
    await tester.pump();
    await tester.pump();
    expect(_path(container), RoutePaths.ownerDashboard);
    expect(find.byKey(const Key('owner-dashboard')), findsOneWidget);
    expect(find.text('My listings'), findsWidgets);
    expect(container.read(sessionProvider).homiziWire, 'host');
    _expectNoLegacyCopy();
  });

  testWidgets('a property partner setup opens the partner dashboard', (
    tester,
  ) async {
    final container = await _pump(tester, _NeedsRole.new);
    await _choose(tester, 'broker');
    expect(find.byKey(const Key('partner-setup-screen')), findsOneWidget);
    expect(find.text('Broker registration'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('partner-agency')),
      'Deshpande Realty',
    );
    await tester.tap(find.byKey(const Key('partner-city-Bengaluru')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('partner-setup-continue')));
    await tester.tap(find.byKey(const Key('partner-setup-continue')));
    await tester.pump();
    await tester.pump();
    expect(find.text("You're all set"), findsWidgets);
    _expectNotLegacy(_path(container));
    _expectNoLegacyCopy();
    await tester.tap(find.byKey(const Key('role-ready-continue')));
    await tester.pump();
    await tester.pump();
    expect(_path(container), RoutePaths.partnerHome);
    expect(find.byKey(const Key('partner-dashboard')), findsOneWidget);
    expect(find.text('Seeker demand'), findsOneWidget);
    expect(find.text('My listings'), findsWidgets);
    expect(find.text('Leads'), findsOneWidget);
    expect(container.read(sessionProvider).homiziWire, 'broker');
    _expectNoLegacyCopy();
  });

  testWidgets('a home-sharer setup opens Find Your Roomie', (tester) async {
    final container = await _pump(tester, _NeedsRole.new);
    await _choose(tester, 'roommate');
    expect(find.byKey(const Key('sharer-setup-screen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sharer-city-Mumbai')));
    await tester.enterText(
      find.byKey(const Key('sharer-locality')),
      'Bandra West',
    );
    await tester.tap(find.byKey(const Key('sharer-room-private')));
    await tester.tap(find.text('Women'));
    await tester.tap(find.text('Vegetarian'));
    await tester.ensureVisible(find.byKey(const Key('sharer-setup-continue')));
    await tester.tap(find.byKey(const Key('sharer-setup-continue')));
    await tester.pump();
    await tester.pump();
    expect(find.text("You're all set"), findsWidgets);
    _expectNotLegacy(_path(container));
    _expectNoLegacyCopy();
    await tester.tap(find.byKey(const Key('role-ready-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_path(container), RoutePaths.roommate);
    expect(find.text('Roommate Finder'), findsWidgets);
    expect(container.read(sessionProvider).homiziWire, 'roommate');
    _expectNoLegacyCopy();
  });
}
