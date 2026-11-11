import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/chat/chat_inbox_screen.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/chat/demo_thread_gateway.dart';
import 'package:homizi/features/chat/thread_providers.dart';

void main() {
  testWidgets('the inbox lists threads and search narrows them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = DemoThreadGateway(
      seedDemoInbox: true,
      now: DateTime(2026, 11, 11, 10),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [threadGatewayProvider.overrideWith((ref) => gateway)],
        child: const MaterialApp(home: ChatInboxScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Ananya Iyer'), findsOneWidget);
    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);
    expect(find.text('Priya Nair'), findsOneWidget);
    expect(
      find.byKey(const Key('chat-unread-demo-chat-ananya')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('chat-unread-demo-chat-priya')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat-unread-demo-chat-rohan')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('chat-inbox-search')),
      'andheri',
    );
    await tester.pump();

    expect(find.text('Priya Nair'), findsOneWidget);
    expect(find.text('Ananya Iyer'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('sending adds a bubble and a reply, and a number stays unsent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = DemoThreadGateway(autoReply: true);
    gateway.seedMessage(
      matchId: 'match-1',
      body: 'The 2BHK is free from 1 Dec.',
      mine: false,
      createdAt: DateTime.utc(2026, 11, 10, 4),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [threadGatewayProvider.overrideWith((ref) => gateway)],
        child: const MaterialApp(
          home: ChatScreen(
            matchId: 'match-1',
            otherName: 'Ananya Iyer',
            listingTitle: 'Sunlit 2BHK in Koramangala',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);
    expect(find.text('The 2BHK is free from 1 Dec.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('chat-body')),
      'Is the room still available?',
    );
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Is the room still available?'), findsOneWidget);
    expect(find.textContaining('4th floor'), findsOneWidget);
    expect(find.textContaining('Kept on this device'), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('chat-log')),
        matching: find.textContaining('+91'),
      ),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('chat-body')),
      'call me on nine eight seven six five four three two one zero',
    );
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();

    expect(find.byKey(const Key('chat-contact-warning')), findsOneWidget);
    final warning = tester.widget<Text>(
      find.byKey(const Key('chat-contact-warning')),
    );
    expect(warning.style?.color, HomiziColors.brandDeepOrange);
    expect(find.textContaining('cannot carry contact'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('chat-log')),
        matching: find.textContaining('nine eight'),
      ),
      findsNothing,
    );

    final stored = await gateway.load('match-1');
    expect(
      stored.messages.any((message) => message.body.contains('nine eight')),
      isFalse,
    );
  });

  testWidgets('opening a thread clears its unread count', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = DemoThreadGateway(
      seedDemoInbox: true,
      now: DateTime(2026, 11, 11, 10),
    );
    final before = await gateway.listConversations();
    final ananya = before.firstWhere(
      (row) => row.matchId == 'demo-chat-ananya',
    );
    expect(ananya.unread, greaterThan(0));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [threadGatewayProvider.overrideWith((ref) => gateway)],
        child: const MaterialApp(
          home: ChatScreen(
            matchId: 'demo-chat-ananya',
            otherName: 'Ananya Iyer',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final after = await gateway.listConversations();
    expect(
      after.firstWhere((row) => row.matchId == 'demo-chat-ananya').unread,
      0,
    );
  });
}
