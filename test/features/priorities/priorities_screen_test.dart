import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/matching/priority_keys.dart';
import 'package:homizi/features/priorities/priority_routes.dart';
import 'package:homizi/features/priorities/priority_store.dart';
import 'package:homizi/features/roles/role_provider.dart';

void main() {
  test('reorder puts location first', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(priorityStateProvider.notifier)
        .reorder(host: false, oldIndex: 0, newIndex: 1);
    expect(
      container.read(priorityStateProvider).tenantOrder.first,
      PriorityKey.location,
    );
    expect(
      container.read(priorityStateProvider).tenantOrder[1],
      PriorityKey.budget,
    );
  });

  testWidgets('tenant list, drag, save, and back to home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(SavedRanks.clear);

    final router = GoRouter(
      initialLocation: RoutePaths.priorities,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => const Scaffold(body: Text('Home hub')),
        ),
        ...priorityRoutes(),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set My Priorities'), findsOneWidget);
    expect(find.text('Tenant / Flatmate'), findsOneWidget);
    expect(find.text('Budget Range'), findsOneWidget);
    expect(find.text('Location & Workplace'), findsOneWidget);
    expect(find.text('Distance unavailable'), findsOneWidget);
    expect(find.text('Essential Amenities'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('How It Works'), 400);
    expect(find.text('How It Works'), findsOneWidget);
    expect(find.text('Create Your Profile'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('priority-handle-budget')),
      const Offset(0, 280),
    );
    await tester.pumpAndSettle();
    expect(find.text('P1'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('priority-save')));
    await tester.tap(find.byKey(const Key('priority-save')));
    await tester.pumpAndSettle();
    expect(find.text('Priorities saved'), findsOneWidget);
    expect(find.textContaining('saved on this device'), findsOneWidget);
    expect(SavedRanks.tenant, isNotNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Home hub'), findsOneWidget);
  });

  testWidgets('host role shows the owner list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentRoleProvider.overrideWithValue(HomiziRole.host)],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Host / Owner / Property Partner'), findsOneWidget);
    expect(find.text('Property Type & Details'), findsOneWidget);
    expect(find.text('Preferred Tenant Profile'), findsOneWidget);
    expect(find.text('Budget / Expected Rent'), findsOneWidget);
    expect(find.text('Lease Duration'), findsOneWidget);
    expect(find.text('Preferred Lifestyle Match'), findsOneWidget);
    expect(find.text('Budget Range'), findsNothing);
    expect(find.text('Distance unavailable'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('loading, empty, and error states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pump(PriorityPhase phase) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(phase),
          overrides: [
            priorityStateProvider.overrideWith(() => _PhaseController(phase)),
          ],
          child: MaterialApp.router(
            theme: HomiziTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    await pump(PriorityPhase.loading);
    expect(find.byKey(const Key('loading-state')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await pump(PriorityPhase.empty);
    expect(find.byKey(const Key('empty-state')), findsOneWidget);
    await tester.tap(find.text('Use the starting order'));
    await tester.pumpAndSettle();
    expect(find.text('Budget Range'), findsOneWidget);

    await pump(PriorityPhase.error);
    expect(find.byKey(const Key('priority-error')), findsOneWidget);
    expect(find.byKey(const Key('priority-retry')), findsOneWidget);
  });
}

GoRouter _router() {
  return GoRouter(
    initialLocation: RoutePaths.priorities,
    routes: [
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const Scaffold(body: Text('Home hub')),
      ),
      ...priorityRoutes(),
    ],
  );
}

class _PhaseController extends PriorityController {
  _PhaseController(this.phase);

  final PriorityPhase phase;

  @override
  PriorityState build() {
    return PriorityState(
      phase: phase,
      tenantOrder: phase == PriorityPhase.empty
          ? const <PriorityKey>[]
          : tenantPriorityOrder,
      hostOrder: phase == PriorityPhase.empty
          ? const <PriorityKey>[]
          : hostPriorityOrder,
      message: phase == PriorityPhase.error
          ? 'The ranking is saved on this device. It could not sync yet.'
          : '',
    );
  }
}
