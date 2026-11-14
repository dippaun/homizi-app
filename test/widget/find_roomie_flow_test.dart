import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/find_roomie/find_roomie_catalog.dart';
import 'package:homizi/features/find_roomie/find_roomie_models.dart';
import 'package:homizi/features/find_roomie/find_roomie_providers.dart';
import 'package:homizi/features/find_roomie/find_roomie_store.dart';
import 'package:homizi/features/matching/match_api.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'test@homizi.in',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _EmptyDiscovery extends DiscoveryController {
  @override
  DiscoveryState build() => const DiscoveryState();
}

void main() {
  testWidgets('connect, match, explore, request, home, then confirm', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final local = MemoryFindRoomieLocal();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_ReadySession.new),
          discoveryProvider.overrideWith(_EmptyDiscovery.new),
          findRoomieLocalProvider.overrideWithValue(local),
        ],
        child: const HomiziApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    );

    router.go(RoutePaths.roommate);
    await tester.pumpAndSettle();
    expect(find.text('Roommate Finder'), findsOneWidget);
    await tester.tap(find.byKey(const Key('find-roomie-entry')));
    await tester.pumpAndSettle();

    expect(find.text('Find Your Roomie'), findsWidgets);
    expect(find.byKey(const Key('find-roomie-sample')), findsOneWidget);
    final deck = sampleFindRoomieDeck();
    final mira = deck.people.first;
    final expected = scoreRoommate(deck.viewer, mira.traits).percent;
    expect(
      tester
          .widgetList<Text>(find.byKey(Key('find-roomie-percent-${mira.id}')))
          .every((text) => text.data == '$expected%'),
      isTrue,
    );
    expect(find.textContaining('WhatsApp'), findsNothing);
    expect(find.textContaining('tel:'), findsNothing);

    await _tap(tester, 'find-roomie-connect-${mira.id}');
    expect(find.text('Your match'), findsOneWidget);
    expect(
      tester
          .widgetList<Text>(find.byKey(Key('find-roomie-percent-${mira.id}')))
          .every((text) => text.data == '$expected%'),
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('find-roomie-chat')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Chat in Homizi'), findsOneWidget);

    await _tap(tester, 'find-roomie-chat');
    expect(router.state.uri.path, RoutePaths.chat(sampleMatchId(mira.id)));
    expect(router.state.uri.path.contains('whatsapp'), isFalse);
    router.pop();
    await tester.pumpAndSettle();

    await _tap(tester, 'find-roomie-explore');
    expect(find.text('Homes together'), findsOneWidget);
    final home = sampleFindRoomieHomes.first;
    expect(find.text(home.title), findsOneWidget);

    await _tap(tester, 'find-roomie-request-${home.id}');
    expect(find.text('Request together'), findsOneWidget);
    await _tap(tester, 'find-roomie-self-confirm');
    await _tap(tester, 'find-roomie-partner-confirm');
    expect(local.snapshot.shortlists, isNotEmpty);
    expect(local.snapshot.joints.single.bothConfirmed, isTrue);

    await _tap(tester, 'find-roomie-open-home');
    expect(find.text('Home & housemate details'), findsOneWidget);
    expect(router.state.uri.path, SharedHomePaths.home(home.id));
    router.pop();
    await tester.pumpAndSettle();

    await _tap(tester, 'find-roomie-to-confirm');
    expect(find.byKey(const Key('find-roomie-confirmed')), findsOneWidget);
    expect(find.textContaining('are sharing a home'), findsOneWidget);

    await _tap(tester, 'find-roomie-confirm-split');
    expect(router.state.uri.path, RoutePaths.rentSplit);
    expect(router.state.uri.queryParameters['with'], 'Meera,Mira');
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    finder,
    400,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
