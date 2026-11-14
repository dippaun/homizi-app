import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/explore/demo_explore_gateway.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_entry.dart';
import 'package:homizi/features/search_properties/search_persist.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';
import 'package:homizi/features/search_properties/search_seed.dart';
import 'package:homizi/features/search_properties/search_store.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';

import '../../fixtures/search_wizard.dart';

class _RoleSession extends SessionController {
  _RoleSession(this.wire);

  final String? wire;

  @override
  SessionState build() {
    final host = wire == 'host' || wire == 'broker';
    return SessionState(
      phase: wire == null ? SessionPhase.signedOut : SessionPhase.ready,
      contact: wire == null ? '' : 'meera@homizi.in',
      role: wire == null
          ? null
          : (host ? AccountRole.host : AccountRole.tenant),
      homiziWire: wire,
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _SeededAccount extends DemoAccountGateway {
  @override
  Future<TenantProfile> loadTenantProfile() async {
    return const TenantProfile(
      preferences: TenantPreferences(
        city: 'Ahmedabad',
        budgetMinInr: 5000,
        budgetMaxInr: 15000,
        propertyTypes: ['2bhk'],
      ),
    );
  }
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets);
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
}

Future<void> _shoot(WidgetTester tester, String name) async {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    return;
  }
  await tester.pump();
  final view = tester.binding.renderViews.single;
  final layer = view.debugLayer;
  if (layer is! OffsetLayer) {
    return;
  }
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  test('a saved search summarizes city, type, and budget', () {
    expect(formatInrCompact(5000), '₹5k');
    expect(formatInrCompact(15000), '₹15k');
    expect(
      propertySearchSummary(
        const PropertySearch(
          propertyKind: PropertyKindChoice.bhk2,
          placeQuery: 'Vastrapur, Ahmedabad',
        ),
      ),
      'Ahmedabad • 2 BHK • ₹5k–15k',
    );
  });

  test('onboarding city, budget, and type seed one saved search', () {
    final seeded = propertySearchSeededFrom(
      tenant: const TenantPreferences(
        city: 'Ahmedabad',
        budgetMinInr: 5000,
        budgetMaxInr: 15000,
        propertyTypes: ['2bhk'],
      ),
    );
    expect(seeded, isNotNull);
    expect(propertySearchSummary(seeded!), 'Ahmedabad • 2 BHK • ₹5k–15k');
    expect(
      propertySearchSeededFrom(personal: const Personalization(city: 'Pune')),
      isNull,
    );
  });

  test(
    'the wizard round-trips through saved_searches without a new column',
    () async {
      final gateway = DemoExploreGateway();
      final store = MemorySearchStore();
      final stored = await persistPropertySearch(
        store: store,
        gateway: gateway,
        draft: const PropertySearch(
          propertyKind: PropertyKindChoice.bhk2,
          placeQuery: 'Ahmedabad',
          useOffice: false,
          usePreferredArea: true,
        ),
      );
      expect(stored.serverId, isNotEmpty);
      final row = (await gateway.savedSearches()).firstWhere(
        (search) => search.rawFilters.containsKey('wizard'),
      );
      expect(row.rawFilters.containsKey('latitude'), isFalse);
      expect(row.rawFilters.containsKey('phone'), isFalse);
      store.saved = null;
      final loaded = await loadEntrySearch(
        store: store,
        gateway: gateway,
        personal: const Personalization(),
        tenant: null,
      );
      expect(loaded?.propertyKind, PropertyKindChoice.bhk2);
      expect(loaded?.serverId, stored.serverId);
      expect(propertySearchSummary(loaded!), 'Ahmedabad • 2 BHK • ₹5k–15k');
    },
  );

  testWidgets('the first search is the wizard and the next opens matches', (
    tester,
  ) async {
    if ((Platform.environment['HOMIZI_CAPTURE_DIR'] ?? '').isNotEmpty) {
      await tester.runAsync(_loadCaptureFonts);
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemorySearchStore();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: RoutePaths.searchStart,
          builder: (context, state) =>
              SearchEntry(editing: state.uri.queryParameters['edit'] == '1'),
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
          sessionProvider.overrideWith(() => _RoleSession('tenant')),
          propertySearchStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    router.go(RoutePaths.searchStart);
    await _until(tester, find.byKey(const Key('search-properties-screen')));
    expect(find.text('Search Properties'), findsWidgets);
    expect(find.text('1. Property Requirements'), findsOneWidget);
    expect(find.text('Continue to Location & Connectivity'), findsOneWidget);
    expect(find.byKey(const Key('search-matches-screen')), findsNothing);
    expect(find.byKey(const Key('search-clear')), findsOneWidget);
    await _shoot(tester, '01-wizard');
    tester.view.physicalSize = const Size(900, 2400);
    await tester.pump();

    await tapSearch(
      tester,
      searchOption('Anything suitable to my budget').first,
    );
    await tapSearch(tester, searchOption('2 BHK'));
    await searchContinue(tester);
    await tester.enterText(
      find.byKey(const Key('search-area-field')),
      'Vastrapur, Ahmedabad',
    );
    await tester.pump();
    await tapSearch(tester, searchOption('Flexible'));
    await searchContinue(tester);
    await tapSearch(tester, searchOption('Any (suitable to my budget)'));
    await searchContinue(tester);
    await tapSearch(tester, searchOption('Anything suitable to my budget'));
    await tapSearch(tester, searchOption('No Preference').first);
    await tapSearch(tester, searchOption('No Preference').last);
    await searchContinue(tester);
    await tapSearch(tester, find.byKey(const Key('search-find-matches')));
    await _until(tester, find.byKey(const Key('search-matches-screen')));

    expect(find.text('Your best matches'), findsOneWidget);
    expect(find.text('Ahmedabad • 2 BHK • ₹5k–15k'), findsOneWidget);
    expect(find.byKey(const Key('search-edit')), findsOneWidget);
    expect(find.byKey(const Key('search-clear')), findsNothing);
    expect(store.saved?.propertyKind, PropertyKindChoice.bhk2);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    await _shoot(tester, '02-results');
    tester.view.physicalSize = const Size(900, 2400);
    await tester.pump();

    router.go(RoutePaths.searchStart);
    await _until(tester, find.byKey(const Key('search-saved-summary')));
    expect(find.byType(SearchPropertiesScreen), findsNothing);
    expect(find.text('Ahmedabad • 2 BHK • ₹5k–15k'), findsOneWidget);
    expect(find.byKey(const Key('search-matches-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-edit')));
    await _until(tester, find.byType(SearchPropertiesScreen));
    expect(find.text('Search Properties'), findsWidgets);
    expect(find.text('2 BHK'), findsWidgets);
    expect(find.textContaining('₹5,000'), findsWidgets);
    expect(find.byKey(const Key('search-clear')), findsOneWidget);
    await tester.tap(find.byKey(const Key('search-step-1')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('search-area-field')))
          .controller!
          .text,
      'Vastrapur, Ahmedabad',
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('search-area-field')));
    await tester.pump();
    await _shoot(tester, '03-edit');
  });

  testWidgets('onboarding preferences skip the wizard', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: RoutePaths.searchStart,
      routes: [
        GoRoute(
          path: RoutePaths.searchStart,
          builder: (context, state) => const SearchEntry(),
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
          sessionProvider.overrideWith(() => _RoleSession('tenant')),
          propertySearchStoreProvider.overrideWithValue(MemorySearchStore()),
          accountGatewayProvider.overrideWithValue(_SeededAccount()),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await _until(tester, find.byKey(const Key('search-saved-summary')));
    expect(find.byType(SearchPropertiesScreen), findsNothing);
    expect(find.text('Ahmedabad • 2 BHK • ₹5k–15k'), findsOneWidget);
  });

  testWidgets(
    'host, broker, roommate, and signed-out users do not see Search',
    (tester) async {
      if ((Platform.environment['HOMIZI_CAPTURE_DIR'] ?? '').isNotEmpty) {
        await tester.runAsync(_loadCaptureFonts);
      }
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pumpRole(String? wire) async {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(wire),
            overrides: [sessionProvider.overrideWith(() => _RoleSession(wire))],
            child: const HomiziApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      Finder searchTab() {
        return find.descendant(
          of: find.byType(GlassyNavigationBar),
          matching: find.text('Search'),
        );
      }

      await pumpRole('host');
      expect(searchTab(), findsNothing);
      expect(find.text('Matches'), findsWidgets);
      await _shoot(tester, '04-host-nav');

      await pumpRole('broker');
      expect(searchTab(), findsNothing);
      expect(find.text('Matches'), findsWidgets);

      await pumpRole('roommate');
      expect(searchTab(), findsNothing);
      expect(find.text('Roommate'), findsWidgets);

      await pumpRole(null);
      expect(find.byKey(const Key('home-screen')), findsOneWidget);
      expect(find.byKey(const Key('home-rentals')), findsOneWidget);
      expect(searchTab(), findsNothing);
      expect(find.text('Priorities'), findsNothing);
      expect(find.text('Search Properties'), findsNothing);
      expect(find.textContaining('% Match'), findsNothing);
      expect(find.byKey(const Key('home-guest-flats')), findsOneWidget);
      GoRouter.of(
        tester.element(find.byKey(const Key('home-screen'))),
      ).go(RoutePaths.searchStart);
      await _until(tester, find.byKey(const Key('search-tenant-prompt')));
      expect(find.byType(SearchPropertiesScreen), findsNothing);
      expect(find.byKey(const Key('search-pick-tenant')), findsOneWidget);
      expect(find.text('Sign in as a tenant'), findsOneWidget);
      await _shoot(tester, '05-tenant-prompt');
    },
  );
}
