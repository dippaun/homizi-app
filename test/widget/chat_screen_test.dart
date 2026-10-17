import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/analytics/demo_analytics_gateway.dart';
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
    expect(find.textContaining('99 Fictional'), findsNothing);
  });

  testWidgets('the street address is hidden until the visit is accepted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
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
        addressLine: '99 Fictional Cross',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [threadGatewayProvider.overrideWith((ref) => gateway)],
        child: const MaterialApp(
          home: ChatScreen(matchId: 'match-1', otherName: 'Rohan M.'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('99 Fictional Cross'), findsNothing);
    expect(
      find.byKey(const Key('propose-visit-visit-incoming')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('accept-visit-visit-incoming')));
    await tester.pump();
    await tester.pump();

    expect(find.text('99 Fictional Cross'), findsOneWidget);
    expect(
      find.textContaining('shown only after this visit was accepted'),
      findsOneWidget,
    );
    expect(find.textContaining('address_line'), findsNothing);

    await tester.tap(find.byKey(const Key('complete-visit-visit-incoming')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('99 Fictional Cross'), findsOneWidget);
  });

  testWidgets('a live insert is shown and contact text stays hidden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _LiveGateway();
    const config = AppConfig(
      environment: AppEnvironment.staging,
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'sb_publishable_example',
      policyVersion: '2026-10-11-draft',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          threadGatewayProvider.overrideWith((ref) => gateway),
          analyticsGatewayProvider.overrideWith(
            (ref) => DemoAnalyticsGateway(optedOut: () => false),
          ),
        ],
        child: const MaterialApp(
          home: ChatScreen(matchId: 'match-1', otherName: 'Rohan M.'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('arrive as they are sent'), findsOneWidget);

    gateway.controller.add(
      ChatMessage(
        id: 'live-1',
        senderId: 'demo-host',
        body: 'Saturday morning works.',
        createdAt: DateTime.utc(2026, 10, 16, 4),
        mine: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Saturday morning works.'), findsOneWidget);

    gateway.controller.add(
      ChatMessage(
        id: 'live-2',
        senderId: 'demo-host',
        body: 'call 9876543210',
        createdAt: DateTime.utc(2026, 10, 16, 4, 5),
        mine: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('chat-log')),
        matching: find.textContaining('9876543210'),
      ),
      findsNothing,
    );
    expect(find.textContaining('hidden because it included'), findsOneWidget);
    await gateway.controller.close();
  });
}

class _LiveGateway extends DemoThreadGateway {
  final controller = StreamController<ChatMessage>.broadcast();

  @override
  Stream<ChatMessage> watchMessages(String matchId) => controller.stream;
}
