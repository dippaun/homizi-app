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
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/matching/match_catalog.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';
import 'package:homizi/features/search_properties/search_rank.dart';
import 'package:homizi/features/shell/homizi_nav.dart';

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('best matches swipe capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  testWidgets('best matches swipe screenshots at 390x844', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bandra = demoHomeById('lst_match_bandra')!;
    final powai = demoHomeById('lst_match_powai')!;
    final router = GoRouter(
      initialLocation: RoutePaths.searchMatches,
      routes: [
        GoRoute(
          path: RoutePaths.searchMatches,
          builder: (context, state) => const SearchMatchesScreen(),
        ),
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: RoutePaths.matches,
          builder: (context, state) => const Scaffold(body: Text('matches')),
        ),
        GoRoute(
          path: RoutePaths.saved,
          builder: (context, state) => const Scaffold(body: Text('saved')),
        ),
        GoRoute(
          path: RoutePaths.explore,
          builder: (context, state) => const Scaffold(body: Text('explore')),
        ),
        GoRoute(
          path: RoutePaths.profile,
          builder: (context, state) => const Scaffold(body: Text('profile')),
        ),
      ],
    );
    addTearDown(router.dispose);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
          builder: (context, child) {
            return RepaintBoundary(
              key: const Key('shot-frame'),
              child: Column(
                children: [
                  Expanded(child: child ?? const SizedBox.shrink()),
                  HomiziBottomNav(
                    path: RoutePaths.searchMatches,
                    router: router,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    container = ProviderScope.containerOf(
      tester.element(find.byType(SearchMatchesScreen)),
    );
    RankedHome rank(Listing listing) {
      return RankedHome(
        listing: listing,
        match: scoreListingMatch(
          requirement: const DetailedRequirement(
            city: 'Mumbai',
            localities: ['Bandra West'],
            propertyTypes: ['private_room'],
            budgetMinInr: 18000,
            budgetMaxInr: 28000,
            furnishing: 'furnished',
          ),
          listing: listing,
        ),
      );
    }

    container.read(rankedHomesProvider.notifier).replace([
      rank(bandra),
      rank(powai),
    ]);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();

    Future<void> shoot(String name) async {
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

    await shoot('01-deck');

    final list = find.descendant(
      of: find.byKey(const Key('best-match-card')),
      matching: find.byType(ListView),
    );
    await tester.drag(list, const Offset(0, -280));
    await tester.pumpAndSettle();
    await shoot('02-why-host-nearby');
    await tester.drag(list, const Offset(0, 280));
    await tester.pumpAndSettle();

    Future<void> flash(Offset delta, String name) async {
      final origin = delta.dy == 0
          ? tester.getTopLeft(list) + const Offset(40, 28)
          : tester.getCenter(
              find.byKey(const Key('property-photos-lst_match_bandra')),
            );
      final gesture = await tester.startGesture(origin);
      await gesture.moveBy(delta);
      await tester.pump();
      await shoot(name);
      await gesture.moveBy(Offset(-delta.dx, -delta.dy));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await flash(const Offset(160, 0), '03-interested');
    await flash(const Offset(-160, 0), '04-skip');
    await flash(const Offset(0, -160), '05-later');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    await shoot('06-seen-all');

    container.read(rankedHomesProvider.notifier).replace(const []);
    await tester.pumpAndSettle();
    await shoot('07-empty');
  });
}

Future<void> _loadFonts() {
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
