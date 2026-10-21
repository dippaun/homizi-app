import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/discovery/explore_screen.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';
import 'package:homizi/features/payments/payments_screen.dart';
import 'package:homizi/features/profile/profile_hub_screen.dart';
import 'package:homizi/features/roommates/roommate_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/tenant/tenant_search_screen.dart';

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
  return GoRouter.of(tester.element(find.byType(NavigationBar)));
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(arrived, findsWidgets);
  expect(GoRouter.of(tester.element(arrived.first)).state.uri.path, path);
  router.go(RoutePaths.home);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.byKey(const Key('home-screen')), findsOneWidget);
}

void main() {
  testWidgets('the four home cards open profile, search, listing, and roomie', (
    tester,
  ) async {
    final router = await _pumpHome(tester);

    expect(find.text('Find a place.'), findsOneWidget);
    expect(find.text('Find your people.'), findsOneWidget);
    expect(find.text('Rent smarter, live better.'), findsOneWidget);
    expect(find.text('Create Your Profile'), findsOneWidget);
    expect(find.text('Search Properties'), findsOneWidget);
    expect(find.text('Post Your Property'), findsOneWidget);
    expect(find.text('Find Your Roomie'), findsOneWidget);

    await _open(
      tester,
      router,
      const Key('home-card-profile'),
      find.byKey(const Key('profile-create-screen')),
      RoutePaths.profileCreate,
    );
    await _open(
      tester,
      router,
      const Key('home-card-search'),
      find.byType(TenantSearchScreen),
      RoutePaths.tenantSearch,
    );
    await _open(
      tester,
      router,
      const Key('home-card-post'),
      find.byType(ListingEditorScreen),
      RoutePaths.listingEditor,
    );
    await _open(
      tester,
      router,
      const Key('home-card-roomie'),
      find.byType(RoommateScreen),
      RoutePaths.roomie,
    );
  });

  testWidgets('search, payments, and profile tabs leave the landing', (
    tester,
  ) async {
    final router = await _pumpHome(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Search'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    router.go(RoutePaths.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Payments'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PaymentsScreen), findsOneWidget);

    router.go(RoutePaths.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ProfileHubScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
  });
}
