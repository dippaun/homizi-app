import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('office and search captures stay out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
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

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('capture office and search at 390x844 @2x', (tester) async {
    phone(tester);
    final memory = MemoryOfficeStore();
    final router = GoRouter(
      initialLocation: RoutePaths.office,
      routes: [
        GoRoute(
          path: RoutePaths.office,
          builder: (context, state) => const OfficeLocationScreen(),
        ),
        GoRoute(
          path: RoutePaths.searchStart,
          builder: (context, state) => const SearchPropertiesScreen(),
        ),
        GoRoute(
          path: RoutePaths.searchMatches,
          builder: (context, state) => const SearchMatchesScreen(),
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
          discoveryProvider.overrideWith(_ReadyDiscovery.new),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          routerConfig: router,
          builder: (context, child) {
            return RepaintBoundary(key: const Key('shot-frame'), child: child);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await shoot(tester, 'office-location');

    await tester.enterText(
      find.byKey(const Key('office-search')),
      'Powai, Mumbai',
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pump();
    await tester.tap(find.byKey(const Key('office-mode-public_transport')));
    await tester.tap(find.byKey(const Key('office-minutes-30')));
    await tester.pump();
    await shoot(tester, 'office-location-filled');

    router.go(RoutePaths.searchStart);
    await tester.pump();
    await tester.pump();
    await shoot(tester, 'search-properties');

    await tester.tap(find.byKey(const Key('search-find-matches')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, 'search-matches');
  }, timeout: const Timeout(Duration(seconds: 90)));
}

class _ReadyDiscovery extends DiscoveryController {
  @override
  DiscoveryState build() {
    return const DiscoveryState(listings: DemoCatalog.listings);
  }
}
