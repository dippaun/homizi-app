import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/opened_direct_chats.dart';

void main() {
  test('a server row hides the remembered copy of the same person', () {
    const poster = '22222222-2222-4222-8222-222222222222';
    final server = ConversationPreview(
      matchId: '33333333-3333-4333-8333-333333333333',
      name: 'Asha V.',
      otherUserId: poster,
      lastMessage: 'The room is free.',
      lastAt: DateTime.utc(2026, 11, 21, 9),
      unread: 1,
    );
    final opened = OpenedDirectChat(
      otherUserId: poster,
      name: 'Asha V.',
      openedAt: DateTime.utc(2026, 11, 21, 8),
      conversationId: server.matchId,
    );
    final rows = mergeOpenedDirectChats([server], [opened]);
    expect(rows, hasLength(1));
    expect(rows.single.lastMessage, 'The room is free.');
  });

  test('a new direct thread is listed before the server has it', () {
    final opened = OpenedDirectChat(
      otherUserId: 'demo-host-rohan',
      name: 'Rohan M.',
      openedAt: DateTime.utc(2026, 11, 21, 10),
      listingTitle: 'Sunlit 2BHK in Koramangala',
    );
    final rows = mergeOpenedDirectChats(const [], [opened]);
    expect(rows.single.matchId, 'direct:demo-host-rohan');
    expect(rows.single.name, 'Rohan M.');
    expect(rows.single.listingTitle, 'Sunlit 2BHK in Koramangala');
    expect(rows.single.lastMessage, contains('No messages yet'));
  });
}
