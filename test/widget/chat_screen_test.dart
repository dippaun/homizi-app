import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/chat/demo_thread_gateway.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/thread_providers.dart';

void main() {
  testWidgets('chat refuses contact details and accepts a visit on device', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = DemoThreadGateway();
    gateway.seedVisit(
      const VisitRequest(
        id: 'visit-incoming',
        matchId: 'match-1',
        requesterId: 'demo-host',
        slots: [],
        status: 'requested',
        mine: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [threadGatewayProvider.overrideWith((ref) => gateway)],
        child: const MaterialApp(
          home: ChatScreen(
            matchId: 'match-1',
            otherName: 'Rohan M.',
            listingTitle: 'Sunlit 2BHK in Koramangala',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('street address'), findsWidgets);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chat-body')), 'See you at 11');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    await tester.pump();

    expect(find.text('See you at 11'), findsOneWidget);
    expect(find.textContaining('Kept on this device'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('chat-body')),
      'call 9876543210',
    );
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('chat-log')),
        matching: find.textContaining('9876543210'),
      ),
      findsNothing,
    );
    expect(find.textContaining('cannot carry contact'), findsOneWidget);

    await tester.tap(find.byKey(const Key('accept-visit-visit-incoming')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Accepted'), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('address_line'), findsNothing);
  });
}
