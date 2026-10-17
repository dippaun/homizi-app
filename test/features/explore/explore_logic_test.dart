import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_sort.dart';
import 'package:homizi/features/discovery/domain/locality.dart';
import 'package:homizi/features/explore/demo_explore_gateway.dart';
import 'package:homizi/features/explore/saved_search.dart';
import 'package:homizi/features/explore/tool_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('popular localities stay inside the selected city', () {
    final chennai = popularLocalities(localitySeed, 'Chennai');
    expect(chennai, isNotEmpty);
    expect(chennai.every((place) => place.city == 'Chennai'), isTrue);
    expect(chennai.length, lessThanOrEqualTo(8));
    expect(
      chennai.first.popularity,
      greaterThanOrEqualTo(chennai.last.popularity),
    );

    final typed = filterLocalities(localitySeed, query: 'kora');
    expect(typed.map((place) => place.slug), ['koramangala']);
  });

  test('newest and most viewed change the order', () {
    const older = Listing(
      id: 'old',
      hostUserId: 'host',
      title: 'Older home',
      city: 'Pune',
      locality: 'Baner',
      rentInr: 10000,
      depositInr: 20000,
      furnishing: 'furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Host',
      amenities: [],
      summary: 'Older.',
      publishedAtIso: '2026-01-01T00:00:00Z',
    );
    const newer = Listing(
      id: 'new',
      hostUserId: 'host',
      title: 'Newer home',
      city: 'Pune',
      locality: 'Aundh',
      rentInr: 12000,
      depositInr: 24000,
      furnishing: 'furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Host',
      amenities: [],
      summary: 'Newer.',
      publishedAtIso: '2026-10-01T00:00:00Z',
    );
    const undated = Listing(
      id: 'none',
      hostUserId: 'host',
      title: 'Undated home',
      city: 'Pune',
      locality: 'Kothrud',
      rentInr: 8000,
      depositInr: 16000,
      furnishing: 'furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Host',
      amenities: [],
      summary: 'No date.',
    );
    final newest = sortListings([older, undated, newer], ListingSort.newest);
    expect(newest.map((listing) => listing.id), ['new', 'old', 'none']);

    final viewed = sortListings(
      [older, newer],
      ListingSort.mostViewed,
      viewsToday: const {'old': 4, 'new': 1},
    );
    expect(viewed.first.id, 'old');

    final grouped = groupListingsByLocality([newer, older]);
    expect(grouped.keys.toList(), ['Aundh', 'Baner']);
  });

  test('a view counts once and a photo request is limited', () async {
    final gateway = DemoExploreGateway();
    await gateway.recordListingView('lst_koramangala');
    await gateway.recordListingView('lst_koramangala');
    expect(await gateway.recentlyViewedIds(), ['lst_koramangala']);
    expect(await gateway.viewsToday(['lst_koramangala']), {
      'lst_koramangala': 1,
    });
    expect(await gateway.viewsToday(['lst_hsr']), isEmpty);

    final saved = await gateway.savedSearches();
    expect(saved.single.id, 'saved-koramangala');
    expect(saved.single.newCount, 1);
    expect(newMatchesFor(saved.single, DemoCatalog.listings), 1);

    final first = await gateway.requestPhotos('lst_marathahalli');
    expect(first.ok, isTrue);
    expect(first.message, photoRequestSent);
    final second = await gateway.requestPhotos('lst_marathahalli');
    expect(second.ok, isFalse);
    expect(second.message, photoRequestLimited);
    final enough = await gateway.requestPhotos('lst_koramangala');
    expect(enough.message, photoRequestEnough);
  });

  test('tool links follow routes that exist', () {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(
          path: '/tools/receipts',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(
          path: '/tools/split',
          builder: (context, state) => const SizedBox(),
        ),
      ],
    );
    addTearDown(router.dispose);
    final links = toolLinksIn(router);
    expect(links.map((link) => link.path), ['/tools/receipts', '/tools/split']);
    expect(links.map((link) => link.label), ['Rent receipts', 'Rent split']);

    final empty = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      ],
    );
    addTearDown(empty.dispose);
    expect(toolLinksIn(empty), isEmpty);
  });
}
