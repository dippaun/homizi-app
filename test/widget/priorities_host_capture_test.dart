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
import 'package:homizi/features/host/host_options_screen.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/priorities/priority_routes.dart';
import 'package:homizi/features/roles/seeker_matches_screen.dart';
import 'package:homizi/features/seekers/seeker_preview_screen.dart';
import 'package:homizi/features/seekers/seeker_shortlist.dart';
import 'package:homizi/l10n/app_localizations.dart';

/// Writes 390x844 (DPR 2) screenshots of Set My Priorities and the host
/// journey when HOMIZI_CAPTURE_DIR is set. CI skips it.
void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('priorities capture stays out of CI', () {
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
    await precache(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('shot-frame')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/priorities-host-$name.png');
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
          path: RoutePaths.hostOptions,
          builder: (context, state) => const HostOptionsScreen(),
        ),
        GoRoute(
          path: RoutePaths.hostTopMatches,
          builder: (context, state) => const SeekerMatchesScreen(
            title: 'Top match profiles',
            topMatches: true,
          ),
        ),
        GoRoute(
          path: '/seekers/preview/:id',
          builder: (context, state) {
            final extra = state.extra;
            return SeekerPreviewScreen(
              requirementId: state.pathParameters['id'] ?? '',
              args: extra is SeekerPreviewArgs ? extra : null,
            );
          },
        ),
        ...priorityRoutes(),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seekerDeckStoreProvider.overrideWithValue(MemorySeekerDeckStore()),
          // Capture data: a home this host has just published.
          demoListingMemoryProvider.overrideWithValue(
            DemoListingMemory(
              seed: [
                DemoOwnedHome(
                  draft: const ListingDraft(
                    id: 'capture-andheri-2bhk',
                    title: '2 BHK Apartment',
                    city: 'Mumbai',
                    locality: 'Andheri East',
                    rentText: '55000',
                    depositText: '165000',
                    occupancy: 2,
                  ),
                  status: 'published',
                  days: const [],
                ),
              ],
            ),
          ),
          priorityRepositoryProvider.overrideWithValue(
            PriorityRepository(
              local: MemoryPriorityLocal(),
              remote: const SkippingPriorityRemote(),
            ),
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

  Future<void> settleIo(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tenant priorities', (tester) async {
    final router = await pump(tester);
    await go(tester, router, RoutePaths.priorities);
    await settleIo(tester);
    await shoot(tester, '01-tenant-priorities');
    await tap(tester, 'priority-row-budget');
    await shoot(tester, '02-edit-budget');
    await tester.tapAt(const Offset(195, 60));
    await tester.pumpAndSettle();
    await reveal(tester, 'priority-add-more');
    await shoot(tester, '03-add-more-type');
    await tap(tester, 'priority-add-more');
    await shoot(tester, '04-add-more-sheet');
    await tester.tapAt(const Offset(195, 60));
    await tester.pumpAndSettle();
    await reveal(tester, 'how-it-works');
    await shoot(tester, '05-how-it-works');
    await tap(tester, 'priority-tab-lifestyle');
    await shoot(tester, '06-lifestyle-tab');
    await tap(tester, 'priority-tab-ranks');
    await tap(tester, 'priority-save');
    await settleIo(tester);
    await shoot(tester, '07-tenant-summary');
    await reveal(tester, 'priority-better-matches');
    await shoot(tester, '08-better-matches');
    await reveal(tester, 'priority-find-matches');
    await shoot(tester, '09-match-preview');
  });

  testWidgets('host journey', (tester) async {
    final router = await pump(tester);
    await go(tester, router, RoutePaths.hostOptions);
    await shoot(tester, '10-host-journey');
    await reveal(tester, 'host-why-better');
    await shoot(tester, '11-host-journey-more');
    await tap(tester, 'host-set-priorities');
    await shoot(tester, '12-host-priorities');
    await tap(tester, 'priority-row-gender_age');
    await shoot(tester, '13-host-edit-gender-age');
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    await reveal(tester, 'priority-save');
    await shoot(tester, '14-host-priorities-more');
    await tap(tester, 'priority-save');
    await shoot(tester, '15-host-saved');
    await tap(tester, 'priority-see-top-matches');
    await shoot(tester, '16-top-matches');
    await tap(tester, 'seeker-tab-other');
    await shoot(tester, '17-other-profiles');
    await tap(tester, 'seeker-tab-top');
    final card = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('seeker-whatsapp-'),
    );
    await tester.tap(card.first);
    await tester.pumpAndSettle();
    await shoot(tester, '18-contact-hidden');
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    final open = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('seeker-card-'),
    );
    await tester.tap(open.first);
    await tester.pumpAndSettle();
    await shoot(tester, '19-profile-details');
    await reveal(tester, 'seeker-priority-match');
    await shoot(tester, '20-top5-priority-match');
  });
}

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
