import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/notifications/demo_notification_gateway.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';
import 'package:homizi/features/notifications/domain/notice_category.dart';

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

  test('a saved search seed keeps the search id only', () async {
    const searchId = 'a20a20a2-a20a-420a-820a-a20a20a20b01';
    final gateway = DemoNotificationGateway();
    gateway.seedRow({
      'id': 'notice-search',
      'type': 'saved_search_match',
      'payload_minimal': {
        'saved_search_id': searchId,
        'title': 'Sunlit 2BHK in Koramangala',
        'phone': '9876543210',
        'email': 'ada@example.test',
        'address_line': '12 MG Road',
        'property_id': 'a20a20a2-a20a-420a-820a-a20a20a20a02',
      },
      'created_at': '2026-10-20T12:00:00Z',
    });
    final snapshot = await gateway.load();
    expect(snapshot.items.single.savedSearchId, searchId);
    expect(snapshot.items.single.propertyId, isNull);
    expect(snapshot.items.single.matchId, isNull);
    expect(
      categoryForType(snapshot.items.single.type),
      NoticeCategory.listings,
    );
    expect(
      noticeSentence(snapshot.items.single.type),
      'A saved search has new homes.',
    );

    final marked = await gateway.markRead(snapshot.items.single.id);
    expect(marked.items.single.savedSearchId, searchId);
    expect(marked.items.single.unread, isFalse);
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
