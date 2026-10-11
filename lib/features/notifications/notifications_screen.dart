import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';
import 'package:homizi/features/notifications/notification_gateway.dart';
import 'package:homizi/features/notifications/notification_providers.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  List<String> _demoMatchIds() {
    if (ref.read(appConfigProvider).connectsToSupabase) {
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
      setState(() {
        _inbox = inbox;
        _loading = false;
        _error = null;
      });
    } on InboxFailure catch (error) {
      if (!mounted || ticket != _ticket) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
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
    ref.listen(discoveryProvider, (previous, next) {
      if (ref.read(appConfigProvider).connectsToSupabase) {
        return;
      }
      final before = previous?.matches.map((match) => match.matchId).join('\n');
      final after = next.matches.map((match) => match.matchId).join('\n');
      if (before == after) {
        return;
      }
      unawaited(_load());
    });

    final unread = _inbox.items.any((item) => item.unread);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread)
            TextButton(
              key: const Key('mark-all-read'),
              onPressed: () => unawaited(
                _apply(
                  () => ref.read(notificationGatewayProvider).markAllRead(),
                ),
              ),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(InboxCopy.safety, key: Key('inbox-safety')),
          if (_inbox.note != null) ...[
            const SizedBox(height: 12),
            Text(_inbox.note!, key: const Key('inbox-note')),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const Key('inbox-error')),
            TextButton(
              onPressed: () => unawaited(_load()),
              child: const Text('Try again'),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Text('Loading notifications…')
          else if (_inbox.items.isEmpty)
            const Text(InboxCopy.empty, key: Key('inbox-empty'))
          else
            Column(
              key: const Key('notification-list'),
              children: [
                for (final notice in _inbox.items)
                  _NoticeTile(
                    notice: notice,
                    onMarkRead: () => unawaited(
                      _apply(
                        () => ref
                            .read(notificationGatewayProvider)
                            .markRead(notice.id),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.onMarkRead});

  final InboxNotice notice;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final matchId = notice.matchId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              noticeSentence(notice.type),
              key: Key('notice-sentence-${notice.id}'),
            ),
            const SizedBox(height: 4),
            Text(notice.unread ? 'Unread' : 'Read'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (notice.unread)
                  TextButton(
                    key: Key('mark-read-${notice.id}'),
                    onPressed: onMarkRead,
                    child: const Text('Mark read'),
                  ),
                if (matchId != null)
                  TextButton(
                    key: Key('open-chat-from-notice-${notice.id}'),
                    onPressed: () => context.push(RoutePaths.chat(matchId)),
                    child: const Text('Open chat'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
