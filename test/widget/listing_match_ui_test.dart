import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/listing_card.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'test@homizi.in',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

Future<void> _pump(WidgetTester tester, {Size? size}) async {
  await tester.runAsync(_loadCaptureFonts);
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(_ReadySession.new)],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _loadCaptureFonts() async {
  final sans = FontLoader('PlusJakartaSans');
  for (final name in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();

  final icons = File(_materialIconsPath());
  if (!icons.existsSync()) {
    throw StateError('MaterialIcons font missing at ${icons.path}');
  }
  final material = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
  await material.load();
}

String _materialIconsPath() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    return '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  }
  final cache = File(Platform.resolvedExecutable).parent.parent.parent;
  return '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf';
}

void main() {
  test('freshness uses today, the day and month, or a previous year', () {
    final today = DateTime(2026, 10, 20, 15, 30);
    expect(
      listedOnLabel(DateTime(2026, 10, 20, 1), now: today),
      'Listed today',
    );
    expect(listedOnLabel(DateTime(2026, 10, 12), now: today), 'Listed 12 Oct');
    expect(
      listedOnLabel(DateTime(2025, 10, 12), now: today),
      'Listed 12 Oct 2025',
    );
    expect(listedOnLabel(null, now: today), isNull);
    expect(mediaCountLabel(0), '0 photos');
    expect(mediaCountLabel(3), '3 photos');
  });

  testWidgets('the listing card shows match, rent, and interested', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final listing = DemoCatalog.listings.firstWhere(
      (item) => item.id == 'lst_koramangala',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [ListingCard(listing: listing)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('100% Match'), findsOneWidget);
    expect(find.text('₹22,000/mo'), findsOneWidget);
    expect(find.text('Deposit ₹80,000'), findsOneWidget);
    expect(find.text('2 BHK · Furnished'), findsOneWidget);
    expect(find.textContaining('Koramangala'), findsWidgets);
    expect(find.text('About 6 km'), findsNothing);
    expect(find.textContaining('About 6 km'), findsOneWidget);
    expect(find.text('Verified'), findsWidgets);
    expect(find.text('Verified listing'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('Interested'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('${listing.photoCount} photos'), findsOneWidget);
    final listed = listedOnLabel(listing.publishedAt);
    expect(listed, isNotNull);
    expect(find.text(listed!), findsOneWidget);
    expect(
      find.byKey(const Key('listing-photos-lst_koramangala')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('listing-listed-lst_koramangala')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('match-badge-lst_koramangala')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('match-breakdown')), findsOneWidget);
    expect(find.byIcon(Icons.check), findsWidgets);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Rent sits inside your budget.'), findsOneWidget);
  });

  testWidgets('the card uses photoCount and says listed today', (tester) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    const sample = Listing(
      id: 'lst_today',
      hostUserId: 'host',
      title: '1 BHK in Kothrud',
      city: 'Pune',
      locality: 'Kothrud',
      rentInr: 14000,
      depositInr: 28000,
      furnishing: 'semi_furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Asha P.',
      hostKind: 'Owner',
      amenities: ['Lift'],
      summary: 'A home in Kothrud.',
      photoAssets: ['assets/photos/living_01.webp'],
      photoCountOverride: 7,
    );
    final today = Listing(
      id: sample.id,
      hostUserId: sample.hostUserId,
      title: sample.title,
      city: sample.city,
      locality: sample.locality,
      rentInr: sample.rentInr,
      depositInr: sample.depositInr,
      furnishing: sample.furnishing,
      propertyType: sample.propertyType,
      hostDisplayName: sample.hostDisplayName,
      hostKind: sample.hostKind,
      amenities: sample.amenities,
      summary: sample.summary,
      photoAssets: sample.photoAssets,
      photoCountOverride: sample.photoCountOverride,
      publishedAtIso: now.toIso8601String(),
    );
    const undated = Listing(
      id: 'lst_undated',
      hostUserId: 'host',
      title: 'Room in Aundh',
      city: 'Pune',
      locality: 'Aundh',
      rentInr: 9000,
      depositInr: 18000,
      furnishing: 'unfurnished',
      propertyType: 'private_room',
      hostDisplayName: 'Host',
      amenities: [],
      summary: 'A room.',
      photoCountOverride: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListingCard(listing: today),
                const SizedBox(height: 16),
                const ListingCard(listing: undated),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('7 photos'), findsOneWidget);
    expect(find.text('1 photos'), findsNothing);
    expect(find.text('Listed today'), findsOneWidget);
    expect(find.text('₹14,000/mo'), findsOneWidget);
    expect(find.textContaining('Kothrud, Pune'), findsOneWidget);
    expect(find.text('0 photos'), findsOneWidget);
    expect(find.byKey(const Key('listing-listed-lst_undated')), findsNothing);
    expect(find.byTooltip('Save'), findsWidgets);
  });

  testWidgets('home has best matches and no recent searches or areas', (
    tester,
  ) async {
    await _pump(tester, size: const Size(390, 1400));
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.text('Recent searches'), findsNothing);
    expect(find.text('Recent areas'), findsNothing);
    expect(find.byKey(const Key('home-best-matches')), findsOneWidget);
    expect(find.text('Best matches for you'), findsOneWidget);
    expect(find.text('100% Match'), findsWidgets);
  });

  testWidgets('recent searches appear only inside the search bar', (
    tester,
  ) async {
    await _pump(tester, size: const Size(390, 900));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Explore'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Recent searches'), findsNothing);
    expect(find.text('Recent areas'), findsNothing);
    expect(find.byKey(const Key('best-matches-section')), findsOneWidget);

    await tester.tap(find.byType(SearchBar));
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(
      find.byKey(const Key('recent-search-recent-koramangala')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('clear-recent-searches')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-recent-searches')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('recent-search-recent-koramangala')),
      findsNothing,
    );
  });
}
