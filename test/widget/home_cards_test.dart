import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/post_property/post_property_chooser_screen.dart';
import 'package:homizi/features/profile_create/profile_create_screen.dart';
import 'package:homizi/features/roommates/roommate_screen.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';

class _SignedOut extends SessionController {
  @override
  SessionState build() => const SessionState(phase: SessionPhase.signedOut);
}

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya@example.test',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

Future<GoRouter> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(_ReadySession.new)],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.byKey(const Key('home-screen')), findsOneWidget);
  return GoRouter.of(tester.element(find.byKey(const Key('home-screen'))));
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(
  WidgetTester tester,
  GoRouter router,
  Key key,
  Finder arrived,
  String path,
) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
  await _until(tester, arrived);
  expect(arrived, findsWidgets);
  expect(GoRouter.of(tester.element(arrived.first)).state.uri.path, path);
  router.go(RoutePaths.home);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.byKey(const Key('home-screen')), findsOneWidget);
}

void main() {
  testWidgets('the four home cards open tenant, owner, roomie, and broker', (
    tester,
  ) async {
    final router = await _pumpHome(tester);

    expect(find.text('Find a place.'), findsOneWidget);
    expect(find.text('Find your people.'), findsOneWidget);
    expect(find.text('Rent smarter, live better.'), findsOneWidget);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Create Your Profile'), findsWidgets);
    expect(find.text('Search Properties'), findsOneWidget);
    expect(find.text('Post Your Property'), findsOneWidget);
    expect(find.text('Find Your Roomie'), findsOneWidget);

    await _open(
      tester,
      router,
      const Key('home-card-profile'),
      find.byType(ProfileCreateScreen),
      RoutePaths.profileCreate,
    );
    await _open(
      tester,
      router,
      const Key('home-card-search'),
      find.byType(SearchPropertiesScreen),
      RoutePaths.searchStart,
    );
    await _open(
      tester,
      router,
      const Key('home-card-post'),
      find.byType(PostPropertyChooserScreen),
      RoutePaths.postProperty,
    );
    await _open(
      tester,
      router,
      const Key('home-card-roomie'),
      find.byType(RoommateScreen),
      RoutePaths.roommate,
    );
  });

  testWidgets('search leaves the landing and shows the tenant bar', (
    tester,
  ) async {
    final router = await _pumpHome(tester);
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      0,
    );

    await tester.tap(find.byKey(const Key('home-card-search')));
    await _until(tester, find.byType(SearchPropertiesScreen));
    expect(find.byType(SearchPropertiesScreen), findsOneWidget);
    final bar = tester.widget<GlassyNavigationBar>(
      find.byType(GlassyNavigationBar),
    );
    expect(bar.selectedIndex, 1);
    expect(
      [for (final destination in bar.destinations) destination.label],
      ['Home', 'Search', 'Priorities', 'Roommate', 'Chat', 'Profile'],
    );
    expect(find.text('Payments'), findsNothing);

    router.go(RoutePaths.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      0,
    );
  });

  testWidgets('visitors browse rentals before they register', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_SignedOut.new)],
        child: const HomiziApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.text('Why Homizi'), findsNothing);
    expect(find.byKey(const Key('home-rentals')), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('home-see-all')));
    await tester.tap(find.byKey(const Key('home-see-all')));
    await _until(tester, find.byKey(const Key('group-by-locality')));

    expect(find.byKey(const Key('group-by-locality')), findsOneWidget);
    expect(
      GoRouter.of(
        tester.element(find.byKey(const Key('group-by-locality'))),
      ).state.uri.path,
      RoutePaths.explore,
    );
    expect(find.byKey(const Key('search-properties-screen')), findsNothing);
  });
}
