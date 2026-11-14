import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/priorities/priority_routes.dart';
import 'package:homizi/features/roles/seeker_matches_screen.dart';
import 'package:homizi/features/seekers/seeker_shortlist.dart';

/// Sample saved preferred tenant profile (test data).
class _SavedHost extends HostTenantPrioritiesController {
  @override
  HostTenantPriorities build() {
    return HostTenantPriorities(
      budgetMinInr: 8000,
      budgetMaxInr: 40000,
      moveInFrom: DateTime(2026, 11),
      moveInTo: DateTime(2027, 2),
      saved: true,
    );
  }
}

Widget _app({required Widget home, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      seekerDeckStoreProvider.overrideWithValue(MemorySeekerDeckStore()),
      ...overrides,
    ],
    child: MaterialApp(theme: HomiziTheme.light(), home: home),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('top match profiles: card % equals profile %, no numbers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        overrides: [hostTenantPrioritiesProvider.overrideWith(_SavedHost.new)],
        home: const SeekerMatchesScreen(
          title: 'Top match profiles',
          topMatches: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Top match profiles'), findsOneWidget);
    expect(find.text('Ranked by your priorities'), findsOneWidget);
    expect(find.byKey(const Key('seeker-tab-top')), findsOneWidget);
    expect(find.byKey(const Key('seeker-tab-other')), findsOneWidget);
    expect(find.byKey(const Key('seekers-set-priorities')), findsNothing);

    var pills = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('seeker-match-'),
    );
    if (pills.evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('seeker-tab-other')));
      await tester.pump();
      pills = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('seeker-match-'),
      );
    }
    expect(pills, findsWidgets);
    final pill = pills.first.evaluate().first.widget;
    final id = (pill.key! as ValueKey<String>).value.substring(
      'seeker-match-'.length,
    );
    final cardText = tester
        .widgetList<Text>(
          find.descendant(of: find.byWidget(pill), matching: find.byType(Text)),
        )
        .first
        .data!;
    final percent = cardText.split('%').first;
    expect(find.textContaining('+91'), findsNothing);

    await tester.tap(find.byKey(Key('seeker-whatsapp-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('seeker-contact-sheet')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('seeker-card-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('seeker-preview')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('seeker-preview-percent'))).data,
      '$percent%',
    );
    expect(find.byKey(const Key('seeker-priority-match')), findsOneWidget);
    expect(find.byKey(const Key('seeker-priority-budget')), findsOneWidget);

    await tester.ensureVisible(find.byKey(Key('seeker-preview-call-$id')));
    await tester.tap(find.byKey(Key('seeker-preview-call-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seeker-contact-chat')));
    await tester.pumpAndSettle();
    expect(find.text('Chat is ready'), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
  });

  testWidgets('without saved priorities the top list asks for them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        home: const SeekerMatchesScreen(
          title: 'Top match profiles',
          topMatches: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('seekers-set-priorities')), findsOneWidget);
  });

  testWidgets('host priorities save to a summary with top matches', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: RoutePaths.hostPriorities,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => const Scaffold(body: Text('Home hub')),
        ),
        GoRoute(
          path: RoutePaths.hostOptions,
          builder: (context, state) => const Scaffold(body: Text('Host hub')),
        ),
        GoRoute(
          path: RoutePaths.hostTopMatches,
          builder: (context, state) => const Scaffold(body: Text('Top list')),
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
    expect(find.text('Preferred tenant profile'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('priority-save')));
    await tester.tap(find.byKey(const Key('priority-save')));
    await tester.pumpAndSettle();
    expect(find.text('Priorities saved'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('priority-see-top-matches')),
    );
    await tester.tap(find.byKey(const Key('priority-see-top-matches')));
    await tester.pumpAndSettle();
    expect(find.text('Top list'), findsOneWidget);
  });
}
