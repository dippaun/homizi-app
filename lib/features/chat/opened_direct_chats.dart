import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';

/// A thread opened from Message before the inbox has reloaded it.
class OpenedDirectChat {
  const OpenedDirectChat({
    required this.otherUserId,
    required this.name,
    required this.openedAt,
    this.avatarUrl,
    this.listingId,
    this.listingTitle,
    this.conversationId,
  });

  final String otherUserId;
  final String name;
  final DateTime openedAt;
  final String? avatarUrl;
  final String? listingId;
  final String? listingTitle;

  /// Server conversation id after get_or_create_direct_conversation.
  final String? conversationId;

  ConversationPreview toPreview() {
    final serverId = conversationId?.trim() ?? '';
    return ConversationPreview(
      matchId: isUuid(serverId) ? serverId : 'direct:$otherUserId',
      name: name.trim().isEmpty ? 'Chat' : name.trim(),
      listingTitle: listingTitle,
      avatarUrl: avatarUrl,
      otherUserId: otherUserId,
      listingId: listingId,
      lastMessage:
          'No messages yet. Say hello without a phone number or an email address.',
      lastAt: openedAt,
      unread: 0,
    );
  }
}

class OpenedDirectChats extends Notifier<List<OpenedDirectChat>> {
  @override
  List<OpenedDirectChat> build() => const [];

  void remember({
    required String otherUserId,
    required String name,
    String? avatarUrl,
    String? listingId,
    String? listingTitle,
    String? conversationId,
  }) {
    final id = otherUserId.trim();
    if (id.isEmpty) {
      return;
    }
    OpenedDirectChat? previous;
    for (final row in state) {
      if (row.otherUserId == id) {
        previous = row;
        break;
      }
    }
    final next = OpenedDirectChat(
      otherUserId: id,
      name: name,
      openedAt: previous?.openedAt ?? DateTime.now().toUtc(),
      avatarUrl: avatarUrl ?? previous?.avatarUrl,
      listingId: listingId ?? previous?.listingId,
      listingTitle: listingTitle ?? previous?.listingTitle,
      conversationId: conversationId ?? previous?.conversationId,
    );
    state = [
      next,
      for (final row in state)
        if (row.otherUserId != id) row,
    ];
  }
}

final openedDirectChatsProvider =
    NotifierProvider<OpenedDirectChats, List<OpenedDirectChat>>(
      OpenedDirectChats.new,
    );

/// Keeps a Message thread visible when the server list has not returned it yet.
List<ConversationPreview> mergeOpenedDirectChats(
  List<ConversationPreview> rows,
  List<OpenedDirectChat> opened,
) {
  final seen = <String>{
    for (final row in rows)
      if (row.otherUserId != null && row.otherUserId!.isNotEmpty)
        row.otherUserId!,
  };
  final merged = [
    ...rows,
    for (final chat in opened)
      if (seen.add(chat.otherUserId)) chat.toPreview(),
  ];
  merged.sort((a, b) => b.lastAt.compareTo(a.lastAt));
  return merged;
}
