import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/discovery/listing_detail_screen.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roommates/domain/roommate_profile_row.dart';
import 'package:homizi/features/roommates/flatmate_return.dart';
import 'package:homizi/features/roommates/shared_rooms_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shared_home/shared_home_detail_screen.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';

class _FreshFlatmate extends SessionController {
  @override
  SessionState build() {
    return const SessionState(phase: SessionPhase.signedOut);
  }

  @override
  Future<String?> signIn({
    required String contact,
    required String code,
  }) async {
    state = SessionState(
      phase: SessionPhase.needsRole,
      contact: contact,
      policyVersion: '2026-10-11-draft',
    );
    return null;
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

class _ReadyFlatmate extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'qa+flatmate@homizi.in',
      role: AccountRole.tenant,
      homiziWire: 'roommate',
      policyVersion: '2026-10-11-draft',
    );
  }
}

Finder _nav(String label) {
  return find.descendant(
    of: find.byType(GlassyNavigationBar),
    matching: find.text(label),
  );
}

Future<void> _pump(
  WidgetTester tester,
  SessionController Function() create,
) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(create)],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  test('roommate brief rows fit roommate_profiles checks', () {
    final row = roommateProfileRow(
      const RequirementDraft(
        seekerKind: 'roommate',
        city: 'Bengaluru',
        localities: ['Jayanagar', 'Jayanagar'],
        locality: 'Jayanagar',
        budgetMinInr: 35000,
        budgetMaxInr: 18000,
        genderPreference: 'women',
        occupancyPreference: 'just_me',
        foodHabits: ['veg', 'eggetarian'],
        smoking: ['no', 'occasionally'],
        pets: ['have_pets', 'pets_ok'],
        sleepSchedules: ['early', 'night'],
        socialStyles: ['quiet', 'social'],
        cooking: ['often', 'rarely'],
        guestsPolicies: ['no_guests', 'often'],
        workFromHome: true,
        cleanliness: 9,
        languages: ['Hindi', 'Kannada'],
        hobbies: ['yoga'],
        flatmateNote: 'A quiet kitchen in Bengaluru.',
      ),
    );
    expect(row['seeking_role'], 'roommate');
    expect(row['open_to_flatmates'], isTrue);
    expect(row['budget_min_inr'], 18000);
    expect(row['budget_max_inr'], 35000);
    expect(row['gender_preference'], 'women');
    expect(row['occupancy'], 'solo');
    expect(row['food'], 'any');
    expect(row['smoking'], 'sometimes');
    expect(row['pets'], 'has');
    expect(row['sleep'], 'flexible');
    expect(row['social'], 'balanced');
    expect(row['cooking'], 'sometimes');
    expect(row['guests'], 'often');
    expect(row['wfh'], 'home');
    expect(row['cleanliness'], 5);
    expect(row['city'], 'Bengaluru');
    expect(row['localities'], ['Jayanagar']);
    expect(row.containsKey('user_id'), isFalse);
    expect(row.toString(), isNot(contains('NoBroker')));
  });

  testWidgets('create profile signs in, picks Flatmate, then returns home', (
    tester,
  ) async {
    await _pump(tester, _FreshFlatmate.new);
    GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    ).go(RoutePaths.welcome);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('create-profile')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('create-profile')))
          .onPressed,
      isNull,
    );

    await _tap(tester, find.byKey(const Key('consent-checkbox')));
    await _tap(tester, find.byKey(const Key('create-profile')));
    await _until(tester, find.text('Sign in'));
    expect(find.text('Sign in'), findsWidgets);

    final loginContext = tester.element(find.byType(LoginScreen));
    final container = ProviderScope.containerOf(loginContext);
    container.read(flatmateReturnProvider.notifier).clear();
    await _tap(tester, find.byKey(const Key('create-profile')));
    expect(container.read(flatmateReturnProvider), flatmateProfileNext);
    expect(
      find.text('Sign in, then your flatmate profile opens.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'qa+flatmate@homizi.in',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await _tap(tester, find.byKey(const Key('verify-code')));
    await _tap(tester, find.byKey(const Key('login-continue')));

    await _until(tester, find.byKey(const Key('role-card-roommate')));
    await _tap(tester, find.byKey(const Key('role-card-roommate')));
    await _until(tester, find.text('Roommate brief'));
    expect(find.text('Roommate brief'), findsOneWidget);
    expect(find.textContaining('NoBroker'), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      HomiziColors.white,
    );

    await _tap(tester, find.byKey(const Key('flatmate-profile-back')));
    await _until(tester, find.byKey(const Key('roommate-screen')));
    expect(find.byKey(const Key('roommate-screen')), findsOneWidget);
    expect(find.text('Roommate Finder'), findsOneWidget);
  });

  testWidgets('roommate finder opens filters, a profile, and shared rooms', (
    tester,
  ) async {
    await _pump(tester, _ReadyFlatmate.new);
    GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    ).go(RoutePaths.roommates);
    await tester.pump();
    await _until(tester, find.byKey(const Key('roommate-screen')));
    await _tap(tester, _nav('Roommate'));
    await _until(tester, find.text('Roommate Finder'));
    expect(find.text('Aditi Mehta'), findsWidgets);
    expect(find.textContaining('NoBroker'), findsNothing);

    await _tap(tester, find.byKey(const Key('roommate-tab-requirements')));
    await _tap(tester, find.byKey(const Key('flatmate-edit-profile')));
    await _until(tester, find.text('Roommate brief'));
    expect(find.byKey(const Key('flatmate-profile-back')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('flatmate-profile-back')));
    await _until(tester, find.byKey(const Key('roommate-screen')));

    await _tap(tester, find.byKey(const Key('roommate-header-chat')));
    await _until(tester, find.byKey(const Key('chat-inbox-screen')));
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await _until(tester, find.byKey(const Key('roommate-screen')));
    await _tap(tester, find.byKey(const Key('roommate-tab-matches')));
    await _until(tester, find.byKey(const Key('flatmate-rooms')));
    await _tap(tester, find.byKey(const Key('flatmate-rooms')));
    await _until(tester, find.byType(SharedRoomsScreen));
    expect(find.text('Room options for you'), findsOneWidget);
    final room = find.text('Shared room in Kothrud');
    await tester.scrollUntilVisible(
      room,
      400,
      scrollable: find.descendant(
        of: find.byKey(const Key('flatmate-rooms-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(room);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SharedHomeDetailScreen), findsOneWidget);
    final full = find.byKey(const Key('shared-full-listing'));
    await tester.scrollUntilVisible(
      full,
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('shared-detail-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(full);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ListingDetailScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('flatmate-rooms-screen')), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await _tap(tester, find.byKey(const Key('roommate-tab-find')));
    await _until(tester, find.byKey(const Key('roommate-filters')));
    await _tap(tester, find.byKey(const Key('roommate-filters')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('roommate-filter-sheet')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('roommate-apply-filters')));
    await tester.pump(const Duration(milliseconds: 400));
    await _until(tester, find.text('Aditi Mehta'));
    expect(find.textContaining('%'), findsWidgets);
  });
}
