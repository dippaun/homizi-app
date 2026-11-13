import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/office/office_location_screen.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';
import 'package:homizi/features/search_properties/search_rank.dart';

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('office and search captures stay out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  Future<void> loadFonts() {
    final jakarta = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-ExtraBold.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    return Future.wait([jakarta.load(), inter.load()]);
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('shot-frame')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Finder verticalList() {
    return find.byWidgetPredicate(
      (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    for (var attempt = 0; attempt < 16; attempt++) {
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target);
        await settle(tester);
        return;
      }
      final lists = verticalList();
      if (lists.evaluate().isEmpty) {
        break;
      }
      await tester.drag(lists, const Offset(0, -280));
      await tester.pump();
    }
    await tester.ensureVisible(target);
    await settle(tester);
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app({
    required GoRouter router,
    required OfficeRepository offices,
    required DiscoveryController Function() discovery,
  }) {
    return ProviderScope(
      overrides: [
        officeRepositoryProvider.overrideWithValue(offices),
        discoveryProvider.overrideWith(discovery),
      ],
      child: MaterialApp.router(
        key: ValueKey(router),
        debugShowCheckedModeBanner: false,
        theme: HomiziTheme.light(),
        routerConfig: router,
        builder: (context, child) {
          return RepaintBoundary(key: const Key('shot-frame'), child: child);
        },
      ),
    );
  }

  List<RouteBase> routes() {
    return [
      GoRoute(
        path: RoutePaths.office,
        builder: (context, state) => const OfficeLocationScreen(),
      ),
      GoRoute(
        path: RoutePaths.officeSaved,
        builder: (context, state) => OfficeSavedScreen(
          label: state.uri.queryParameters['label'] ?? 'Office',
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
      GoRoute(
        path: RoutePaths.searchMatches,
        builder: (context, state) => const SearchMatchesScreen(),
      ),
    ];
  }

  testWidgets(
    'capture office and search at 390x844 @2x',
    (tester) async {
      phone(tester);
      await tester.runAsync(loadFonts);
      final memory = MemoryOfficeStore();
      final router = GoRouter(
        initialLocation: RoutePaths.office,
        routes: routes(),
      );
      addTearDown(router.dispose);
      final offices = OfficeRepository(
        local: memory,
        remote: const SkippingOfficeRemote(),
      );

      await tester.pumpWidget(
        app(router: router, offices: offices, discovery: _ReadyDiscovery.new),
      );
      await tester.pump();
      await tester.pump();
      await shoot(tester, 'office-location');

      await tester.enterText(
        find.byKey(const Key('office-search')),
        'Powai, Mumbai',
      );
      await tester.pump();
      expect(find.byKey(const Key('office-use-typed')), findsOneWidget);
      await shoot(tester, 'office-autocomplete');

      await tester.pump(const Duration(milliseconds: 300));
      await reveal(
        tester,
        find.byKey(const Key('office-mode-public_transport')),
      );
      await tester.tap(find.byKey(const Key('office-mode-public_transport')));
      await settle(tester);
      await shoot(tester, 'office-transport');

      await reveal(tester, find.byKey(const Key('office-minutes-15')));
      await tester.tap(find.byKey(const Key('office-minutes-45')));
      await settle(tester);
      await shoot(tester, 'office-minutes');

      await tester.tap(find.byKey(const Key('office-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('office-saved-screen')), findsOneWidget);
      await shoot(tester, 'office-saved');

      await tester.tap(find.text('Add another office'));
      await tester.pump();
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('office-search')),
        'Andheri East, Mumbai',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('office-use-typed')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('office-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Add another office'));
      await tester.pump();
      await tester.pump();
      await reveal(tester, find.text('Powai, Mumbai'));
      expect(find.text('Andheri East, Mumbai'), findsWidgets);
      expect(find.text('Powai, Mumbai'), findsWidgets);
      await shoot(tester, 'office-multiple');

      router.go(RoutePaths.searchStart);
      await tester.pump();
      await tester.pump();
      await shoot(tester, 'search-progress');

      const sections = <(String, String)>[
        ('Occupancy Required', 'search-01-occupancy'),
        ('Property Type', 'search-02-property-type'),
        ('Monthly Budget', 'search-03-budget'),
        ('Preferred Location & Workplace', 'search-04-location'),
        ('Possession Required From', 'search-05-possession'),
        ('Flatmate / Roommate Gender Preference', 'search-06-gender'),
        ('Lifestyle Preference', 'search-07-lifestyle'),
        ('Furnishing Preference', 'search-08-furnishing'),
        ('Bathroom Preference', 'search-09-bathroom'),
        ('Essential Amenities', 'search-10-amenities'),
        ('Property Rules & Restrictions', 'search-11-rules'),
        ('Suitable For', 'search-12-suitable'),
      ];
      for (final (title, name) in sections) {
        await reveal(tester, find.text(title));
        await shoot(tester, name);
      }

      final progress = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal,
      );
      await tester.drag(progress, const Offset(-360, 0));
      await tester.pump();
      await tester.tap(find.byKey(const Key('search-step-4')));
      await settle(tester);
      await tester.drag(verticalList(), const Offset(0, -80));
      await settle(tester);
      await shoot(tester, 'search-progress-confirm');

      await tester.ensureVisible(find.byKey(const Key('search-find-matches')));
      await tester.tap(find.byKey(const Key('search-find-matches')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Distance unavailable'), findsWidgets);
      await shoot(tester, 'search-matches');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchMatchesScreen)),
      );
      container.read(rankedHomesProvider.notifier).replace(const []);
      await tester.pump();
      expect(find.text('No homes in this search'), findsOneWidget);
      await shoot(tester, 'search-matches-empty');

      final slow = GoRouter(
        initialLocation: RoutePaths.searchStart,
        routes: routes(),
      );
      addTearDown(slow.dispose);
      await tester.pumpWidget(
        app(router: slow, offices: offices, discovery: _SlowDiscovery.new),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('search-find-matches')));
      await tester.pump();
      expect(find.text('Finding homes'), findsOneWidget);
      await shoot(tester, 'search-loading');
      await tester.pump(const Duration(seconds: 1));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets('capture the search error state', (tester) async {
    phone(tester);
    await tester.runAsync(loadFonts);
    final router = GoRouter(
      initialLocation: RoutePaths.searchStart,
      routes: routes(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      app(
        router: router,
        offices: OfficeRepository(
          local: MemoryOfficeStore(),
          remote: const SkippingOfficeRemote(),
        ),
        discovery: _ErrorDiscovery.new,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('search-find-matches')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Homes could not be loaded. Try again.'), findsOneWidget);
    await shoot(tester, 'search-error');
  });
}

class _ReadyDiscovery extends DiscoveryController {
  @override
  DiscoveryState build() {
    return const DiscoveryState(listings: DemoCatalog.listings);
  }
}

class _SlowDiscovery extends DiscoveryController {
  @override
  DiscoveryState build() => const DiscoveryState(loading: true);

  @override
  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    state = const DiscoveryState(listings: DemoCatalog.listings);
  }
}

class _ErrorDiscovery extends DiscoveryController {
  @override
  DiscoveryState build() {
    return const DiscoveryState(error: 'Could not load homes.');
  }

  @override
  Future<void> refresh() async {
    state = const DiscoveryState(error: 'Could not load homes.');
  }
}
