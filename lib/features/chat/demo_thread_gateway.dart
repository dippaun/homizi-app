import 'dart:async';

import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/features/chat/demo_inbox.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/chat/domain/demo_reply.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/thread_gateway.dart';

/// Device-only thread used when the project URL or public key is empty,
/// or when nobody is signed in. A phone number or email is refused here too.
class DemoThreadGateway implements ThreadGateway {
  DemoThreadGateway({
    this.userId = 'demo-self',
    this.autoReply = false,
    bool seedDemoInbox = false,
    DateTime? now,
  }) {
    if (!seedDemoInbox) {
      return;
    }
    for (final seed in demoInboxSeeds(now ?? DateTime.now())) {
      _messages[seed.matchId] = seed.messages;
      _names[seed.matchId] = seed.name;
      _titles[seed.matchId] = seed.listingTitle;
      _avatars[seed.matchId] = seed.avatarUrl;
      _others[seed.matchId] = seed.otherUserId;
    }
  }

  final String userId;

  /// When true, a plausible reply is stored with the message that was just sent.
  final bool autoReply;

  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, List<VisitRequest>> _visits = {};
  final Map<String, String> _hiddenAddresses = {};
  final Map<String, String> _names = {};
  final Map<String, String> _titles = {};
  final Map<String, String> _avatars = {};
  final Map<String, String> _others = {};
  final Map<String, DateTime> _readThrough = {};
  final _inboxEvents = StreamController<void>.broadcast();

  void seedMessage({
    required String matchId,
    required String body,
    required bool mine,
    DateTime? createdAt,
    String? senderId,
  }) {
    final message = ChatMessage(
      id: newLocalId(),
      senderId: senderId ?? (mine ? userId : 'demo-host'),
      body: body,
      createdAt: (createdAt ?? DateTime.utc(2026, 10, 12, 9, 15)).toUtc(),
      mine: mine,
    );
    final current = _messages[matchId] ?? <ChatMessage>[];
    _messages[matchId] = [...current, message];
  }

  void seedVisit(VisitRequest visit) {
    final current = _visits[visit.matchId] ?? [];
    if (visit.addressLine != null && visit.addressLine!.trim().isNotEmpty) {
      _hiddenAddresses[visit.id] = visit.addressLine!.trim();
    }
    _visits[visit.matchId] = [
      ...current,
      VisitRequest(
        id: visit.id,
        matchId: visit.matchId,
        requesterId: visit.requesterId,
        slots: visit.slots,
        status: visit.status,
        mine: visit.mine,
      ),
    ];
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
    final stored = <ChatMessage>[
      ...(_messages[matchId] ?? const <ChatMessage>[]),
      message,
    ];
    if (autoReply) {
      final reply = ChatMessage(
        id: newLocalId(),
        senderId: _others[matchId] ?? 'demo-host',
        body: demoReplyFor(trimmed),
        createdAt: message.createdAt.add(const Duration(seconds: 1)),
        mine: false,
      );
      stored.add(reply);
    }
    _messages[matchId] = stored;
    _ping();
    return _snapshot(matchId, ThreadCopy.demoSaved);
  }

  @override
  Future<List<ConversationPreview>> listConversations() async {
    final rows = <ConversationPreview>[];
    for (final entry in _messages.entries) {
      final messages = entry.value;
      if (messages.isEmpty && !_names.containsKey(entry.key)) {
        continue;
      }
      final last = messages.isEmpty ? null : messages.last;
      rows.add(
        ConversationPreview(
          matchId: entry.key,
          name: _names[entry.key] ?? 'Match',
          listingTitle: _titles[entry.key],
          avatarUrl: _avatars[entry.key],
          otherUserId: _others[entry.key],
          lastMessage: last == null
              ? 'No messages yet. Say hello without a phone number or an email address.'
              : displayMessageBody(last.body),
          lastAt: last?.createdAt ?? DateTime.utc(2026, 10, 12),
          unread: _unread(entry.key, messages),
        ),
      );
    }
    rows.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return rows;
  }

  @override
  Future<void> markRead(String matchId) async {
    _readThrough[matchId] = DateTime.now().toUtc().add(
      const Duration(seconds: 2),
    );
    _ping();
  }

  @override
  Stream<void> watchInbox() => _inboxEvents.stream;

  int _unread(String matchId, List<ChatMessage> messages) {
    final through = _readThrough[matchId];
    if (through != null) {
      return messages
          .where(
            (message) => !message.mine && message.createdAt.isAfter(through),
          )
          .length;
    }
    DateTime? lastMine;
    for (final message in messages) {
      if (message.mine) {
        lastMine = message.createdAt;
      }
    }
    if (lastMine == null) {
      return messages.where((message) => !message.mine).length;
    }
    return messages
        .where(
          (message) => !message.mine && message.createdAt.isAfter(lastMine!),
        )
        .length;
  }

  void _ping() {
    if (!_inboxEvents.isClosed) {
      _inboxEvents.add(null);
    }
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
  Future<ThreadSnapshot> proposeVisitTime(
    String visitId,
    List<DateTime> slots,
  ) async {
    visitSlotPayload(slots);
    String? matchId;
    for (final entry in _visits.entries) {
      for (var index = 0; index < entry.value.length; index++) {
        final visit = entry.value[index];
        if (visit.id != visitId) {
          continue;
        }
        if (visit.status != 'requested' && visit.status != 'rescheduled') {
          throw ThreadFailure(threadErrorMessage('closed'));
        }
        final nextStatus = visit.requesterId == userId
            ? 'requested'
            : 'rescheduled';
        final copy = [...entry.value];
        copy[index] = VisitRequest(
          id: visit.id,
          matchId: visit.matchId,
          requesterId: visit.requesterId,
          slots: [for (final slot in slots) slot.toUtc()],
          status: nextStatus,
          mine: visit.mine,
        );
        _visits[entry.key] = copy;
        matchId = entry.key;
      }
    }
    if (matchId == null) {
      throw ThreadFailure(threadErrorMessage('not_participant'));
    }
    return _snapshot(matchId, ThreadCopy.demoSaved);
  }

  @override
  Future<ThreadSnapshot> respondVisit(String visitId, String status) async {
    if (status != 'accepted' &&
        status != 'declined' &&
        status != 'cancelled' &&
        status != 'completed') {
      throw ThreadFailure(threadErrorMessage('not_allowed'));
    }
    String? matchId;
    for (final entry in _visits.entries) {
      for (var index = 0; index < entry.value.length; index++) {
        final visit = entry.value[index];
        if (visit.id != visitId) {
          continue;
        }
        final requester = visit.requesterId == userId;
        final allowed = switch (visit.status) {
          'accepted' => status == 'completed',
          'requested' =>
            (status == 'cancelled' && requester) ||
                ((status == 'accepted' || status == 'declined') && !requester),
          'rescheduled' =>
            requester &&
                (status == 'accepted' ||
                    status == 'declined' ||
                    status == 'cancelled'),
          _ => false,
        };
        if (!allowed) {
          throw ThreadFailure(
            threadErrorMessage(
              visit.status == 'requested' ||
                      visit.status == 'rescheduled' ||
                      visit.status == 'accepted'
                  ? 'not_allowed'
                  : 'closed',
            ),
          );
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
      visits: [
        for (final visit in _visits[matchId] ?? const <VisitRequest>[])
          VisitRequest(
            id: visit.id,
            matchId: visit.matchId,
            requesterId: visit.requesterId,
            slots: visit.slots,
            status: visit.status,
            mine: visit.requesterId == userId,
            addressLine: _visibleAddress(visit),
          ),
      ],
      note: note,
    );
  }

  String? _visibleAddress(VisitRequest visit) {
    if (visit.status != 'accepted' && visit.status != 'completed') {
      return null;
    }
    final line = _hiddenAddresses[visit.id];
    if (line == null || line.trim().isEmpty) {
      return null;
    }
    return line.trim();
  }
}
