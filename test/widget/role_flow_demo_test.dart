import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/broker/broker_home_screen.dart';
import 'package:homizi/features/host/host_home_screen.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/public_profile.dart';
import 'package:homizi/features/roommates/roommate_screen.dart';
import 'package:homizi/features/saved/saved_screen.dart';
import 'package:homizi/features/session/session_controller.dart';

Future<ProviderContainer> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.parse(
          rawEnvironment: 'staging',
          supabaseUrl: '',
          supabaseAnonKey: '',
          policyVersion: '2026-10-11-draft',
          stagingPasswordAuth: true,
          stagingTestPassword: 'REDACTED_STAGING_PASSWORD',
          demoSkipLogin: true,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(ownVerificationProvider.notifier)
      .replace(PublicProfile.verifiedDemo);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HomiziApp()),
  );
  await tester.pump();
  await container.read(sessionProvider.notifier).finishBoot();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

Finder _downScroll(Finder scope) {
  return find.descendant(
    of: scope,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _home(
  WidgetTester tester,
  ProviderContainer container, {
  String path = RoutePaths.home,
}) async {
  container.read(routerProvider).go(path);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _tapClear(WidgetTester tester, Finder target, Finder scope) async {
  await tester.ensureVisible(target);
  var rect = tester.getRect(target);
  final limit =
      tester.view.physicalSize.height / tester.view.devicePixelRatio - 120;
  final scrollable = _downScroll(scope);
  if (rect.center.dy > limit && scrollable.evaluate().isNotEmpty) {
    await tester.drag(scrollable, Offset(0, rect.center.dy - (limit - 40)));
    await tester.pump();
    rect = tester.getRect(target);
  }
  await tester.tapAt(rect.center);
}

Future<void> _top(WidgetTester tester, Finder scrollable) async {
  if (scrollable.evaluate().isEmpty) {
    return;
  }
  final state = tester.state<ScrollableState>(scrollable);
  state.position.jumpTo(0);
  await tester.pump();
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  required Finder scope,
  String? horizontalKey,
}) async {
  final down = _downScroll(scope);
  if (down.evaluate().isNotEmpty) {
    await _top(tester, down);
  }
  if (horizontalKey != null) {
    final bar = find.byKey(Key(horizontalKey));
    if (bar.evaluate().isEmpty && down.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(bar, 280, scrollable: down);
    }
    final horizontal = find.descendant(
      of: bar,
      matching: find.byType(Scrollable),
    );
    if (target.evaluate().isEmpty && horizontal.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(target, 160, scrollable: horizontal);
    } else {
      await tester.ensureVisible(target);
    }
    return;
  }
  if (target.evaluate().isEmpty && down.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(target, 280, scrollable: down);
    return;
  }
  await tester.ensureVisible(target);
}

Future<void> _openPath(
  WidgetTester tester,
  ProviderContainer container,
  String path,
  Finder marker,
) async {
  unawaited(container.read(routerProvider).push(path));
  await tester.pump();
  await _until(tester, marker);
  expect(marker, findsWidgets);
  expect(find.textContaining('Sign in before'), findsNothing);
  expect(find.textContaining('Sign in to '), findsNothing);
  await _home(tester, container);
}

Future<void> _role(WidgetTester tester, String role, Finder marker) async {
  if (find.byKey(Key('role-switch-$role')).hitTestable().evaluate().isEmpty) {
    final menu = find.byKey(const Key('home-menu'));
    if (menu.evaluate().isNotEmpty) {
      await tester.tap(menu);
      await tester.pumpAndSettle();
    }
  }
  for (final element in find.byType(Scrollable).evaluate()) {
    final scrollable = element.widget;
    if (scrollable is! Scrollable ||
        scrollable.axisDirection != AxisDirection.down) {
      continue;
    }
    final state = (element as StatefulElement).state as ScrollableState;
    if (state.position.hasPixels && state.position.pixels != 0) {
      state.position.jumpTo(0);
    }
  }
  await tester.pump();
  final chip = find.byKey(Key('role-switch-$role'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final router = GoRouter.of(
    tester.element(find.byKey(const Key('home-screen'))),
  );
  if (role == 'host') {
    router.go(RoutePaths.hostHome);
  } else if (role == 'broker') {
    router.go(RoutePaths.brokerHome);
  } else if (role == 'roommate') {
    router.go(RoutePaths.roommates);
  }
  await tester.pump();
  await _until(tester, marker);
  expect(marker, findsOneWidget);
  expect(find.textContaining('Sign in'), findsNothing);
}

void main() {
  test(
    'listing amounts reject leading zeros, tiny area, and high maintenance',
    () {
      const draft = ListingDraft(
        title: '2 BHK in Indiranagar',
        city: 'Bengaluru',
        locality: 'Indiranagar',
        rentText: '028000',
        maintenanceText: '40000',
        areaText: '55',
      );
      final issues = draft.persistBlockers();
      expect(
        issues,
        contains('Enter the rent as a whole number without leading zeros.'),
      );
      expect(
        issues,
        contains('Maintenance cannot be higher than the monthly rent.'),
      );
      expect(issues.any((issue) => issue.contains('120 and 20000')), isTrue);
      const clean = ListingDraft(
        title: '2 BHK in Indiranagar',
        city: 'Bengaluru',
        locality: 'Indiranagar',
        rentText: '28000',
        maintenanceText: '2500',
        areaText: '850',
      );
      expect(clean.persistBlockers(), isEmpty);
    },
  );

  testWidgets('demo mode opens every role home and each entry point', (
    tester,
  ) async {
    final container = await _boot(tester);
    expect(container.read(forceDemoModeProvider), isTrue);
    expect(find.text('Sign in'), findsNothing);
    expect(find.textContaining('Sign in to '), findsNothing);
    expect(find.textContaining('Sign in before'), findsNothing);
    expect(find.text('Find a place.'), findsOneWidget);
    expect(find.text('Find your people.'), findsOneWidget);
    expect(find.text('Everything for your next home'), findsNothing);
    expect(find.byType(HostHomeScreen), findsNothing);

    container.read(routerProvider).go(RoutePaths.tenantHome);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.byKey(const Key('tenant-home-screen')), findsNothing);
    expect(find.text('Your tenant home'), findsNothing);
    expect(find.text('What you need'), findsNothing);

    final tenantPaths = <(String, Finder)>[
      (
        RoutePaths.searchStart,
        find.byKey(const Key('search-properties-screen')),
      ),
      (RoutePaths.explore, find.byKey(const Key('group-by-locality'))),
      (RoutePaths.saved, find.byType(SavedScreen)),
      (RoutePaths.matches, find.byType(MatchesScreen)),
      (RoutePaths.tenantVisits, find.byKey(const Key('tenant-visits-screen'))),
      (RoutePaths.profile, find.byKey(const Key('profile-name'))),
      (RoutePaths.tenantSetup, find.byKey(const Key('tenant-setup-screen'))),
    ];
    for (final (path, marker) in tenantPaths) {
      await _openPath(tester, container, path, marker);
    }

    await _home(tester, container);
    const services = <(String, String)>[
      (RoutePaths.agreements, 'agreement-rent'),
      ('${RoutePaths.serviceRequest}?kind=packers_movers', 'service-from'),
      ('${RoutePaths.serviceRequest}?kind=cleaning', 'service-from'),
      ('${RoutePaths.serviceRequest}?kind=ac_repair', 'service-from'),
      ('${RoutePaths.serviceRequest}?kind=plumbing', 'service-from'),
      (RoutePaths.help, 'faq-search'),
      (RoutePaths.tools, 'tool-receipt'),
      (RoutePaths.verifyIdentity, 'kyc-coming-soon'),
      (RoutePaths.payments, 'payment-amount'),
    ];
    for (final (path, marker) in services) {
      await _openPath(tester, container, path, find.byKey(Key(marker)));
    }

    await _role(tester, 'host', find.byKey(const Key('owner-dashboard')));
    expect(find.byType(HostHomeScreen), findsNothing);
    expect(find.text('Your homes'), findsNothing);
    expect(find.text('The seeker list could not be loaded.'), findsNothing);

    final hostPaths = <(String, Finder)>[
      (RoutePaths.hostProfile, find.byKey(const Key('host-company'))),
      (RoutePaths.hostSeekers, find.byKey(const Key('seeker-card-ananya'))),
      (RoutePaths.listStart, find.byKey(const Key('listing-start'))),
      (RoutePaths.ownerOverview, find.byKey(const Key('owner-overview'))),
      (RoutePaths.listings, find.byKey(const Key('owner-dashboard'))),
      (RoutePaths.hostLeads, find.byKey(const Key('host-leads-screen'))),
      (RoutePaths.photoManager, find.byKey(const Key('add-listing-photo'))),
      (RoutePaths.hostVisits, find.byKey(const Key('host-visits-screen'))),
      (RoutePaths.verifyIdentity, find.byKey(const Key('kyc-coming-soon'))),
      (RoutePaths.profile, find.byKey(const Key('profile-name'))),
      (RoutePaths.forOwners, find.byKey(const Key('for-owners-screen'))),
      (RoutePaths.seekers, find.byKey(const Key('seekers-screen'))),
      (RoutePaths.settings, find.byKey(const Key('delete-account'))),
      (
        RoutePaths.notifications,
        find.byKey(const Key('notification-preferences')),
      ),
      (RoutePaths.help, find.byKey(const Key('faq-search'))),
      (RoutePaths.matches, find.byType(MatchesScreen)),
      (RoutePaths.matchSwipe, find.byKey(const Key('property-swipe-page'))),
    ];
    for (final (path, marker) in hostPaths) {
      await _openPath(tester, container, path, marker);
    }

    await _role(tester, 'broker', find.byKey(const Key('partner-dashboard')));
    expect(find.byType(BrokerHomeScreen), findsNothing);
    expect(find.text('Your broker desk'), findsNothing);
    final brokerPaths = <(String, Finder)>[
      (RoutePaths.seekers, find.byKey(const Key('broker-briefs-screen'))),
      (RoutePaths.listings, find.byKey(const Key('broker-listings-screen'))),
      (RoutePaths.brokerLeads, find.byKey(const Key('broker-leads-screen'))),
      (RoutePaths.brokerChats, find.byKey(const Key('broker-chats-screen'))),
      (RoutePaths.brokerVisits, find.byKey(const Key('broker-visits-screen'))),
      (RoutePaths.partnerSetup, find.byKey(const Key('partner-setup-screen'))),
    ];
    for (final (path, marker) in brokerPaths) {
      await _openPath(tester, container, path, marker);
    }

    await _role(tester, 'roommate', find.byType(RoommateScreen));
    await _until(tester, find.text('Roommate Finder'));
    expect(find.text('Roommate Finder'), findsOneWidget);
    await tester.tap(find.byKey(const Key('roommate-filters')));
    await tester.pump();
    await _until(tester, find.byKey(const Key('roommate-filter-sheet')));
    expect(find.byKey(const Key('roommate-filter-sheet')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('roommate-filter-sheet'))),
    ).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('roommate-tab-requirements')));
    await tester.pump();
    final brief = find.byKey(const Key('flatmate-edit-profile'));
    await _reveal(tester, brief, scope: find.byType(RoommateScreen));
    await _tapClear(tester, brief, find.byType(RoommateScreen));
    await tester.pump();
    await _until(tester, find.byKey(const Key('sharer-setup-screen')));
    expect(find.text('Step 1 of 13'), findsNothing);
    expect(find.text('What you need'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('sharer-city-Mumbai')));
    await tester.tap(find.byKey(const Key('sharer-city-Mumbai')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('sharer-locality')),
      'Bandra West',
    );
    await tester.ensureVisible(find.byKey(const Key('sharer-room-private')));
    await tester.tap(find.byKey(const Key('sharer-room-private')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('sharer-setup-continue')));
    await tester.tap(find.byKey(const Key('sharer-setup-continue')));
    await tester.pump();
    await _until(tester, find.byKey(const Key('role-ready-screen')));
    expect(find.text("You're all set"), findsWidgets);
    await tester.tap(find.byKey(const Key('role-ready-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await _home(tester, container);
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.text('Find a place.'), findsOneWidget);
    expect(find.textContaining('Sign in before'), findsNothing);

    await _role(tester, 'tenant', find.text('Find a place.'));
    expect(find.byKey(const Key('home-card-profile')), findsOneWidget);
    expect(find.text('Find your people.'), findsOneWidget);
    expect(find.text('Everything for your next home'), findsNothing);
  });
}
