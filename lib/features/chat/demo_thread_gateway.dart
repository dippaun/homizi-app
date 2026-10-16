import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/thread_gateway.dart';

/// Device-only thread used when the project URL or public key is empty.
/// A phone number or email is refused here too, so demo mode cannot show it.
class DemoThreadGateway implements ThreadGateway {
  DemoThreadGateway({this.userId = 'demo-self'});

  final String userId;
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, List<VisitRequest>> _visits = {};

  void seedMessage({
    required String matchId,
    required String body,
    required bool mine,
  }) {
    final message = ChatMessage(
      id: newLocalId(),
      senderId: mine ? userId : 'demo-host',
      body: body,
      createdAt: DateTime.utc(2026, 10, 12, 9, 15),
      mine: mine,
    );
    final current = _messages[matchId] ?? <ChatMessage>[];
    _messages[matchId] = [...current, message];
  }

  void seedVisit(VisitRequest visit) {
    final current = _visits[visit.matchId] ?? [];
    _visits[visit.matchId] = [...current, visit];
  }

  @override
  Future<ThreadSnapshot> load(String matchId) async {
    return _snapshot(matchId, null);
  }

  @override
  Stream<ChatMessage> watchMessages(String matchId) =>
      const Stream<ChatMessage>.empty();

  @override
  Future<ThreadSnapshot> send(String matchId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > 4000) {
      throw const ThreadFailure(ThreadCopy.contactRejected);
    }
    if (containsContactText(trimmed)) {
      throw const ThreadFailure(ThreadCopy.contactRejected);
    }
    final message = ChatMessage(
      id: newLocalId(),
      senderId: userId,
      body: trimmed,
      createdAt: DateTime.now().toUtc(),
      mine: true,
    );
    _messages[matchId] = [...(_messages[matchId] ?? []), message];
    return _snapshot(matchId, ThreadCopy.demoSaved);
  }

  @override
  Future<ThreadSnapshot> requestVisit(
    String matchId,
    List<DateTime> slots,
  ) async {
    if (slots.isEmpty || slots.length > 3) {
      throw ThreadFailure(threadErrorMessage('slots'));
    }
    visitSlotPayload(slots);
    final visit = VisitRequest(
      id: newLocalId(),
      matchId: matchId,
      requesterId: userId,
      slots: [for (final slot in slots) slot.toUtc()],
      status: 'requested',
      mine: true,
    );
    _visits[matchId] = [...(_visits[matchId] ?? []), visit];
    return _snapshot(matchId, ThreadCopy.demoSaved);
  }

  @override
  Future<ThreadSnapshot> respondVisit(String visitId, String status) async {
    if (status != 'accepted' && status != 'declined' && status != 'cancelled') {
      throw ThreadFailure(threadErrorMessage('not_allowed'));
    }
    String? matchId;
    for (final entry in _visits.entries) {
      for (var index = 0; index < entry.value.length; index++) {
        final visit = entry.value[index];
        if (visit.id != visitId) {
          continue;
        }
        if (visit.status != 'requested') {
          throw ThreadFailure(threadErrorMessage('closed'));
        }
        final cancelling = status == 'cancelled' && visit.requesterId == userId;
        final deciding =
            (status == 'accepted' || status == 'declined') &&
            visit.requesterId != userId;
        if (!cancelling && !deciding) {
          throw ThreadFailure(threadErrorMessage('not_allowed'));
        }
        final next = VisitRequest(
          id: visit.id,
          matchId: visit.matchId,
          requesterId: visit.requesterId,
          slots: visit.slots,
          status: status,
          mine: visit.mine,
        );
        final copy = [...entry.value];
        copy[index] = next;
        _visits[entry.key] = copy;
        matchId = entry.key;
      }
    }
    if (matchId == null) {
      throw ThreadFailure(threadErrorMessage('not_participant'));
    }
    return _snapshot(matchId, ThreadCopy.demoSaved);
  }

  ThreadSnapshot _snapshot(String matchId, String? note) {
    final messages = [
      for (final message in _messages[matchId] ?? const <ChatMessage>[])
        ChatMessage(
          id: message.id,
          senderId: message.senderId,
          body: displayMessageBody(message.body),
          createdAt: message.createdAt,
          mine: message.senderId == userId,
        ),
    ];
    return ThreadSnapshot(
      conversationId: 'demo-conversation-$matchId',
      messages: messages,
      visits: _visits[matchId] ?? const [],
      note: note,
    );
  }
}
