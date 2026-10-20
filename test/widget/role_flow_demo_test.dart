import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:homizi/features/roommates/roommate_screen.dart';
import 'package:homizi/features/saved/saved_screen.dart';

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
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HomiziApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump();
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

Future<void> _home(WidgetTester tester, ProviderContainer container) async {
  container.read(routerProvider).go(RoutePaths.home);
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

Future<void> _open(
  WidgetTester tester,
  ProviderContainer container,
  String key,
  Finder marker, {
  required Finder scope,
  String? horizontalKey,
}) async {
  final target = find.byKey(Key(key));
  await _reveal(tester, target, scope: scope, horizontalKey: horizontalKey);
  await _tapClear(tester, target, scope);
  await tester.pump();
  await _until(tester, marker);
  expect(marker, findsWidgets);
  expect(find.textContaining('Sign in before'), findsNothing);
  expect(find.textContaining('Sign in to '), findsNothing);
  await _home(tester, container);
}

Future<void> _role(WidgetTester tester, String role, Finder marker) async {
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
    expect(find.byKey(const Key('tenant-journey')), findsOneWidget);
    expect(find.text('Everything for your next home'), findsNothing);
    expect(find.byType(HostHomeScreen), findsNothing);

    final tenantHome = find.byKey(const Key('home-screen'));
    final tenantEntries = <(String, Finder)>[
      ('tenant-entry-search', find.byKey(const Key('tenant-search-screen'))),
      ('tenant-entry-explore', find.byKey(const Key('group-by-locality'))),
      ('tenant-entry-saved', find.byType(SavedScreen)),
      ('tenant-entry-brief', find.byKey(const Key('requirement-step-label'))),
      ('tenant-entry-matches', find.byType(MatchesScreen)),
      ('tenant-entry-visits', find.byKey(const Key('tenant-visits-screen'))),
      ('tenant-entry-profile', find.byKey(const Key('profile-name'))),
      ('tenant-entry-setup', find.byKey(const Key('tenant-setup-screen'))),
    ];
    for (final (key, marker) in tenantEntries) {
      await _open(tester, container, key, marker, scope: tenantHome);
    }

    final carousel = <(String, String)>[
      ('home-agreement', 'agreement-rent'),
      ('home-packers', 'service-from'),
      ('home-cleaning', 'service-from'),
      ('home-ac', 'service-from'),
      ('home-plumbing', 'service-from'),
      ('home-legal', 'faq-search'),
    ];
    for (final (key, marker) in carousel) {
      await _open(
        tester,
        container,
        key,
        find.byKey(Key(marker)),
        scope: tenantHome,
        horizontalKey: 'home-services',
      );
    }
    const below = <(String, String)>[
      ('home-tools', 'tool-receipt'),
      ('home-verify', 'kyc-consent'),
      ('home-pay', 'payment-amount'),
    ];
    for (final (key, marker) in below) {
      await _open(
        tester,
        container,
        key,
        find.byKey(Key(marker)),
        scope: tenantHome,
      );
    }

    await _role(tester, 'host', find.byType(HostHomeScreen));
    expect(find.text('The seeker list could not be loaded.'), findsNothing);

    const hostEntries = <(String, String)>[
      ('host-create-profile', 'host-company'),
      ('host-see-seekers', 'seeker-card-ananya'),
      ('host-post-property', 'listing-title'),
      ('host-tile-dashboard', 'owner-dashboard'),
      ('host-tile-listings', 'owner-dashboard'),
      ('host-tile-leads', 'host-leads-screen'),
      ('host-tile-photos', 'add-listing-photo'),
      ('host-tile-visits', 'host-visits-screen'),
      ('host-tile-verify', 'kyc-consent'),
      ('host-tile-profile', 'profile-name'),
      ('host-tile-options', 'host-post-property'),
      ('host-tile-owners', 'for-owners-screen'),
      ('host-tile-seekers', 'seekers-screen'),
      ('host-tile-settings', 'delete-account'),
      ('host-tile-notifications', 'notification-preferences'),
      ('host-tile-help', 'faq-search'),
    ];
    for (final (key, marker) in hostEntries) {
      await _open(
        tester,
        container,
        key,
        find.byKey(Key(marker)),
        scope: find.byType(HostHomeScreen),
      );
    }
    await _open(
      tester,
      container,
      'host-tile-chats',
      find.byType(MatchesScreen),
      scope: find.byType(HostHomeScreen),
    );
    final swipe = find.byKey(const Key('host-tile-swipe'));
    await _reveal(tester, swipe, scope: find.byType(HostHomeScreen));
    await _tapClear(tester, swipe, find.byType(HostHomeScreen));
    await tester.pump();
    await _until(tester, find.text('Meera K.'));
    expect(find.text('Meera K.'), findsOneWidget);
    expect(find.text('People did not load'), findsNothing);
    expect(find.textContaining('Sign in to '), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(HostHomeScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await _open(
      tester,
      container,
      'host-see-seekers',
      find.text('Ananya Iyer'),
      scope: find.byType(HostHomeScreen),
    );

    await _role(tester, 'broker', find.byType(BrokerHomeScreen));
    const brokerEntries = <(String, String)>[
      ('broker-home-create-profile', 'broker-registration-screen'),
      ('broker-tile-briefs', 'broker-briefs-screen'),
      ('broker-tile-listings', 'broker-listings-screen'),
      ('broker-tile-leads', 'broker-leads-screen'),
      ('broker-tile-chats', 'broker-chats-screen'),
      ('broker-tile-visits', 'broker-visits-screen'),
      ('broker-tile-profile', 'broker-registration-screen'),
      ('broker-open-notifications', 'notification-preferences'),
      ('broker-open-settings', 'delete-account'),
    ];
    for (final (key, marker) in brokerEntries) {
      await _open(
        tester,
        container,
        key,
        find.byKey(Key(marker)),
        scope: find.byType(BrokerHomeScreen),
      );
    }

    await _role(tester, 'roommate', find.byType(RoommateScreen));
    expect(find.byKey(const Key('flatmate-shortcuts')), findsOneWidget);
    await _open(
      tester,
      container,
      'flatmate-chats',
      find.byType(MatchesScreen),
      scope: find.byType(RoommateScreen),
      horizontalKey: 'flatmate-shortcuts',
    );
    await tester.tap(find.byKey(const Key('roommate-show-swipe')));
    await tester.pump();
    expect(find.byKey(const Key('roommate-swipe-card')), findsWidgets);
    await tester.tap(find.byKey(const Key('roommate-filters')));
    await tester.pump();
    await _until(tester, find.byKey(const Key('roommate-filter-sheet')));
    expect(find.byKey(const Key('roommate-filter-sheet')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('roommate-filter-sheet'))),
    ).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _open(
      tester,
      container,
      'flatmate-mutual',
      find.byKey(const Key('flatmate-mutual-screen')),
      scope: find.byType(RoommateScreen),
      horizontalKey: 'flatmate-shortcuts',
    );
    await _open(
      tester,
      container,
      'flatmate-rooms',
      find.byKey(const Key('flatmate-rooms-screen')),
      scope: find.byType(RoommateScreen),
      horizontalKey: 'flatmate-shortcuts',
    );
    final brief = find.byKey(const Key('flatmate-edit-profile'));
    await _reveal(
      tester,
      brief,
      scope: find.byType(RoommateScreen),
      horizontalKey: 'flatmate-shortcuts',
    );
    await _tapClear(tester, brief, find.byType(RoommateScreen));
    await tester.pump();
    await _until(tester, find.byKey(const Key('requirement-locality')));
    expect(find.byKey(const Key('requirement-locality')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('requirement-locality')),
      'Bandra West',
    );
    await tester.tap(find.byKey(const Key('requirement-add-locality')));
    await tester.pump();
    for (var step = 0; step < 16; step++) {
      final save = find.byKey(const Key('requirement-save'));
      if (save.evaluate().isNotEmpty) {
        break;
      }
      await tester.tap(find.byKey(const Key('requirement-continue')));
      await tester.pump();
    }
    expect(find.byKey(const Key('requirement-save')), findsOneWidget);
    await tester.tap(find.byKey(const Key('requirement-save')));
    await tester.pump();
    await _until(tester, find.byKey(const Key('requirement-note')));
    expect(find.textContaining('Sign in before'), findsNothing);
    expect(find.text('Draft kept on this device.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('requirement-publish')));
    await tester.pump();
    await _until(tester, find.text('Brief published'));
    expect(find.text('Brief published'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
    await tester.tap(find.byKey(const Key('demo-success-home')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(RoommateScreen), findsOneWidget);
    expect(find.textContaining('Sign in before'), findsNothing);

    await _role(tester, 'tenant', find.byKey(const Key('tenant-journey')));
    expect(find.byKey(const Key('home-agreement')), findsOneWidget);
    expect(find.text('Everything for your next home'), findsNothing);
    expect(find.text('Your tenant home'), findsOneWidget);
  });
}
