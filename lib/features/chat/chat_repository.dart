import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/supabase/missing_relation.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/listings/domain/poster_kind.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatFailure implements Exception {
  const ChatFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// On-device thread for a demo id or a guest preview.
/// A non-uuid is never sent to Postgres from here.
class LocalDirectChatStore {
  final _threads = <String, List<ChatMessage>>{};
  final _controllers = <String, StreamController<List<ChatMessage>>>{};

  List<ChatMessage> messagesFor(String otherUserId) {
    return List<ChatMessage>.unmodifiable(
      _threads[otherUserId] ?? const <ChatMessage>[],
    );
  }

  Stream<List<ChatMessage>> watch(String otherUserId) {
    final controller = _controllers.putIfAbsent(
      otherUserId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(messagesFor(otherUserId));
      }
    });
    return controller.stream;
  }

  void send(String otherUserId, String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > 4000) {
      throw ChatFailure(threadErrorMessage('body'));
    }
    if (containsContactText(trimmed)) {
      throw const ChatFailure(ThreadCopy.contactRejected);
    }
    final now = DateTime.now().toUtc();
    _add(
      otherUserId,
      ChatMessage(
        id: 'local-${now.microsecondsSinceEpoch}',
        senderId: 'me',
        body: trimmed,
        createdAt: now,
        mine: true,
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      final current = _threads[otherUserId];
      if (current == null) {
        return;
      }
      final readAt = DateTime.now().toUtc();
      _threads[otherUserId] = [
        for (final message in current)
          if (message.mine) message.copyWith(readAt: readAt) else message,
      ];
      _add(
        otherUserId,
        ChatMessage(
          id: 'local-reply-${readAt.microsecondsSinceEpoch}',
          senderId: otherUserId,
          body: 'Got it. Chat stays on Homizi.',
          createdAt: readAt,
          mine: false,
        ),
      );
    });
  }

  void _add(String otherUserId, ChatMessage message) {
    final next = [...messagesFor(otherUserId), message];
    _threads[otherUserId] = next;
    final controller = _controllers[otherUserId];
    if (controller != null && !controller.isClosed) {
      controller.add(List<ChatMessage>.unmodifiable(next));
    }
  }

  void dispose() {
    for (final controller in _controllers.values) {
      unawaited(controller.close());
    }
  }
}

final localDirectChatsProvider = Provider<LocalDirectChatStore>((ref) {
  final store = LocalDirectChatStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Supabase conversations for two profiles. Null in demo mode.
final chatRepositoryProvider = Provider<ChatRepository?>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final session = ref.watch(sessionProvider);
  final signedIn =
      session.phase == SessionPhase.ready &&
      session.userId != null &&
      isUuid(session.userId!);
  if (!config.connectsToSupabase || forceDemo || !signedIn) {
    return null;
  }
  return ChatRepository(Supabase.instance.client);
});

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  /// Opens the direct thread. [otherUserId] and [listingId] must be uuids.
  /// A demo id throws before any request, so Postgres never sees `22P02`.
  Future<String> openDirect({
    required String otherUserId,
    String? listingId,
  }) async {
    if (!isUuid(otherUserId)) {
      throw const ChatFailure('This sample chat stays on this device.');
    }
    final listing = listingId != null && isUuid(listingId) ? listingId : null;
    try {
      final raw = await _client.rpc<dynamic>(
        'get_or_create_direct_conversation',
        params: {'other_user': otherUserId, 'listing': listing},
      );
      final id = _uuid(raw);
      if (!isUuid(id)) {
        throw const ChatFailure('The server did not open the chat.');
      }
      return id;
    } on ChatFailure {
      rethrow;
    } on Object catch (error) {
      throw ChatFailure(_message(error));
    }
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    if (!isUuid(conversationId)) {
      throw const ChatFailure('This sample chat stays on this device.');
    }
    final user = _user();
    try {
      final rows = await _client
          .from('messages')
          .select(
            'id, conversation_id, sender_id, body, created_at, read_at, status',
          )
          .eq('conversation_id', conversationId)
          .order('created_at');
      return [for (final raw in rows) ?chatMessageFromRealtime(raw, user.id)];
    } on Object catch (error) {
      throw ChatFailure(_message(error));
    }
  }

  Future<void> send(String conversationId, String body) async {
    if (!isUuid(conversationId)) {
      throw const ChatFailure('This sample chat stays on this device.');
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > 4000) {
      throw ChatFailure(threadErrorMessage('body'));
    }
    if (containsContactText(trimmed)) {
      throw const ChatFailure(ThreadCopy.contactRejected);
    }
    final user = _user();
    try {
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'body': trimmed,
      });
    } on Object catch (error) {
      throw ChatFailure(_message(error));
    }
  }

  Future<void> markRead(String conversationId) async {
    if (!isUuid(conversationId)) {
      return;
    }
    _user();
    try {
      await _client.rpc<dynamic>(
        'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
    } on Object catch (error) {
      throw ChatFailure(_message(error));
    }
  }

  Stream<ChatMessage> watchMessages(String conversationId) {
    if (!isUuid(conversationId)) {
      return const Stream<ChatMessage>.empty();
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      return Stream<ChatMessage>.error(
        ChatFailure(threadErrorMessage('unauthenticated')),
      );
    }
    RealtimeChannel? channel;
    var cancelled = false;
    late final StreamController<ChatMessage> controller;
    controller = StreamController<ChatMessage>(
      onListen: () {
        final next = _client.channel('direct:$conversationId');
        void emit(PostgresChangePayload payload) {
          if (controller.isClosed) {
            return;
          }
          final rowConversation = payload.newRecord['conversation_id'];
          if (rowConversation != null && rowConversation != conversationId) {
            return;
          }
          final message = chatMessageFromRealtime(payload.newRecord, user.id);
          if (message != null) {
            controller.add(message);
          }
        }

        next
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
              ),
              callback: emit,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
              ),
              callback: emit,
            )
            .subscribe();
        if (cancelled) {
          unawaited(_client.removeChannel(next));
          return;
        }
        channel = next;
      },
      onCancel: () async {
        cancelled = true;
        final current = channel;
        channel = null;
        if (current != null) {
          await _client.removeChannel(current);
        }
      },
    );
    return controller.stream;
  }

  Stream<void> watchInbox() {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const Stream<void>.empty();
    }
    RealtimeChannel? channel;
    var cancelled = false;
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        final next = _client.channel('direct-inbox:${user.id}');
        next
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              callback: (_) {
                if (!controller.isClosed) {
                  controller.add(null);
                }
              },
            )
            .subscribe();
        if (cancelled) {
          unawaited(_client.removeChannel(next));
          return;
        }
        channel = next;
      },
      onCancel: () async {
        cancelled = true;
        final current = channel;
        channel = null;
        if (current != null) {
          await _client.removeChannel(current);
        }
      },
    );
    return controller.stream;
  }

  Future<List<ConversationPreview>> listConversations() async {
    final user = _user();
    try {
      final memberRows = await _client
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', user.id);
      final conversationIds = <String>[
        for (final raw in memberRows)
          if (isUuid('${raw['conversation_id']}')) '${raw['conversation_id']}',
      ];
      if (conversationIds.isEmpty) {
        return const [];
      }
      final conversationRows = await _client
          .from('conversations')
          .select('id, last_message_at, listing_id, created_at')
          .inFilter('id', conversationIds);
      final otherRows = await _client
          .from('conversation_members')
          .select('conversation_id, user_id')
          .inFilter('conversation_id', conversationIds);
      final messageRows = await _client
          .from('messages')
          .select(
            'id, conversation_id, sender_id, body, created_at, read_at, status',
          )
          .inFilter('conversation_id', conversationIds)
          .order('created_at');
      final others = <String, String>{};
      for (final raw in otherRows) {
        final row = raw;
        final conversationId = row['conversation_id'];
        final memberId = row['user_id'];
        if (conversationId is String &&
            memberId is String &&
            memberId != user.id &&
            isUuid(memberId)) {
          others[conversationId] = memberId;
        }
      }
      final messages = <String, List<ChatMessage>>{};
      for (final raw in messageRows) {
        final row = raw;
        final conversationId = row['conversation_id'];
        final message = chatMessageFromRealtime(row, user.id);
        if (conversationId is String && message != null) {
          messages.putIfAbsent(conversationId, () => []).add(message);
        }
      }
      final otherIds = others.values.toSet();
      final names = await _names(otherIds);
      final avatars = await _avatars(otherIds);
      final titles = await _titles(otherIds);
      final roles = await _roles(otherIds);
      final listingIds = <String>[
        for (final raw in conversationRows)
          if (raw['listing_id'] is String && isUuid('${raw['listing_id']}'))
            '${raw['listing_id']}',
      ];
      final listingPosters = await _listingPosters(listingIds);
      final rows = <ConversationPreview>[];
      for (final raw in conversationRows) {
        final row = raw;
        final id = row['id'];
        if (id is! String || !isUuid(id)) {
          continue;
        }
        final other = others[id];
        final thread = messages[id] ?? const <ChatMessage>[];
        final last = thread.isEmpty ? null : thread.last;
        final unread = thread
            .where((message) => !message.mine && message.readAt == null)
            .length;
        final lastAt =
            DateTime.tryParse('${row['last_message_at']}')?.toUtc() ??
            last?.createdAt ??
            DateTime.tryParse('${row['created_at']}')?.toUtc() ??
            DateTime.now().toUtc();
        final listingId = row['listing_id'];
        rows.add(
          ConversationPreview(
            matchId: id,
            name: other == null ? 'Chat' : (names[other] ?? 'Chat'),
            listingTitle: other == null ? null : titles[other],
            avatarUrl: other == null ? null : avatars[other],
            otherUserId: other,
            lastMessage: last == null
                ? 'No messages yet. Say hello without a phone number or an email address.'
                : last.body,
            lastAt: lastAt,
            unread: unread,
            listingId: listingId is String && isUuid(listingId)
                ? listingId
                : null,
            posterKind:
                (listingId is String
                    ? listingPosters[listingId]
                    : null) ??
                (other == null
                    ? null
                    : posterKindFromProfileRole(roles[other])),
          ),
        );
      }
      rows.sort((a, b) => b.lastAt.compareTo(a.lastAt));
      return rows;
    } on Object catch (error) {
      throw ChatFailure(_message(error));
    }
  }

  Future<Map<String, String>> _roles(Set<String> ids) async {
    if (ids.isEmpty) {
      return const {};
    }
    try {
      final rows = await _client
          .from('profiles')
          .select('user_id, primary_role')
          .inFilter('user_id', ids.toList());
      final roles = <String, String>{};
      for (final raw in rows) {
        final id = raw['user_id'];
        final role = raw['primary_role'];
        if (id is String && role is String && role.trim().isNotEmpty) {
          roles[id] = role.trim();
        }
      }
      return roles;
    } on Object {
      return const {};
    }
  }

  Future<Map<String, String>> _listingPosters(List<String> ids) async {
    if (ids.isEmpty) {
      return const {};
    }
    try {
      final rows = await _client
          .from('properties')
          .select('id, listed_by, property_type')
          .inFilter('id', ids);
      final features = await _client
          .from('property_features')
          .select('property_id, value')
          .eq('feature_key', 'wizard:poster')
          .inFilter('property_id', ids);
      final stored = <String, String>{};
      for (final raw in features) {
        final id = raw['property_id'];
        final value = raw['value'];
        if (id is String && value is String) {
          stored[id] = value;
        }
      }
      final posters = <String, String>{};
      for (final raw in rows) {
        final id = raw['id'];
        if (id is! String) {
          continue;
        }
        posters[id] = posterKindFromSignals(
          stored: stored[id],
          listedBy: raw['listed_by'] is String ? raw['listed_by'] as String : null,
          propertyType: raw['property_type'] is String
              ? raw['property_type'] as String
              : null,
        );
      }
      return posters;
    } on Object {
      return const {};
    }
  }

  Future<Map<String, String>> _names(Set<String> ids) async {
    if (ids.isEmpty) {
      return const {};
    }
    final rows = await _client
        .from('profiles')
        .select('user_id, display_name')
        .inFilter('user_id', ids.toList());
    final names = <String, String>{};
    for (final raw in rows) {
      final row = raw;
      final id = row['user_id'];
      final name = row['display_name'];
      if (id is String &&
          name is String &&
          name.trim().isNotEmpty &&
          !containsContactText(name)) {
        names[id] = name.trim();
      }
    }
    return names;
  }

  Future<Map<String, String>> _avatars(Set<String> ids) async {
    if (ids.isEmpty) {
      return const {};
    }
    try {
      final rows = await _client
          .from('profiles')
          .select('user_id, avatar_path')
          .inFilter('user_id', ids.toList());
      final avatars = <String, String>{};
      for (final raw in rows) {
        final row = raw;
        final id = row['user_id'];
        final path = row['avatar_path'];
        if (id is String && path is String) {
          final trimmed = path.trim();
          if (trimmed.startsWith('http') || trimmed.startsWith('assets/')) {
            avatars[id] = trimmed;
          }
        }
      }
      return avatars;
    } on Object {
      return const {};
    }
  }

  Future<Map<String, String>> _titles(Set<String> ids) async {
    if (ids.isEmpty) {
      return const {};
    }
    try {
      final rows = await _client
          .from('properties')
          .select('host_user_id, title, status')
          .eq('status', 'published')
          .inFilter('host_user_id', ids.toList());
      final titles = <String, String>{};
      for (final raw in rows) {
        final row = raw;
        final id = row['host_user_id'];
        final title = row['title'];
        if (id is String &&
            title is String &&
            title.trim().isNotEmpty &&
            !containsContactText(title) &&
            !titles.containsKey(id)) {
          titles[id] = title.trim();
        }
      }
      return titles;
    } on Object {
      return const {};
    }
  }

  User _user() {
    final user = _client.auth.currentUser;
    if (user == null || !isUuid(user.id)) {
      throw ChatFailure(threadErrorMessage('unauthenticated'));
    }
    return user;
  }

  String _uuid(dynamic raw) {
    if (raw is String) {
      return raw;
    }
    return '';
  }

  String _message(Object error) {
    if (error is ChatFailure) {
      return error.message;
    }
    if (isMissingRelation(error)) {
      return unavailableYetMessage;
    }
    final offline = offlineFailureMessage(error);
    if (offline != null) {
      return offline;
    }
    final lower = error.toString().toLowerCase();
    if (lower.contains('22p02') ||
        lower.contains('invalid input syntax for type uuid')) {
      return 'This sample chat stays on this device.';
    }
    if (lower.contains('messages_no_contact') ||
        lower.contains('contains_contact') ||
        lower.contains('23514')) {
      return ThreadCopy.contactRejected;
    }
    if (lower.contains('blocked')) {
      return threadErrorMessage('blocked');
    }
    if (lower.contains('unauthenticated') || lower.contains('28000')) {
      return threadErrorMessage('unauthenticated');
    }
    if (lower.contains('not_participant')) {
      return threadErrorMessage('not_participant');
    }
    return 'The server did not save that.';
  }
}
