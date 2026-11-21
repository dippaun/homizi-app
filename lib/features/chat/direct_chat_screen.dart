import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/chat/chat_repository.dart';
import 'package:homizi/features/chat/domain/chat_format.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/host_greeting.dart';
import 'package:homizi/features/chat/opened_direct_chats.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Thread with one other profile. Realtime when both ids are uuids.
/// Demo and other non-uuid profiles stay in [LocalDirectChatStore].
class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({
    required this.otherUserId,
    this.otherName = 'Chat',
    this.avatarUrl,
    this.listingId,
    this.listingTitle,
    this.place,
    this.suggestGreeting = false,
    this.profilePath,
    super.key,
  });

  final String otherUserId;
  final String otherName;
  final String? avatarUrl;
  final String? listingId;
  final String? listingTitle;
  final String? place;
  final bool suggestGreeting;
  final String? profilePath;

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _body = TextEditingController();
  final _scroll = ScrollController();
  var _loading = true;
  var _busy = false;
  String? _note;
  String? _conversationId;
  var _local = true;
  List<ChatMessage> _messages = const [];
  StreamSubscription<List<ChatMessage>>? _localLive;
  StreamSubscription<ChatMessage>? _remoteLive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_open());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_localLive?.cancel());
    unawaited(_remoteLive?.cancel());
    _body.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _demoPerson => !isUuid(widget.otherUserId);

  void _remember({String? conversationId}) {
    ref
        .read(openedDirectChatsProvider.notifier)
        .remember(
          otherUserId: widget.otherUserId,
          name: widget.otherName,
          avatarUrl: widget.avatarUrl,
          listingId: widget.listingId,
          listingTitle: widget.listingTitle,
          conversationId: conversationId,
        );
  }

  Future<void> _open() async {
    final repo = ref.read(chatRepositoryProvider);
    if (repo == null || _demoPerson) {
      _remember();
      _bindLocal();
      return;
    }
    try {
      final id = await repo.openDirect(
        otherUserId: widget.otherUserId,
        listingId: widget.listingId,
      );
      _remember(conversationId: id);
      final messages = await repo.loadMessages(id);
      if (!mounted) {
        return;
      }
      setState(() {
        _local = false;
        _conversationId = id;
        _messages = messages;
        _loading = false;
        _note = null;
      });
      _offerGreeting(messages.isEmpty);
      _bindRemote(repo, id);
      unawaited(_markRead(repo, id));
      _jumpToEnd();
    } on ChatFailure catch (error) {
      if (!mounted) {
        return;
      }
      _note = error.message;
      _remember();
      _bindLocal();
    }
  }

  void _offerGreeting(bool empty) {
    if (!widget.suggestGreeting || !empty || _body.text.trim().isNotEmpty) {
      return;
    }
    _body.text = hostGreeting(
      name: widget.otherName,
      listingTitle: widget.listingTitle ?? '',
      locality: widget.place ?? '',
    );
  }

  void _bindLocal() {
    final store = ref.read(localDirectChatsProvider);
    setState(() {
      _local = true;
      _loading = false;
      _messages = store.messagesFor(widget.otherUserId);
    });
    _offerGreeting(_messages.isEmpty);
    _localLive = store.watch(widget.otherUserId).listen((messages) {
      if (!mounted) {
        return;
      }
      setState(() => _messages = messages);
      _jumpToEnd();
    });
    _jumpToEnd();
  }

  void _bindRemote(ChatRepository repo, String conversationId) {
    unawaited(_remoteLive?.cancel());
    _remoteLive = repo.watchMessages(conversationId).listen((incoming) {
      if (!mounted) {
        return;
      }
      final safe = ChatMessage(
        id: incoming.id,
        senderId: incoming.senderId,
        body: displayMessageBody(incoming.body),
        createdAt: incoming.createdAt,
        mine: incoming.mine,
        readAt: incoming.readAt,
      );
      setState(() {
        _messages = [
          for (final message in _messages)
            if (message.id != safe.id) message,
          safe,
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      if (!safe.mine) {
        unawaited(_markRead(repo, conversationId));
      }
      _jumpToEnd();
    });
  }

  Future<void> _markRead(ChatRepository repo, String conversationId) async {
    try {
      await repo.markRead(conversationId);
    } on Object {
      // The thread still shows. Receipts catch up on the next open.
    }
  }

  Future<void> _send() async {
    final text = _body.text;
    if (containsContactText(text)) {
      setState(() => _note = ThreadCopy.contactRejected);
      return;
    }
    setState(() => _busy = true);
    try {
      if (_local || _conversationId == null) {
        ref.read(localDirectChatsProvider).send(widget.otherUserId, text);
      } else {
        final repo = ref.read(chatRepositoryProvider);
        if (repo == null) {
          ref.read(localDirectChatsProvider).send(widget.otherUserId, text);
        } else {
          await repo.send(_conversationId!, text);
          final messages = await repo.loadMessages(_conversationId!);
          if (mounted) {
            setState(() => _messages = messages);
          }
        }
      }
      if (!mounted) {
        return;
      }
      _body.clear();
      setState(() {
        _busy = false;
        if (_note == ThreadCopy.contactRejected) {
          _note = null;
        }
      });
      _jumpToEnd();
    } on ChatFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note = error.message;
      });
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) {
        return;
      }
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _openProfile() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final profile = widget.profilePath?.trim() ?? '';
    if (profile.startsWith('/')) {
      router.push(profile);
      return;
    }
    final listing = widget.listingId?.trim() ?? '';
    if (listing.isNotEmpty) {
      router.push(RoutePaths.listing(listing));
      return;
    }
    final user = widget.otherUserId.trim();
    if (user.isNotEmpty && !isUuid(user)) {
      router.push(RoutePaths.roommatePerson(user));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = containsContactText(widget.otherName)
        ? 'Chat'
        : widget.otherName;
    final title = widget.listingTitle;
    final safeTitle = title != null && !containsContactText(title)
        ? title
        : null;
    return MinTouchScope(
      child: Scaffold(
        key: const Key('direct-chat-screen'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: InkWell(
            key: const Key('direct-chat-profile'),
            onTap: _openProfile,
            child: Row(
              children: [
                HostAvatar(name: name, photoRef: widget.avatarUrl, radius: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        homiziText(context, name),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (safeTitle != null)
                        Text(
                          homiziText(context, safeTitle),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: HomiziColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (widget.otherUserId.isNotEmpty)
              IconButton(
                key: const Key('report-match'),
                tooltip: homiziText(context, 'Report'),
                onPressed: () => context.push(
                  RoutePaths.reportLocation(
                    targetType: 'user',
                    targetId: widget.otherUserId,
                    blockedUserId: widget.otherUserId,
                  ),
                ),
                icon: const Icon(Icons.flag_outlined),
              ),
          ],
        ),
        body: _loading
            ? const LoadingState(message: 'Opening the conversation…')
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                  if (_note == ThreadCopy.contactRejected)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _ContactWarning(
                        message: homiziText(context, _note!),
                      ),
                    )
                  else if (_note != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: LiveNotice(
                        key: const Key('chat-note'),
                        message: homiziText(context, _note!),
                      ),
                    ),
                  Expanded(
                    child: _messages.isEmpty
                        ? const EmptyState(
                            key: Key('direct-chat-empty'),
                            title: 'No messages yet',
                            message:
                                'Say hello without a phone number or an email address.',
                          )
                        : ListView(
                            key: const Key('chat-log'),
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            children: _bubbles(context),
                          ),
                  ),
                  if (widget.suggestGreeting &&
                      (widget.listingId ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Material(
                        key: const Key('host-listing-card'),
                        color: HomiziColors.accentWash,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push(
                            RoutePaths.listing(widget.listingId!.trim()),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.home_work_outlined,
                                  color: HomiziColors.logoOrange,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        homiziText(
                                          context,
                                          (widget.listingTitle ?? '')
                                                  .trim()
                                                  .isEmpty
                                              ? 'Your property'
                                              : widget.listingTitle!.trim(),
                                        ),
                                        style: const TextStyle(
                                          color: HomiziColors.ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if ((widget.place ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        Text(
                                          widget.place!.trim(),
                                          style: const TextStyle(
                                            color: HomiziColors.inkSoft,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('chat-body'),
                            controller: _body,
                            keyboardType: TextInputType.text,
                            minLines: 1,
                            maxLines: 4,
                            decoration:
                                kitInputDecoration(
                                  hint: homiziText(context, 'Write a message'),
                                  prefixIcon: const Icon(
                                    RealLifeIcons.chat,
                                    color: HomiziColors.logoOrange,
                                  ),
                                ).copyWith(
                                  filled: true,
                                  fillColor: HomiziColors.mist,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
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
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          key: const Key('chat-send'),
                          style: FilledButton.styleFrom(
                            backgroundColor: HomiziColors.accent,
                            foregroundColor: HomiziColors.ink,
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _busy ? null : () => unawaited(_send()),
                          icon: const Icon(Icons.send, size: 18),
                          label: Text(homiziText(context, 'Send')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _bubbles(BuildContext context) {
    final laterFromOther = <DateTime>[
      for (final message in _messages)
        if (!message.mine) message.createdAt,
    ];
    final now = DateTime.now();
    final children = <Widget>[];
    String? day;
    for (final message in _messages) {
      final label = formatChatDay(message.createdAt, now);
      if (label != day) {
        day = label;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: Text(
                homiziText(context, label),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: HomiziColors.muted),
              ),
            ),
          ),
        );
      }
      final read = chatMessageWasRead(
        createdAt: message.createdAt,
        mine: message.mine,
        laterFromOther: laterFromOther,
        readAt: message.readAt,
      );
      children.add(
        Align(
          alignment: message.mine
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: message.mine ? HomiziColors.accentWash : HomiziColors.mist,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(message.mine ? 18 : 4),
                bottomRight: Radius.circular(message.mine ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    homiziText(context, message.body),
                    key: Key('chat-message-${message.id}'),
                    style: const TextStyle(color: HomiziColors.ink),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatChatClock(message.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: HomiziColors.muted,
                      ),
                    ),
                    if (message.mine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        read ? Icons.done_all : Icons.done,
                        key: Key('chat-tick-${message.id}'),
                        size: 14,
                        color: read ? HomiziColors.accent : HomiziColors.muted,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return children;
  }
}

class _ContactWarning extends StatelessWidget {
  const _ContactWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomiziColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HomiziColors.accent, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                color: HomiziColors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  key: const Key('chat-contact-warning'),
                  style: const TextStyle(color: HomiziColors.brandDeepOrange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
