import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';
import 'package:homizi/features/notifications/live_tenant_notices.dart';
import 'package:homizi/features/notifications/notification_gateway.dart';
import 'package:homizi/features/notifications/notification_providers.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/ui/kit/kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  var _loading = true;
  var _ticket = 0;
  String? _error;
  InboxSnapshot _inbox = const InboxSnapshot(items: []);
  var _live = const <TenantLiveNotice>[];
  final _hiddenLive = <String>{};
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  bool get _remoteSession {
    final config = ref.read(appConfigProvider);
    return config.connectsToSupabase && !ref.read(forceDemoModeProvider);
  }

  List<String> _demoMatchIds() {
    if (_remoteSession) {
      return const [];
    }
    return [
      for (final match in ref.read(discoveryProvider).matches) match.matchId,
    ];
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    try {
      final inbox = await ref
          .read(notificationGatewayProvider)
          .load(demoMatchIds: _demoMatchIds());
      if (!mounted || ticket != _ticket) {
        return;
      }
      final live = await loadTenantLiveNotices(ref);
      if (!mounted || ticket != _ticket) {
        return;
      }
      setState(() {
        _inbox = inbox;
        _live = live;
        _loading = false;
        _error = null;
      });
      _bind();
    } on InboxFailure catch (error) {
      if (!mounted || ticket != _ticket) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
        _live = demoTenantNotices();
      });
    }
  }

  void _bind() {
    if (!_remoteSession) {
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _channel != null) {
      return;
    }
    final channel = Supabase.instance.client.channel('tenant-live:${user.id}');
    void refresh() {
      if (mounted) {
        unawaited(_load());
      }
    }

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'properties',
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'interests',
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'profiles',
          callback: (_) => refresh(),
        )
        .subscribe();
    _channel = channel;
  }

  Future<void> _apply(Future<InboxSnapshot> Function() action) async {
    try {
      final inbox = await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _inbox = inbox;
        _error = null;
      });
    } on InboxFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = [
      for (final item in _live)
        if (!_hiddenLive.contains(item.id)) item,
    ];
    final unread = _inbox.items.any((item) => item.unread);
    final empty = live.isEmpty && _inbox.items.isEmpty;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Notifications')),
        actions: [
          if (unread)
            TextButton(
              key: const Key('mark-all-read'),
              onPressed: () => unawaited(
                _apply(
                  () => ref.read(notificationGatewayProvider).markAllRead(),
                ),
              ),
              child: Text(homiziText(context, 'Mark all read')),
            ),
        ],
      ),
      body: ContentBody(
        pageId: 'notifications',
        child: HomiziFrame(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  homiziText(context, InboxCopy.safety),
                  key: const Key('inbox-safety'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorState(
                    key: const Key('inbox-error'),
                    title: 'Inbox unavailable',
                    message: _error!,
                    onRetry: () => unawaited(_load()),
                  ),
                ],
                const SizedBox(height: 16),
                if (_loading)
                  const LoadingState(message: 'Loading notifications…')
                else if (empty)
                  const EmptyState(
                    key: Key('inbox-empty'),
                    title: 'No notifications yet',
                    message: InboxCopy.empty,
                  )
                else
                  Column(
                    key: const Key('notification-list'),
                    children: [
                      for (final item in live)
                        _LiveTile(
                          notice: item,
                          onDismiss: () => setState(() {
                            _hiddenLive.add(item.id);
                          }),
                        ),
                      for (final notice in _inbox.items)
                        Dismissible(
                          key: ValueKey(notice.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => unawaited(
                            _apply(
                              () => ref
                                  .read(notificationGatewayProvider)
                                  .dismiss(notice.id),
                            ),
                          ),
                          background: Container(
                            alignment: Alignment.centerRight,
                            color: HomiziColors.mist,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(Icons.delete_outline),
                          ),
                          child: _NoticeTile(
                            notice: notice,
                            onMarkRead: () => unawaited(
                              _apply(
                                () => ref
                                    .read(notificationGatewayProvider)
                                    .markRead(notice.id),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.notice, required this.onDismiss});

  final TenantLiveNotice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final icon = switch (notice.title) {
      'New posting in your area' => Icons.home_outlined,
      'New roommate with a good match' => Icons.groups_outlined,
      'New message' => Icons.chat_bubble_outline,
      _ => Icons.favorite_border,
    };
    return Card.filled(
      key: Key('live-notice-${notice.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: HomiziColors.logoOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    homiziText(context, notice.title),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (notice.demo)
                  Text(
                    homiziText(context, 'Sample'),
                    style: const TextStyle(
                      color: HomiziColors.inkSoft,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(homiziText(context, notice.detail)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key('dismiss-live-${notice.id}'),
                onPressed: onDismiss,
                child: Text(homiziText(context, 'Dismiss')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeTile extends ConsumerWidget {
  const _NoticeTile({required this.notice, required this.onMarkRead});

  final InboxNotice notice;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchId = notice.matchId;
    final propertyId = notice.propertyId;
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    homiziText(context, noticeSentence(notice.type)),
                    key: Key('notice-sentence-${notice.id}'),
                  ),
                ),
                if (notice.unread) Badge(label: Text(homiziText(context, '1'))),
              ],
            ),
            const SizedBox(height: 4),
            Text(homiziText(context, notice.unread ? 'Unread' : 'Read')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (notice.unread)
                  TextButton(
                    key: Key('mark-read-${notice.id}'),
                    onPressed: onMarkRead,
                    child: Text(homiziText(context, 'Mark read')),
                  ),
                if (matchId != null)
                  TextButton(
                    key: Key('open-chat-from-notice-${notice.id}'),
                    onPressed: () => unawaited(
                      guardVerifiedAction(
                        context,
                        ref,
                        action: () async {
                          if (!context.mounted) {
                            return;
                          }
                          await context.push(RoutePaths.chat(matchId));
                        },
                      ),
                    ),
                    child: Text(homiziText(context, 'Open chat')),
                  ),
                if (propertyId != null)
                  TextButton(
                    key: Key('open-listing-from-notice-${notice.id}'),
                    onPressed: () =>
                        context.push(RoutePaths.listing(propertyId)),
                    child: Text(homiziText(context, 'View listing')),
                  ),
                if (notice.type == 'saved_search_match')
                  TextButton(
                    key: Key('open-saved-search-from-notice-${notice.id}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => context.push(RoutePaths.savedSearches),
                    child: Text(homiziText(context, 'Saved searches')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
