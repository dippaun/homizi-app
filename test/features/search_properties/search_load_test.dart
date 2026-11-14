import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';

import '../../fixtures/search_wizard.dart';

/// What the live Supabase gateway does with no session: every read throws
/// before any query, because `properties` has no anon read.
class _SignedOutSupabase implements DiscoveryGateway {
  var loads = 0;

  Never _signIn() =>
      throw const DiscoveryFailure('Sign in before browsing homes.');

  @override
  DiscoveryState? get cachedOrNull => null;

  @override
  Future<DiscoveryState> load() async {
    loads++;
    _signIn();
  }

  @override
  Future<List<Listing>> searchListings(ListingFilters filters) async =>
      _signIn();

  @override
  Future<PreciseAddress> preciseAddress(String propertyId) async => _signIn();

  @override
  Future<String> likeListing(Listing listing) async => _signIn();

  @override
  Future<String> passListing(Listing listing) async => _signIn();

  @override
  Future<String> undoListing(Listing listing) async => _signIn();

  @override
  Future<String> saveListing(Listing listing) async => _signIn();

  @override
  Future<String> unsaveListing(String listingId) async => _signIn();

  @override
  Future<String> shareOwnContact(String matchId, String scope) async =>
      _signIn();

  @override
  Future<String> stopSharingOwnContact(String matchId) async => _signIn();
}

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: Text('home')),
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

Future<void> _findHomes(WidgetTester tester, DiscoveryGateway gateway) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [discoveryGatewayProvider.overrideWithValue(gateway)],
  );
  addTearDown(container.dispose);
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: HomiziTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  unawaited(router.push(RoutePaths.searchStart));
  await tester.pumpAndSettle();
  await completeSearchWizard(tester);
  await tapSearch(tester, find.byKey(const Key('search-find-matches')));
  await tester.pumpAndSettle();
}

void main() {
  test('a guest load used to fail and now returns the sample homes', () async {
    final remote = _SignedOutSupabase();
    final bare = ProviderContainer(
      overrides: [discoveryGatewayProvider.overrideWithValue(remote)],
    );
    addTearDown(bare.dispose);
    await bare.read(discoveryProvider.notifier).refresh();
    expect(
      bare.read(discoveryProvider).error,
      'Sign in before browsing homes.',
    );
    expect(bare.read(discoveryProvider).listings, isEmpty);

    final guest = GuestBrowseDiscovery(
      remote,
      DemoDiscoveryGateway(),
      signedIn: () => false,
    );
    final fixed = ProviderContainer(
      overrides: [discoveryGatewayProvider.overrideWithValue(guest)],
    );
    addTearDown(fixed.dispose);
    await fixed.read(discoveryProvider.notifier).refresh();
    expect(fixed.read(discoveryProvider).error, isNull);
    expect(fixed.read(discoveryProvider).listings, isNotEmpty);
    expect(
      await guest.searchListings(const ListingFilters(city: 'Ahmedabad')),
      isNotEmpty,
    );
  });

  test('a signed-in person always reads Supabase', () async {
    final remote = _SignedOutSupabase();
    final gateway = GuestBrowseDiscovery(
      remote,
      DemoDiscoveryGateway(),
      signedIn: () => true,
    );
    await expectLater(gateway.load(), throwsA(isA<DiscoveryFailure>()));
    expect(remote.loads, 1);
  });

  testWidgets('the old gateway shows "Homes could not be loaded"', (
    tester,
  ) async {
    await _findHomes(tester, _SignedOutSupabase());
    expect(find.byKey(const Key('search-error')), findsOneWidget);
    expect(find.textContaining('Homes could not be loaded'), findsOneWidget);
    expect(find.byKey(const Key('search-matches-screen')), findsNothing);
  });

  testWidgets('a guest finishing the wizard sees matching homes', (
    tester,
  ) async {
    await _findHomes(
      tester,
      GuestBrowseDiscovery(
        _SignedOutSupabase(),
        DemoDiscoveryGateway(),
        signedIn: () => false,
      ),
    );
    expect(find.byKey(const Key('search-error')), findsNothing);
    expect(find.byKey(const Key('search-matches-screen')), findsOneWidget);
    expect(find.byKey(const Key('search-saved-count')), findsOneWidget);
    expect(find.text('No homes in this search'), findsNothing);
    expect(find.byKey(const Key('search-guest-note')), findsOneWidget);
  });
}
