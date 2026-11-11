class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.mine,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool mine;

  /// When the other person has a later message, or this device opened the thread.
  final DateTime? readAt;

  ChatMessage copyWith({DateTime? readAt}) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      body: body,
      createdAt: createdAt,
      mine: mine,
      readAt: readAt ?? this.readAt,
    );
  }
}

/// One row in the conversations list. Contact fields are never included.
class ConversationPreview {
  const ConversationPreview({
    required this.matchId,
    required this.name,
    required this.lastMessage,
    required this.lastAt,
    required this.unread,
    this.listingTitle,
    this.avatarUrl,
    this.otherUserId,
  });

  final String matchId;
  final String name;
  final String lastMessage;
  final DateTime lastAt;
  final int unread;
  final String? listingTitle;
  final String? avatarUrl;
  final String? otherUserId;
}

class VisitRequest {
  const VisitRequest({
    required this.id,
    required this.matchId,
    required this.requesterId,
    required this.slots,
    required this.status,
    required this.mine,
    this.addressLine,
  });

  final String id;
  final String matchId;
  final String requesterId;
  final List<DateTime> slots;
  final String status;
  final bool mine;

  /// Street line from `get_visit_address`. Null until the visit is accepted.
  final String? addressLine;

  bool get isOpen => status == 'requested' || status == 'rescheduled';
}

class ThreadSnapshot {
  const ThreadSnapshot({
    required this.messages,
    required this.visits,
    this.conversationId,
    this.note,
  });

  final String? conversationId;
  final List<ChatMessage> messages;
  final List<VisitRequest> visits;
  final String? note;

  static const empty = ThreadSnapshot(messages: [], visits: []);

  /// Keeps one row per id. A repeat delivery replaces the stored body.
  ThreadSnapshot withMessage(ChatMessage message) {
    final index = messages.indexWhere((item) => item.id == message.id);
    if (index >= 0) {
      final next = [...messages];
      next[index] = message;
      return ThreadSnapshot(
        conversationId: conversationId,
        messages: next,
        visits: visits,
        note: note,
      );
    }
    return ThreadSnapshot(
      conversationId: conversationId,
      messages: [...messages, message],
      visits: visits,
      note: note,
    );
  }
}

abstract final class ThreadCopy {
  static const demoSaved =
      'Kept on this device. The server did not store this.';
  static const serverMessage =
      'Message sent. Contact details stay out of chat.';
  static const serverVisit =
      'Visit requested. The street address is not part of this request.';
  static const serverVisitUpdate =
      'Visit updated. The street address is still not shown here.';
  static const contactRejected =
      'Remove the phone number or email before sending. Chat cannot carry contact details.';
}
