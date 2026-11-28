import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/premium/domain/premium_models.dart';
import 'package:homizi/features/premium/premium_providers.dart';
import 'package:homizi/features/premium/premium_screen.dart';
import 'package:homizi/features/premium/premium_service.dart';

class _FakeService implements PremiumService {
  _FakeService({this.outcome});

  final Object? outcome;
  final bought = <PremiumPeriod>[];
  var _status = PremiumStatus.free;

  @override
  PremiumMode get mode => PremiumMode.sandbox;

  @override
  Future<List<PremiumPlan>> loadPlans() async => premiumDefaultPlans;

  @override
  Future<PremiumStatus> currentStatus() async => _status;

  @override
  Future<PremiumStatus> purchase(PremiumPlan plan) async {
    final failure = outcome;
    if (failure != null) {
      throw failure;
    }
    bought.add(plan.period);
    return _status = PremiumStatus(period: plan.period);
  }

  @override
  Future<PremiumStatus> restore() async => _status;
}

Future<GoRouter> _pump(WidgetTester tester, PremiumService service) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push(RoutePaths.premium),
              child: const Text('Open Premium'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.premium,
        builder: (context, state) => const PremiumScreen(),
      ),
      GoRoute(
        path: RoutePaths.demoDone,
        builder: (context, state) => DemoSuccessScreen(
          title: state.uri.queryParameters['title'] ?? 'Saved',
          detail: state.uri.queryParameters['detail'] ?? '',
        ),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const Scaffold(body: Text('Home')),
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
          ),
        ),
        premiumServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp.router(
        theme: HomiziTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Premium'));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('paywall shows the benefits, both plans, and one back button', (
    tester,
  ) async {
    await _pump(tester, _FakeService());
    expect(find.byKey(const Key('premium-screen')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    for (final benefit in premiumBenefits) {
      expect(find.text(benefit.title), findsOneWidget);
    }
    expect(find.byKey(const Key('premium-plan-monthly')), findsOneWidget);
    expect(find.byKey(const Key('premium-plan-annual')), findsOneWidget);
    expect(find.text('₹99/month'), findsOneWidget);
    expect(find.text('₹799/year'), findsOneWidget);
    expect(find.text('Best value · Save ₹389'), findsOneWidget);
    expect(find.byKey(const Key('premium-sandbox-note')), findsOneWidget);
    // Annual is the default pick.
    expect(find.text('Get Premium · ₹799/year'), findsOneWidget);
  });

  testWidgets('choosing monthly changes the button and buys that plan', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(tester, service);
    await tester.tap(find.byKey(const Key('premium-plan-monthly')));
    await tester.pumpAndSettle();
    expect(find.text('Get Premium · ₹99/month'), findsOneWidget);

    await tester.tap(find.byKey(const Key('premium-subscribe')));
    await tester.pumpAndSettle();

    expect(service.bought, [PremiumPeriod.monthly]);
    expect(find.byKey(const Key('demo-success-screen')), findsOneWidget);
    expect(find.text('Welcome to HOMIZI Premium'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-success-home')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a cancelled checkout stays on the paywall quietly', (
    tester,
  ) async {
    await _pump(tester, _FakeService(outcome: const PremiumCancelled()));
    await tester.tap(find.byKey(const Key('premium-subscribe')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('premium-screen')), findsOneWidget);
    expect(find.byKey(const Key('premium-note')), findsNothing);
    expect(find.byKey(const Key('demo-success-screen')), findsNothing);
  });

  testWidgets('a failed purchase shows the reason and no confirmation', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeService(outcome: const PremiumFailure('Card was declined.')),
    );
    await tester.tap(find.byKey(const Key('premium-subscribe')));
    await tester.pumpAndSettle();
    expect(find.text('Card was declined.'), findsOneWidget);
    expect(find.byKey(const Key('demo-success-screen')), findsNothing);
  });

  testWidgets('an active plan hides the buy button', (tester) async {
    final service = _FakeService();
    await service.purchase(premiumDefaultPlans.last);
    await _pump(tester, service);
    expect(find.byKey(const Key('premium-active')), findsOneWidget);
    expect(find.byKey(const Key('premium-subscribe')), findsNothing);
  });
}
