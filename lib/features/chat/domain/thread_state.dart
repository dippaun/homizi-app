class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.mine,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool mine;
}

class VisitRequest {
  const VisitRequest({
    required this.id,
    required this.matchId,
    required this.requesterId,
    required this.slots,
    required this.status,
    required this.mine,
  });

  final String id;
  final String matchId;
  final String requesterId;
  final List<DateTime> slots;
  final String status;
  final bool mine;

  bool get isOpen => status == 'requested';
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
