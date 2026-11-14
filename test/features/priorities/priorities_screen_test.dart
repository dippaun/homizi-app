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
    expect(find.byKey(const Key('priority-drag-hint')), findsOneWidget);
    for (final wire in [
      'budget',
      'location',
      'occupancy',
      'property_type',
      'move_in',
    ]) {
      expect(find.byKey(Key('priority-row-$wire')), findsOneWidget);
    }
    expect(find.text('P1'), findsOneWidget);
    expect(find.text('P5'), findsOneWidget);
    expect(find.text('P6'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('priority-handle-budget')),
      const Offset(0, 280),
    );
    await tester.pumpAndSettle();
    expect(find.text('P1'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('how-it-works')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('How It Works'), findsOneWidget);
    expect(find.byKey(const Key('priority-type-explainer')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('priority-save')));
    await tester.tap(find.byKey(const Key('priority-save')));
    await tester.pumpAndSettle();
    expect(find.text('Priorities saved'), findsOneWidget);
    expect(find.textContaining('saved on this device'), findsOneWidget);
    expect(SavedRanks.tenant, isNotNull);
    expect(find.byKey(const Key('priority-readiness')), findsOneWidget);
    expect(find.byKey(const Key('priority-summary-budget')), findsOneWidget);

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

    expect(find.text('Preferred tenant profile'), findsOneWidget);
    expect(find.byKey(const Key('priority-host-property')), findsOneWidget);
    expect(find.byKey(const Key('priority-list-host')), findsOneWidget);
    expect(find.byKey(const Key('priority-row-budget')), findsOneWidget);
    expect(
      find.byKey(const Key('priority-row-working_professional')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('priority-row-location')), findsNothing);
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
    expect(find.byKey(const Key('priority-row-budget')), findsOneWidget);

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
