import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/home/home_listing_deck.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

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

Future<void> _pumpHome(WidgetTester tester, {bool verified = false}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_ReadySession.new),
        if (verified) ownVerificationProvider.overrideWith(VerifiedSession.new),
      ],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.scrollUntilVisible(
    find.byKey(const Key('home-swipe-card')),
    400,
    scrollable: find.descendant(
      of: find.byKey(const Key('home-scroll')),
      matching: find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      ),
    ),
  );
  await tester.ensureVisible(find.byKey(const Key('home-swipe-skip')));
  await tester.pump();
}

void main() {
  test('the deck keeps a couple-friendly home in the second slot', () {
    final deck = homeSwipeListings(DemoCatalog.listings);
    expect(deck, isNotEmpty);
    expect(deck.length, lessThanOrEqualTo(8));
    expect(deck[1].friendlyTags, contains('couple_friendly'));
    expect(deck.every((listing) => listing.photoAssets.isNotEmpty), isTrue);
  });

  testWidgets('the home card shows title, chips, tick, and actions', (
    tester,
  ) async {
    await _pumpHome(tester);
    final first = homeSwipeListings(DemoCatalog.listings).first;

    expect(find.text(first.title), findsOneWidget);
    expect(find.byKey(const Key('home-swipe-verified')), findsOneWidget);
    expect(find.byKey(const Key('home-swipe-chip-rent')), findsOneWidget);
    expect(find.byKey(const Key('home-swipe-chip-type')), findsOneWidget);
    expect(find.byKey(const Key('home-swipe-chip-locality')), findsOneWidget);
    expect(find.byKey(const Key('home-swipe-chip-furnishing')), findsOneWidget);
    expect(find.textContaining('₹'), findsWidgets);
    expect(find.text(first.locality), findsWidgets);
    expect(find.byKey(const Key('home-swipe-rewind')), findsOneWidget);
    expect(find.byKey(const Key('home-swipe-skip')), findsOneWidget);
    expect(find.byKey(const Key('home-swipe-shortlist')), findsOneWidget);
    expect(find.byKey(const Key('home-swipe-chat')), findsOneWidget);
    expect(find.text('Couple friendly'), findsNothing);
  });

  testWidgets('skip, drag, and rewind move between listings', (tester) async {
    await _pumpHome(tester);
    final deck = homeSwipeListings(DemoCatalog.listings);

    await tester.tap(find.byKey(const Key('home-swipe-skip')));
    await tester.pumpAndSettle();
    expect(find.text(deck[1].title), findsOneWidget);
    expect(find.text('Couple friendly'), findsOneWidget);
    expect(
      find.byKey(const Key('home-swipe-tag-couple_friendly')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('home-swipe-rewind')));
    await tester.pump();
    expect(find.text(deck.first.title), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('home-swipe-card')),
      const Offset(-280, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text(deck[1].title), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('home-swipe-card')),
      const Offset(280, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text(deck[2].title), findsOneWidget);
  });

  testWidgets('shortlist saves the home and the end state confirms', (
    tester,
  ) async {
    await _pumpHome(tester);
    final deck = homeSwipeListings(DemoCatalog.listings);

    await tester.tap(find.byKey(const Key('home-swipe-shortlist')));
    await tester.pumpAndSettle();
    expect(find.text(deck[1].title), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-swipe-rewind')));
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsWidgets);
    expect(find.text(deck.first.title), findsOneWidget);

    for (var i = 0; i < deck.length; i++) {
      await tester.tap(find.byKey(const Key('home-swipe-skip')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('home-swipe-done')), findsOneWidget);
    expect(find.text('You are caught up'), findsOneWidget);
    expect(
      find.text(
        'You have seen these homes. Shortlisted ones stay on this device.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('home-swipe-review')));
    await tester.pump();
    expect(find.text(deck.first.title), findsOneWidget);
  });

  testWidgets('tapping the card opens the listing', (tester) async {
    await _pumpHome(tester);
    final first = homeSwipeListings(DemoCatalog.listings).first;

    await tester.tap(find.byKey(const Key('home-swipe-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(first.title), findsWidgets);
    expect(find.byKey(const Key('contact-gate')), findsOneWidget);
  });

  testWidgets('chat asks an unverified person to verify', (tester) async {
    await _pumpHome(tester);
    await tester.tap(find.byKey(const Key('home-swipe-chat')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('verify-to-continue-sheet')), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
  });

  testWidgets('a verified person opens chat without a phone number', (
    tester,
  ) async {
    await _pumpHome(tester, verified: true);
    await tester.tap(find.byKey(const Key('home-swipe-chat')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });
}
