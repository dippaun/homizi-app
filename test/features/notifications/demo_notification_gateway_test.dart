import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/notifications/demo_notification_gateway.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';

void main() {
  const matchId = '88888888-8888-4888-8888-888888888801';

  test('demo match ids are synced once and contact ids are dropped', () async {
    final gateway = DemoNotificationGateway();
    final first = await gateway.load(
      demoMatchIds: ['demo-match-lst_koramangala', '9876543210', matchId],
    );
    final second = await gateway.load(
      demoMatchIds: ['demo-match-lst_koramangala', matchId],
    );

    expect(first.items.map((item) => item.matchId).toSet(), {
      'demo-match-lst_koramangala',
      matchId,
    });
    expect(second.items, hasLength(first.items.length));
    expect(
      second.items.every((item) => item.type == 'match' && item.unread),
      isTrue,
    );
  });

  test('marking read stays on the device', () async {
    final gateway = DemoNotificationGateway();
    final loaded = await gateway.load(demoMatchIds: ['demo-match-1']);
    final marked = await gateway.markRead(loaded.items.single.id);
    expect(marked.note, InboxCopy.demoMarked);
    expect(marked.note, isNot(InboxCopy.serverMarked));
    expect(marked.items.single.unread, isFalse);
    final again = await gateway.markAllRead();
    expect(again.note, InboxCopy.demoMarked);
  });

  test('a poisoned seed does not keep a phone as the match id', () async {
    final gateway = DemoNotificationGateway();
    gateway.seedRow({
      'id': 'poison',
      'type': '9876543210',
      'payload_minimal': {
        'phone': '9876543210',
        'address_line': '12 MG Road',
        'email': 'ada@example.test',
        'match_id': '9876543210',
      },
      'created_at': '2026-10-11T12:00:00Z',
    });
    final snapshot = await gateway.load();
    expect(snapshot.items.single.matchId, isNull);
    expect(
      noticeSentence(snapshot.items.single.type),
      'Something changed on a match.',
    );
    expect(
      noticeSentence(snapshot.items.single.type).contains('9876'),
      isFalse,
    );
  });
}
