import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/home/home_listing_deck.dart';
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

void main() {
  test('the deck keeps a couple-friendly home in the second slot', () {
    final deck = homeSwipeListings(DemoCatalog.listings);
    expect(deck, isNotEmpty);
    expect(deck.length, lessThanOrEqualTo(8));
    expect(deck[1].friendlyTags, contains('couple_friendly'));
    expect(deck.every((listing) => listing.photoAssets.isNotEmpty), isTrue);
  });

  testWidgets('home no longer mounts the swipe deck', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
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
    expect(find.byKey(const Key('home-swipe-card')), findsNothing);
    expect(find.text('Why Homizi'), findsNothing);
    expect(find.byKey(const Key('home-rentals')), findsOneWidget);
  });
}
