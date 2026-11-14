import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/onboarding/welcome_screen.dart';
import 'package:homizi/features/profile/tenant_profile_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/tenant/tenant_intent.dart';

class _SignedOut extends SessionController {
  @override
  SessionState build() => const SessionState(phase: SessionPhase.signedOut);
}

class _ReadyTenant extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'meera.iyer@homizi.in',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _NeedsRole extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.needsRole,
      contact: 'meera.iyer@homizi.in',
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

class _NeedsSignIn extends DemoAccountGateway {
  @override
  Future<TenantProfile> loadTenantProfile() async {
    throw const AccountFailure('Sign in to create your tenant profile.');
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2600);
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
  return container;
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets);
}

Uri _uri(WidgetTester tester) {
  final scaffolds = find.byType(Scaffold).evaluate();
  return GoRouterState.of(scaffolds.last).uri;
}

void main() {
  test('a pending tenant profile leaves auth for setup', () {
    expect(
      tenantIntentRedirect(
        base: RoutePaths.home,
        phase: SessionPhase.ready,
        path: RoutePaths.login,
        profilePending: true,
      ),
      RoutePaths.tenantSetup,
    );
    expect(
      tenantIntentRedirect(
        base: null,
        phase: SessionPhase.ready,
        path: RoutePaths.tenantSetup,
        profilePending: true,
      ),
      isNull,
    );
    expect(
      tenantIntentRedirect(
        base: null,
        phase: SessionPhase.ready,
        path: RoutePaths.explore,
        profilePending: true,
      ),
      isNull,
    );
    expect(
      tenantIntentRedirect(
        base: RoutePaths.login,
        phase: SessionPhase.signedOut,
        path: RoutePaths.welcome,
        profilePending: true,
      ),
      RoutePaths.login,
    );
  });

  testWidgets('create profile before login opens sign-in, then the form', (
    tester,
  ) async {
    final container = await _pump(tester, _SignedOut.new);
    container.read(routerProvider).go(RoutePaths.welcome);
    await tester.pump();
    await _until(tester, find.byType(WelcomeScreen));
    expect(find.byKey(const Key('welcome-role-tenant')), findsOneWidget);
    expect(find.text('Sign in to create your tenant profile.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('consent-checkbox')));
    await tester.tap(find.byKey(const Key('consent-checkbox')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('create-profile-before-login')),
    );
    await tester.tap(find.byKey(const Key('create-profile-before-login')));
    await tester.pump();
    await _until(tester, find.byKey(const Key('tenant-profile-signin-prompt')));
    expect(_uri(tester).path, RoutePaths.login);
    expect(container.read(tenantIntentProvider), TenantIntent.profile);

    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'meera.iyer@homizi.in',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.ensureVisible(find.byKey(const Key('verify-code')));
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pump();
    await _until(tester, find.byKey(const Key('login-continue')));
    await tester.tap(find.byKey(const Key('login-continue')));
    await tester.pump();
    await _until(tester, find.byKey(const Key('tenant-setup-name')));
    expect(_uri(tester).path, RoutePaths.tenantSetup);
    expect(container.read(sessionProvider).homiziWire, 'tenant');

    await tester.enterText(
      find.byKey(const Key('tenant-setup-name')),
      'Meera Iyer',
    );
    await tester.enterText(
      find.byKey(const Key('tenant-setup-locality')),
      'Indiranagar, Koramangala',
    );
    await tester.ensureVisible(find.byKey(const Key('save-tenant-setup')));
    await tester.tap(find.byKey(const Key('save-tenant-setup')));
    await tester.pump();
    await _until(tester, find.byKey(const Key('home-screen')));

    expect(_uri(tester).path, RoutePaths.home);
    expect(find.byKey(const Key('tenant-home-screen')), findsNothing);
    expect(find.text('Your tenant home'), findsNothing);
    expect(find.text('What you need'), findsNothing);
    expect(container.read(tenantIntentProvider), isNull);
    final saved = await container
        .read(accountGatewayProvider)
        .loadTenantProfile();
    expect(saved.displayName, 'Meera Iyer');
    expect(saved.preferences.localities, ['Indiranagar', 'Koramangala']);
    expect(saved.preferences.budgetMinInr, 12000);
    expect(saved.preferences.budgetMaxInr, 35000);
    expect(saved.preferences.propertyTypes, contains('apartment'));
    expect(find.textContaining('NoBroker'), findsNothing);
  });

  testWidgets('choosing tenant with a pending profile opens setup', (
    tester,
  ) async {
    final container = await _pump(tester, _NeedsRole.new);
    await _until(tester, find.byKey(const Key('role-card-tenant')));
    container.read(tenantIntentProvider.notifier).state = TenantIntent.profile;
    await tester.pump();
    await _until(tester, find.byKey(const Key('tenant-setup-screen')));
    expect(_uri(tester).path, RoutePaths.tenantSetup);
    expect(container.read(sessionProvider).homiziWire, 'tenant');
    expect(find.text('What you need'), findsNothing);
  });

  testWidgets('the old tenant home menu is not the landing', (tester) async {
    final container = await _pump(tester, _ReadyTenant.new);
    await _until(tester, find.byKey(const Key('home-screen')));
    expect(find.byKey(const Key('menu-tenant-home')), findsNothing);
    expect(find.text('Your tenant home'), findsNothing);
    container.read(routerProvider).go(RoutePaths.tenantHome);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_uri(tester).path, RoutePaths.home);
    expect(find.byKey(const Key('tenant-home-screen')), findsNothing);
    container.read(routerProvider).go(RoutePaths.requirement);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_uri(tester).path, RoutePaths.requirement);
    expect(find.byKey(const Key('sign-in-gate')), findsNothing);
    expect(find.text('What you need'), findsOneWidget);
  });

  testWidgets('the profile sign-in prompt opens login', (tester) async {
    _phone(tester);
    final router = GoRouter(
      initialLocation: RoutePaths.tenantProfile,
      routes: [
        GoRoute(
          path: RoutePaths.tenantProfile,
          builder: (context, state) => const TenantProfileScreen(),
        ),
        GoRoute(
          path: RoutePaths.login,
          builder: (context, state) =>
              const Scaffold(body: Text('Signed-in next')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [accountGatewayProvider.overrideWith((ref) => _NeedsSignIn())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await _until(
      tester,
      find.widgetWithText(
        OutlinedButton,
        'Sign in to create your tenant profile.',
      ),
    );
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'Sign in to create your tenant profile.',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Signed-in next'), findsOneWidget);
    expect(container.read(tenantIntentProvider), TenantIntent.profile);
    expect(router.routeInformationProvider.value.uri.path, RoutePaths.login);
  });
}
