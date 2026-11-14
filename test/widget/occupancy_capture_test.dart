import 'dart:async';
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
import 'package:homizi/features/owner/owner_dashboard_screen.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/roommates/shared_rooms_screen.dart';
import 'package:homizi/features/shared_home/occupancy_search_screen.dart';
import 'package:homizi/features/shared_home/shared_home_catalog.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/shared_home/shared_home_repository.dart';
import 'package:homizi/features/shared_home/shared_home_routes.dart';
import 'package:homizi/features/tools/split_screen.dart';
import 'package:homizi/l10n/app_localizations.dart';

/// Writes 390x844 (DPR 2) screenshots of occupancy matching and shared
/// homes when HOMIZI_CAPTURE_DIR is set. CI skips it.
void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('occupancy capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  setUpAll(_loadCaptureFonts);

  Future<void> precache(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await precache(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('shot-frame')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/occupancy-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Finder list() => find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .last;

  Future<void> top(WidgetTester tester) async {
    if (find.byType(Scrollable).evaluate().isEmpty) return;
    tester.state<ScrollableState>(list()).position.jumpTo(0);
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    if (finder.evaluate().isEmpty) {
      await top(tester);
    }
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 300, scrollable: list());
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await reveal(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await top(tester);
  }

  Future<GoRouter> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 1688);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: RoutePaths.flatmateRooms,
          builder: (context, state) => SharedRoomsScreen(
            entry: state.uri.queryParameters['entry'] == 'occupancy'
                ? OccupancyEntry.occupancy
                : OccupancyEntry.roomie,
          ),
        ),
        GoRoute(
          path: RoutePaths.rentSplit,
          builder: (context, state) => SplitScreen(
            roommates: splitRoommatesFromQuery(
              state.uri.queryParameters['with'],
            ),
            initialBhk: state.uri.queryParameters['bhk'],
            initialLocality: state.uri.queryParameters['place'],
            initialRentInr: int.tryParse(
              state.uri.queryParameters['rent'] ?? '',
            ),
          ),
        ),
        ...sharedHomeRoutes(),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedHomeRepositoryProvider.overrideWithValue(
            SharedHomeRepository(
              local: MemorySharedHomeLocal(),
              remote: const SkippingSharedHomeRemote(),
            ),
          ),
          ownerListingsProvider.overrideWith(
            (ref) async => const [
              OwnerListing(
                id: 'l1',
                title: '3 BHK in Andheri East',
                locality: 'Andheri East',
                city: 'Mumbai',
                rentInr: 36000,
                status: 'published',
                chip: 'live',
                views: 0,
                saves: 0,
                interests: 0,
                visitRequests: 0,
              ),
            ],
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: _captureTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) =>
              RepaintBoundary(key: const Key('shot-frame'), child: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> go(WidgetTester tester, GoRouter router, String path) async {
    unawaited(router.push(path));
    await tester.pumpAndSettle();
  }

  const andheri = '${sampleSharedHomePrefix}andheri-3bhk';

  testWidgets('occupancy matching flow', (tester) async {
    final router = await pump(tester);
    await go(tester, router, SharedHomePaths.search);
    await shoot(tester, '01-search');
    await reveal(tester, 'occ-find');
    await shoot(tester, '02-search-preferences');
    await reveal(tester, 'occ-how');
    await shoot(tester, '03-how-it-works');
    await tap(tester, 'occ-find');
    await shoot(tester, '04-matching-homes');
    await tap(tester, 'shared-room-$andheri');
    await shoot(tester, '05-home-details');
    await reveal(tester, 'shared-request-join');
    await shoot(tester, '06-home-housemate');
    await tap(tester, 'shared-request-join');
    await shoot(tester, '07-choose-match');
    await tap(tester, 'join-continue');
    await shoot(tester, '08-send-request');
    await tap(tester, 'join-send');
    await shoot(tester, '09-request-sent');
    await tap(tester, 'join-sample-reply');
    await shoot(tester, '10-accepted');
    await tap(tester, 'join-continue-home');
    await shoot(tester, '11-your-shared-home');
    await tap(tester, 'join-move-in');
    await shoot(tester, '12-moved-in');
    await tap(tester, 'join-split-after');
    await shoot(tester, '13-rent-split-prefilled');
  });

  testWidgets('group search', (tester) async {
    final router = await pump(tester);
    await go(tester, router, '${SharedHomePaths.search}?mode=group');
    await tap(tester, 'occ-occupancy-double');
    await shoot(tester, '14-group-search');
    await tap(tester, 'occ-find');
    await shoot(tester, '15-group-results');
  });

  testWidgets('find your roomie', (tester) async {
    final router = await pump(tester);
    await go(tester, router, SharedHomePaths.roomie);
    await shoot(tester, '16-roomie-prefs');
    await reveal(tester, 'roomie-find');
    await shoot(tester, '17-roomie-prefs-more');
    await tap(tester, 'roomie-find');
    await shoot(tester, '18-room-options');
    await tap(tester, 'shared-tab-roomies');
    await shoot(tester, '19-new-roomies');
  });

  testWidgets('host posts a shared home', (tester) async {
    final router = await pump(tester);
    await go(tester, router, SharedHomePaths.host);
    await shoot(tester, '20-host-form');
    await tester.enterText(find.byKey(const Key('host-mate-name')), 'Rohit');
    await tester.pumpAndSettle();
    await reveal(tester, 'host-example');
    await shoot(tester, '21-host-form-housemate');
    await tap(tester, 'host-save');
    await shoot(tester, '22-host-saved');
    await tap(tester, 'host-see-requests');
    await shoot(tester, '23-host-requests');
  });
}

/// Inter has no ₹ glyph; the browser falls back on the web, the test
/// renderer does not, so fall back to Plus Jakarta Sans here.
ThemeData _captureTheme() {
  final base = HomiziTheme.light();
  const fallback = ['PlusJakartaSans'];
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fallback),
  );
}

Future<void> _loadCaptureFonts() async {
  final sans = FontLoader('PlusJakartaSans');
  for (final name in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();
  final inter = FontLoader('Inter');
  for (final name in const [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    inter.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await inter.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final path = root != null && root.isNotEmpty
      ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
      : '${Platform.resolvedExecutable}/../../../artifacts/material_fonts/MaterialIcons-Regular.otf';
  final material = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(ByteData.sublistView(await File(path).readAsBytes())),
    );
  await material.load();
}
