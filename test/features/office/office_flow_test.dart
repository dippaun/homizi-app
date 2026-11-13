import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/office/office_location_screen.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';

void main() {
  testWidgets('saving an office keeps the typed place and opens search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memory = MemoryOfficeStore();
    final router = GoRouter(
      initialLocation: RoutePaths.office,
      routes: [
        GoRoute(
          path: RoutePaths.office,
          builder: (context, state) => const OfficeLocationScreen(),
        ),
        GoRoute(
          path: RoutePaths.officeSaved,
          builder: (context, state) => OfficeSavedScreen(
            label: state.uri.queryParameters['label'] ?? '',
            mode: state.uri.queryParameters['mode'] ?? '',
            minutes: state.uri.queryParameters['minutes'] ?? '',
            remote: state.uri.queryParameters['remote'] == '1',
            mapsEnabled: state.uri.queryParameters['maps'] == '1',
          ),
        ),
        GoRoute(
          path: RoutePaths.searchStart,
          builder: (context, state) => const SearchPropertiesScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          officeRepositoryProvider.overrideWithValue(
            OfficeRepository(
              local: memory,
              remote: const SkippingOfficeRemote(),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Your Office Location'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('office-search')),
      'Powai, Mumbai',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('office-use-typed')));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('office-mode-walk')));
    await tester.tap(find.byKey(const Key('office-mode-walk')));
    await tester.ensureVisible(find.byKey(const Key('office-minutes-45')));
    await tester.tap(find.byKey(const Key('office-minutes-45')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('office-save')));
    await tester.tap(find.byKey(const Key('office-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('office-saved-screen')), findsOneWidget);
    expect(find.text('Powai, Mumbai'), findsOneWidget);
    expect(find.text('Walk · 45 min one way'), findsOneWidget);
    expect(find.text(distanceUnavailableLabel), findsOneWidget);
    expect(find.textContaining('this device'), findsOneWidget);
    expect(memory.offices.single.transport, TransportMode.walk);
    expect(memory.offices.single.maxCommuteMinutes, 45);
    expect(memory.offices.single.latitude, isNull);

    await tester.tap(find.byKey(const Key('office-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('search-properties-screen')), findsOneWidget);
    expect(find.text('Occupancy Required'), findsOneWidget);
    expect(find.text('Find My Best Matches'), findsOneWidget);
  });
}
