import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/notifications/demo_notification_gateway.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';
import 'package:homizi/features/notifications/notification_providers.dart';
import 'package:homizi/features/notifications/notifications_screen.dart';

void main() {
  testWidgets('the inbox hides contact fields and marks read on device', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = DemoNotificationGateway();
    gateway.seedRow({
      'id': 'notice-1',
      'type': 'message',
      'payload_minimal': {
        'phone': '9876543210',
        'address_line': '12 MG Road',
        'email': 'ada@example.test',
        'match_id': '88888888-8888-4888-8888-888888888801',
      },
      'created_at': '2026-10-11T12:00:00Z',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationGatewayProvider.overrideWith((ref) => gateway)],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notification-list')), findsOneWidget);
    expect(find.text('New message on a match.'), findsOneWidget);
    expect(find.textContaining('9876543210'), findsNothing);
    expect(find.textContaining('address_line'), findsNothing);
    expect(find.textContaining('12 MG Road'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    expect(
      find.byKey(const Key('open-chat-from-notice-notice-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('mark-read-notice-1')));
    await tester.pumpAndSettle();

    expect(find.text(InboxCopy.demoMarked), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);
  });

  testWidgets('an empty inbox explains what will arrive', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationGatewayProvider.overrideWith(
            (ref) => DemoNotificationGateway(),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(InboxCopy.empty), findsOneWidget);
    expect(find.text(InboxCopy.safety), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });
}
