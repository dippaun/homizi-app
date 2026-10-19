import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/broker/broker_registration_screen.dart';
import 'package:homizi/features/host/host_options_screen.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';
import 'package:homizi/features/requirements/requirement_form_screen.dart';
import 'package:homizi/features/roles/role_selection_screen.dart';
import 'package:homizi/features/roles/seeker_match.dart';
import 'package:homizi/features/roles/seeker_matches_screen.dart';
import 'package:homizi/features/roles/seeker_providers.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _NeedsRole extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.needsRole,
      contact: 'qa+roles@homizi.in',
      policyVersion: '2026-10-11-draft',
    );
  }

  @override
  Future<String?> selectPrimaryRole(String wire) async {
    state = state.copyWith(
      role: accountRoleForPrimaryWire(wire),
      homiziWire: wire,
      phase: SessionPhase.ready,
    );
    return null;
  }
}

class _RefusingRole extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.needsRole,
      contact: 'qa+roles@homizi.in',
      policyVersion: '2026-10-11-draft',
    );
  }

  @override
  Future<String?> selectPrimaryRole(String wire) async => 'Choose a role.';
}

class _ReadyTenant extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya@example.test',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _FixedRole extends SessionController {
  _FixedRole(this.wire);

  final String wire;

  @override
  SessionState build() {
    return SessionState(
      phase: SessionPhase.ready,
      contact: 'meenal@example.test',
      role: accountRoleForPrimaryWire(wire),
      homiziWire: wire,
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _KoramangalaDraft extends ListingDraftController {
  @override
  ListingDraft build() {
    return const ListingDraft(
      title: '2 BHK in Koramangala',
      city: 'Bengaluru',
      locality: 'Koramangala',
      rentText: '28000',
    );
  }
}

class _FixedSeekers implements SeekerMatchGateway {
  _FixedSeekers(this.page, {this.error});

  final SeekerMatchPage page;
  final Object? error;

  @override
  Future<SeekerMatchPage> load() async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return page;
  }
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  SessionController Function() create,
) async {
  _phoneSize(tester);
  final container = ProviderContainer(
    overrides: [sessionProvider.overrideWith(create)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HomiziApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

Future<void> _tapRole(WidgetTester tester, String role) async {
  final card = find.byKey(Key('role-card-$role'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<DemoInventoryGateway> _pumpRequirement(
  WidgetTester tester, {
  String? kind,
}) async {
  _phoneSize(tester);
  final gateway = DemoInventoryGateway();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [inventoryGatewayProvider.overrideWith((ref) => gateway)],
      child: MaterialApp(
        theme: HomiziTheme.light(),
        home: RequirementFormScreen(seekerKind: kind),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return gateway;
}

Future<void> _nextRequirement(WidgetTester tester) async {
  final button = find.byKey(const Key('requirement-continue'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

bool _chipSelected(WidgetTester tester, String label) {
  final filter = find.widgetWithText(FilterChip, label);
  if (filter.evaluate().isNotEmpty) {
    return tester.widget<FilterChip>(filter).selected;
  }
  return tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
      .selected;
}

void main() {
  testWidgets('the role picker offers four ways in', (tester) async {
    await _pumpApp(tester, _NeedsRole.new);
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.text('How will you use HOMIZI?'), findsOneWidget);
    expect(find.text('Roommate'), findsOneWidget);
    expect(find.text('Find a flatmate'), findsOneWidget);
    expect(find.text('Rental'), findsOneWidget);
    expect(find.text('Find a home to rent'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Rent out my property'), findsOneWidget);
    expect(find.text('Broker'), findsOneWidget);
    expect(find.text("I'm an agent"), findsOneWidget);
    expect(find.textContaining('NoBroker'), findsNothing);
    expect(find.textContaining('nobroker'), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      HomiziColors.white,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('role-card-broker')),
              matching: find.byIcon(Icons.badge_outlined),
            ),
          )
          .color,
      HomiziColors.accent,
    );
  });

  testWidgets('a refused role stays on the picker', (tester) async {
    await _pumpApp(tester, _RefusingRole.new);
    await _tapRole(tester, 'tenant');
    expect(find.text('Choose a role.'), findsOneWidget);
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
  });

  testWidgets('roommate opens the roommate brief', (tester) async {
    final container = await _pumpApp(tester, _NeedsRole.new);
    await _tapRole(tester, 'roommate');
    expect(container.read(sessionProvider).homiziWire, 'roommate');
    expect(find.text('Roommate brief'), findsOneWidget);
    expect(find.text('Step 1 of 14'), findsOneWidget);
    expect(find.text('Flatmate fit'), findsNothing);
  });

  testWidgets('rental opens the tenant brief', (tester) async {
    final container = await _pumpApp(tester, _NeedsRole.new);
    await _tapRole(tester, 'tenant');
    expect(container.read(sessionProvider).homiziWire, 'tenant');
    expect(find.text('What you need'), findsOneWidget);
    expect(find.text('Step 1 of 13'), findsOneWidget);
  });

  testWidgets('host opens the two host options', (tester) async {
    final container = await _pumpApp(tester, _NeedsRole.new);
    await _tapRole(tester, 'host');
    expect(container.read(sessionProvider).homiziWire, 'host');
    expect(find.byType(HostOptionsScreen), findsOneWidget);
    expect(find.text('See what seekers need'), findsOneWidget);
    expect(find.text('Post your property'), findsOneWidget);
  });

  testWidgets('broker opens registration', (tester) async {
    final container = await _pumpApp(tester, _NeedsRole.new);
    await _tapRole(tester, 'broker');
    expect(container.read(sessionProvider).homiziWire, 'broker');
    expect(find.text('Broker registration'), findsOneWidget);
    expect(find.byKey(const Key('broker-name')), findsOneWidget);
  });

  testWidgets('profile can open the role picker', (tester) async {
    final container = await _pumpApp(tester, _ReadyTenant.new);
    container.read(routerProvider).go(RoutePaths.profile);
    await tester.pump();
    await tester.pump();
    final change = find.byKey(const Key('profile-change-role'));
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.byKey(const Key('role-card-roommate')), findsOneWidget);
    expect(find.byKey(const Key('role-card-broker')), findsOneWidget);
  });

  testWidgets('a tenant brief walks the new steps and can stay hidden', (
    tester,
  ) async {
    final gateway = await _pumpRequirement(tester);
    expect(find.text('Step 1 of 13'), findsOneWidget);
    expect(find.text('City and localities'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('requirement-locality')),
      'Koramangala',
    );
    await tester.tap(find.byKey(const Key('requirement-add-locality')));
    await tester.pump();
    expect(find.text('Koramangala'), findsWidgets);

    await _nextRequirement(tester);
    expect(find.text('Monthly budget'), findsOneWidget);
    expect(find.byKey(const Key('requirement-budget-slider')), findsOneWidget);
    expect(find.text('₹12,000 – ₹35,000'), findsOneWidget);

    await _nextRequirement(tester);
    expect(find.text('When you move'), findsOneWidget);
    expect(find.byKey(const Key('requirement-lease-11')), findsOneWidget);
    await tester.tap(find.byKey(const Key('requirement-lease-6')));
    await tester.pump();

    await _nextRequirement(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Private room'), findsOneWidget);
    expect(find.text('1 RK'), findsOneWidget);
    expect(find.text('2 BHK'), findsOneWidget);
    expect(find.text('Furnishing'), findsOneWidget);
    expect(find.text('Unfurnished'), findsOneWidget);
    expect(find.text('Semi-furnished'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.widgetWithText(FilterChip, '2 BHK'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '2 BHK'), findsNothing);
    await tester.tap(find.text('1 BHK'));
    await tester.tap(find.text('Shared room'));
    await tester.tap(find.text('Furnished'));
    await tester.pump();
    expect(_chipSelected(tester, 'Shared room'), isTrue);
    expect(_chipSelected(tester, '1 BHK'), isTrue);
    expect(_chipSelected(tester, '2 BHK'), isTrue);
    expect(_chipSelected(tester, 'Private room'), isFalse);
    expect(_chipSelected(tester, 'Semi-furnished'), isTrue);
    expect(_chipSelected(tester, 'Furnished'), isTrue);

    await _nextRequirement(tester);
    expect(find.text('Building'), findsOneWidget);
    expect(find.text('Car or two-wheeler'), findsOneWidget);
    expect(find.text('Lift required'), findsOneWidget);
    expect(_chipSelected(tester, 'Car or two-wheeler'), isTrue);
    await tester.tap(find.text('No parking'));
    await tester.pump();
    expect(_chipSelected(tester, 'No parking'), isTrue);
    expect(_chipSelected(tester, 'Car or two-wheeler'), isFalse);
    await tester.tap(find.text('Car'));
    await tester.tap(find.text('Two-wheeler'));
    await tester.pump();
    expect(_chipSelected(tester, 'No parking'), isFalse);
    expect(_chipSelected(tester, 'Car'), isTrue);
    expect(_chipSelected(tester, 'Two-wheeler'), isTrue);
    expect(_chipSelected(tester, 'Any floor'), isTrue);
    await tester.tap(find.text('Ground'));
    await tester.pump();
    expect(_chipSelected(tester, 'Any floor'), isFalse);
    expect(_chipSelected(tester, 'Ground'), isTrue);
    await tester.tap(find.text('Any floor'));
    await tester.pump();
    expect(_chipSelected(tester, 'Any floor'), isTrue);
    expect(_chipSelected(tester, 'Ground'), isFalse);
    await tester.tap(find.byKey(const Key('requirement-lift')));
    await tester.pump();

    await _nextRequirement(tester);
    expect(find.text('How you live'), findsOneWidget);
    expect(find.text('No pets'), findsOneWidget);
    expect(find.text('Vegetarian'), findsOneWidget);
    expect(find.text('Smoking'), findsOneWidget);
    expect(find.text('Drinking'), findsOneWidget);

    await _nextRequirement(tester);
    expect(find.text('Who you live with'), findsOneWidget);
    expect(
      find.text(
        'Gender preference for flatmates. This is not used in the match score.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(ChoiceChip, 'No preference'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Women'), findsNothing);
    await tester.tap(find.text('Women'));
    await tester.tap(find.text('Men'));
    await tester.pump();
    expect(_chipSelected(tester, 'Women'), isFalse);
    expect(_chipSelected(tester, 'Men'), isTrue);
    expect(_chipSelected(tester, 'No preference'), isFalse);
    await tester.tap(find.text('Sharing'));
    await tester.tap(find.text('Couple'));
    await tester.pump();
    expect(_chipSelected(tester, 'Sharing'), isFalse);
    expect(_chipSelected(tester, 'Just me'), isFalse);
    expect(_chipSelected(tester, 'Couple'), isTrue);

    await _nextRequirement(tester);
    expect(find.text('Work and commute'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('requirement-work')),
      'Indiranagar',
    );
    await tester.enterText(
      find.byKey(const Key('requirement-commute')),
      'Metro, about 25 minutes',
    );

    await _nextRequirement(tester);
    expect(find.text('Guests'), findsOneWidget);

    await _nextRequirement(tester);
    expect(find.text('Amenities'), findsOneWidget);
    await tester.tap(find.byKey(const Key('requirement-amenity-wifi')));
    await tester.pump();

    await _nextRequirement(tester);
    expect(find.text('About you'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('requirement-about')),
      'Architect in Indiranagar. I want a bright 1 BHK.',
    );

    await _nextRequirement(tester);
    expect(find.text('Who can find you'), findsOneWidget);
    expect(
      find.text('Let verified hosts and brokers contact me'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('requirement-discoverable')));
    await tester.pump();
    expect(find.text('Flatmate fit'), findsNothing);

    await _nextRequirement(tester);
    expect(find.text('Step 13 of 13'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(
      find.textContaining(
        '₹12,000 – ₹35,000 · Shared room, 1 BHK, 2 BHK · Semi-furnished, Furnished',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Hidden from hosts and brokers'),
      findsOneWidget,
    );
    expect(find.text('Flatmate fit'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('requirement-save')));
    await tester.tap(find.byKey(const Key('requirement-save')));
    await tester.pump();
    await tester.pump();
    expect(find.text(InventoryCopy.demoRequirementSaved), findsOneWidget);

    final saved = await gateway.loadLatestRequirement();
    expect(saved, isNotNull);
    expect(saved!.seekerKind, 'tenant');
    expect(saved.city, 'Bengaluru');
    expect(saved.localityList, ['Koramangala']);
    expect(saved.leaseMonths, 6);
    expect(saved.roomTypes, ['shared', '1bhk', '2bhk']);
    expect(saved.furnishings, ['semi_furnished', 'furnished']);
    expect(saved.parkingNeeds, ['two_wheeler', 'four_wheeler']);
    expect(saved.preferredFloors, ['any']);
    expect(saved.genderPreference, 'men');
    expect(saved.occupancyPreference, 'couple');
    expect(saved.liftNeeded, isTrue);
    expect(saved.amenities, contains('wifi'));
    expect(saved.workLocation, 'Indiranagar');
    expect(saved.discoverable, isFalse);
    expect(saved.aboutMe, contains('Indiranagar'));
  });

  testWidgets('a roommate brief adds the flatmate step', (tester) async {
    final gateway = await _pumpRequirement(tester, kind: 'roommate');
    expect(find.text('Roommate brief'), findsOneWidget);
    expect(find.text('Step 1 of 14'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('requirement-locality')),
      'Jayanagar',
    );
    await tester.tap(find.byKey(const Key('requirement-add-locality')));
    await tester.pump();
    for (var step = 0; step < 12; step++) {
      await _nextRequirement(tester);
    }
    expect(find.text('Flatmate fit'), findsOneWidget);
    expect(find.text('Sleep schedule'), findsOneWidget);
    expect(find.text('Early sleeper'), findsOneWidget);
    expect(find.byKey(const Key('requirement-cleanliness')), findsOneWidget);
    expect(find.text('I work from home'), findsOneWidget);
    expect(find.text('Languages'), findsOneWidget);
    expect(find.text('Hindi'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.byKey(const Key('requirement-wfh')));
    await tester.pump();
    await tester.ensureVisible(find.text('yoga'));
    await tester.tap(find.text('yoga'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('requirement-flatmate-note')),
      'A quiet person who also works from home.',
    );

    await _nextRequirement(tester);
    expect(find.text('Step 14 of 14'), findsOneWidget);
    expect(
      find.textContaining('Hosts and brokers can see this brief'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('requirement-publish')));
    await tester.tap(find.byKey(const Key('requirement-publish')));
    await tester.pump();
    await tester.pump();
    expect(find.text(InventoryCopy.demoRequirementUnpublished), findsOneWidget);

    final saved = await gateway.loadLatestRequirement();
    expect(saved!.seekerKind, 'roommate');
    expect(saved.localityList, ['Jayanagar']);
    expect(saved.workFromHome, isTrue);
    expect(saved.hobbies, contains('yoga'));
    expect(saved.flatmateNote, contains('quiet person'));
    expect(saved.discoverable, isTrue);
    expect(saved.languages, containsAll(['Hindi', 'English']));
  });

  testWidgets('host options open seekers and a listing without brokerage', (
    tester,
  ) async {
    _phoneSize(tester);
    final router = GoRouter(
      initialLocation: RoutePaths.hostOptions,
      routes: [
        GoRoute(
          path: RoutePaths.hostOptions,
          builder: (context, state) => const HostOptionsScreen(),
        ),
        GoRoute(
          path: RoutePaths.hostSeekers,
          builder: (context, state) =>
              const SeekerMatchesScreen(title: 'What seekers need'),
        ),
        GoRoute(
          path: RoutePaths.listingEditor,
          builder: (context, state) => ListingEditorScreen(
            fresh: state.uri.queryParameters['fresh'] == '1',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _FixedRole('host')),
          listingDraftProvider.overrideWith(_KoramangalaDraft.new),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      HomiziColors.white,
    );
    await tester.tap(find.byKey(const Key('host-see-seekers')));
    await tester.pump();
    await tester.pump();
    expect(find.text('What seekers need'), findsOneWidget);
    expect(find.text('Ananya Iyer'), findsOneWidget);
    expect(find.textContaining('Neelam'), findsNothing);

    router.go(RoutePaths.hostOptions);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('host-post-property')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Basics'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('listing-title')),
      '2 BHK in Koramangala',
    );
    await tester.enterText(
      find.byKey(const Key('listing-locality')),
      'Koramangala',
    );
    final city = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(city);
    await tester.tap(city);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bengaluru').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-continue')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Rent and deposit'), findsOneWidget);
    expect(find.byKey(const Key('listing-brokerage-terms')), findsNothing);
    expect(find.byKey(const Key('broker-chip')), findsNothing);
  });

  testWidgets('broker registration saves and opens matching seekers', (
    tester,
  ) async {
    _phoneSize(tester);
    final router = GoRouter(
      initialLocation: RoutePaths.brokerRegister,
      routes: [
        GoRoute(
          path: RoutePaths.brokerRegister,
          builder: (context, state) => const BrokerRegistrationScreen(),
        ),
        GoRoute(
          path: RoutePaths.brokerSeekers,
          builder: (context, state) => const SeekerMatchesScreen(
            title: 'Matching seekers',
            showBrokerBadge: true,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Broker registration'), findsOneWidget);
    expect(find.byKey(const Key('broker-chip')), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      HomiziColors.white,
    );

    await tester.tap(find.byKey(const Key('broker-save')));
    await tester.pump();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.byKey(const Key('broker-saved')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('broker-name')),
      'Meenal Deshpande',
    );
    await tester.enterText(
      find.byKey(const Key('broker-agency')),
      'Deshpande Realty',
    );
    await tester.enterText(find.byKey(const Key('broker-rera')), '12');
    await tester.tap(find.byKey(const Key('broker-save')));
    await tester.pump();
    expect(
      find.text('RERA number should be 5 to 40 letters, digits, or slashes.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('broker-rera')),
      'PRM/KA/RERA/1251/446/AG/171018/000441',
    );
    await tester.ensureVisible(find.byKey(const Key('broker-city-Bengaluru')));
    await tester.tap(find.byKey(const Key('broker-city-Bengaluru')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('broker-locality')),
      'Koramangala',
    );
    await tester.tap(find.text('Add locality'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('broker-phone')), '9876543210');
    await tester.ensureVisible(find.byKey(const Key('broker-save')));
    await tester.tap(find.byKey(const Key('broker-save')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Your broker profile is saved.'), findsOneWidget);
    expect(find.byKey(const Key('broker-see-seekers')), findsOneWidget);
    expect(find.byKey(const Key('broker-post-listing')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('broker-see-seekers')));
    await tester.tap(find.byKey(const Key('broker-see-seekers')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Matching seekers'), findsOneWidget);
    expect(find.byKey(const Key('broker-chip')), findsOneWidget);
    expect(find.text('Ananya Iyer'), findsOneWidget);
    expect(find.text('100% match'), findsWidgets);
    expect(find.textContaining('Neelam'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    expect(
      find.textContaining('Contact stays hidden until you both match'),
      findsOneWidget,
    );
  });

  testWidgets('a broker listing asks for brokerage terms', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _FixedRole('broker')),
          listingDraftProvider.overrideWith(_KoramangalaDraft.new),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ListingEditorScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('listing-continue')));
    await tester.pump();
    expect(find.text('Rent and deposit'), findsOneWidget);
    expect(find.byKey(const Key('broker-chip')), findsOneWidget);
    expect(find.byKey(const Key('listing-brokerage-terms')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('listing-brokerage-terms')),
      'One month rent, paid when the agreement is signed',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('listing-brokerage-terms')))
          .controller
          ?.text,
      'One month rent, paid when the agreement is signed',
    );
  });

  testWidgets('matching seekers explains an empty list', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seekerMatchGatewayProvider.overrideWithValue(
            _FixedSeekers(
              const SeekerMatchPage(seekers: [], basis: 'No listings yet.'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const SeekerMatchesScreen(
            title: 'Matching seekers',
            showBrokerBadge: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('seekers-empty')), findsOneWidget);
    expect(
      find.text('No discoverable briefs match your listings yet.'),
      findsOneWidget,
    );
    expect(find.textContaining('Neelam'), findsNothing);
    expect(find.byKey(const Key('broker-chip')), findsOneWidget);
  });

  testWidgets('matching seekers shows a load error', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seekerMatchGatewayProvider.overrideWithValue(
            _FixedSeekers(
              const SeekerMatchPage(seekers: [], basis: ''),
              error: StateError('offline'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const SeekerMatchesScreen(title: 'What seekers need'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('The seeker list could not be loaded.'), findsOneWidget);
    expect(find.byKey(const Key('broker-chip')), findsNothing);
  });
}
