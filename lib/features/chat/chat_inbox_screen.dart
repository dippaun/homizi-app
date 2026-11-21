import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/supabase/missing_relation.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_home_bar.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/chat/chat_repository.dart';
import 'package:homizi/features/chat/domain/chat_format.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/open_profile_chat.dart';
import 'package:homizi/features/chat/thread_gateway.dart';
import 'package:homizi/features/chat/thread_providers.dart';
import 'package:homizi/features/post_property/partner_property_chats.dart';
import 'package:homizi/features/post_property/partner_shell.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// Conversations for the signed-in person, or the on-device demo when there
/// is no session. Opening a row uses the same thread as match chat.
class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({this.embedded = false, super.key});

  /// Hides the app bar when the inbox sits inside the tenant Likes tab.
  final bool embedded;

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  final _search = TextEditingController();
  var _loading = true;
  String? _error;
  List<ConversationPreview> _rows = const [];
  StreamSubscription<void>? _live;
  StreamSubscription<void>? _direct;

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_live?.cancel());
    unawaited(_direct?.cancel());
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _rowsForInbox();
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = rows;
        _loading = false;
        _error = null;
      });
      _bind();
    } on ThreadFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } on ChatFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<List<ConversationPreview>> _rowsForInbox() async {
    final gateway = ref.read(threadGatewayProvider);
    final repo = ref.read(chatRepositoryProvider);
    if (repo == null) {
      return gateway.listConversations();
    }
    try {
      final remote = await repo.listConversations();
      final local = await gateway.listConversations();
      final seen = <String>{
        for (final row in remote)
          if (row.otherUserId != null) row.otherUserId!,
      };
      return [
        ...remote,
        for (final row in local)
          if (!isUuid(row.matchId) &&
              (row.otherUserId == null || seen.add(row.otherUserId!)))
            row,
      ];
    } on ChatFailure catch (error) {
      if (isMissingRelation(error) || error.message == unavailableYetMessage) {
        return gateway.listConversations();
      }
      rethrow;
    }
  }

  void _bind() {
    unawaited(_live?.cancel());
    unawaited(_direct?.cancel());
    _live = ref
        .read(threadGatewayProvider)
        .watchInbox()
        .listen((_) => unawaited(_load()), onError: (_) {});
    final repo = ref.read(chatRepositoryProvider);
    if (repo != null) {
      _direct = repo.watchInbox().listen(
        (_) => unawaited(_load()),
        onError: (_) {},
      );
    }
  }

  List<ConversationPreview> get _visible {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _rows;
    }
    return [
      for (final row in _rows)
        if (row.name.toLowerCase().contains(query) ||
            row.lastMessage.toLowerCase().contains(query) ||
            (row.listingTitle?.toLowerCase().contains(query) ?? false))
          row,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final partnerDesk =
        ref.watch(partnerShellProvider) &&
        ref.watch(currentRoleProvider) == HomiziRole.broker;
    if (partnerDesk && !widget.embedded) {
      return const PartnerPropertyChats();
    }
    final now = DateTime.now();
    final visible = _visible;
    return MinTouchScope(
      child: Scaffold(
        key: const Key('chat-inbox-screen'),
        backgroundColor: HomiziColors.white,
        appBar: widget.embedded
            ? null
            : const HomiziHomeBar(profileKey: Key('chat-tab-avatar')),
        body: _loading
            ? const LoadingState(message: 'Opening the conversation…')
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextField(
                      key: const Key('chat-inbox-search'),
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: homiziText(context, 'Search conversations'),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: HomiziColors.muted,
                        ),
                        filled: true,
                        fillColor: HomiziColors.mist,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: HomiziColors.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(
                      homiziText(
                        context,
                        'Messages stay on Homizi. A phone number, an email, or a WhatsApp link is not sent.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HomiziColors.muted,
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: LiveNotice(message: homiziText(context, _error!)),
                    ),
                  Expanded(
                    child: visible.isEmpty
                        ? EmptyState(
                            key: const Key('chat-inbox-empty'),
                            title: _rows.isEmpty
                                ? 'No chats yet'
                                : 'No conversations match that search.',
                            message: _rows.isEmpty
                                ? 'A chat opens after you and someone else both agree. Phone numbers stay out of it.'
                                : 'Try a name, a listing, or a few words from the last message.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                            itemCount: visible.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: HomiziColors.line,
                            ),
                            itemBuilder: (context, index) {
                              final row = visible[index];
                              final name = containsContactText(row.name)
                                  ? 'Match'
                                  : row.name;
                              final title =
                                  row.listingTitle != null &&
                                      !containsContactText(row.listingTitle!)
                                  ? row.listingTitle!
                                  : null;
                              return InkWell(
                                key: Key('chat-thread-${row.matchId}'),
                                onTap: () {
                                  final other = row.otherUserId;
                                  if (other != null &&
                                      other.isNotEmpty &&
                                      isUuid(other)) {
                                    unawaited(
                                      openProfileChat(
                                        context,
                                        ref,
                                        otherUserId: other,
                                        name: name,
                                        avatarUrl: row.avatarUrl,
                                        listingId: row.listingId,
                                        listingTitle: title,
                                      ),
                                    );
                                    return;
                                  }
                                  context.push(
                                    RoutePaths.inboxChat(
                                      row.matchId,
                                      name: name,
                                      title: title,
                                      otherUserId: row.otherUserId,
                                      avatar: row.avatarUrl,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      HostAvatar(
                                        name: name,
                                        photoRef: row.avatarUrl,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              homiziText(context, name),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: HomiziColors.ink,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            if (title != null)
                                              Text(
                                                homiziText(context, title),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: HomiziColors.muted,
                                                ),
                                              ),
                                            Text(
                                              homiziText(
                                                context,
                                                row.lastMessage,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: HomiziColors.inkSoft,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            formatChatListTime(row.lastAt, now),
                                            style: const TextStyle(
                                              color: HomiziColors.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (row.unread > 0) ...[
                                            const SizedBox(height: 6),
                                            _UnreadBadge(
                                              count: row.unread,
                                              badgeKey: Key(
                                                'chat-unread-${row.matchId}',
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.badgeKey});

  final int count;
  final Key badgeKey;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return DecoratedBox(
      key: badgeKey,
      decoration: const BoxDecoration(
        color: HomiziColors.accent,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
