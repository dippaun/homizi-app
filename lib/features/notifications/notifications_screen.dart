import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';
import 'package:homizi/features/notifications/domain/notice_category.dart';
import 'package:homizi/features/notifications/domain/notification_preferences.dart';
import 'package:homizi/features/notifications/notification_gateway.dart';
import 'package:homizi/features/notifications/notification_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  var _loading = true;
  var _ticket = 0;
  String? _error;
  InboxSnapshot _inbox = const InboxSnapshot(items: []);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: NoticeCategory.values.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _tabs.dispose();
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

  List<InboxNotice> get _visible {
    final category = NoticeCategory.values[_tabs.index];
    if (category == NoticeCategory.all) {
      return _inbox.items;
    }
    return [
      for (final item in _inbox.items)
        if (categoryForType(item.type) == category) item,
    ];
  }

  Future<void> _preferences() async {
    final gateway = ref.read(notificationGatewayProvider);
    try {
      final current = await gateway.loadPreferences();
      if (!mounted) {
        return;
      }
      final next = await showModalBottomSheet<NotificationPreferences>(
        context: context,
        showDragHandle: true,
        builder: (context) => _PreferencesSheet(initial: current),
      );
      if (next == null || !mounted) {
        return;
      }
      await gateway.savePreferences(next);
      if (!mounted) {
        return;
      }
      setState(() => _error = null);
      _inbox = InboxSnapshot(
        items: _inbox.items,
        note: InboxCopy.preferencesSaved,
      );
      setState(() {});
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
      if (_remoteSession) {
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
    final visible = _visible;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Notifications')),
        actions: [
          IconButton(
            key: const Key('notification-preferences'),
            tooltip: homiziText(context, 'Notification preferences'),
            onPressed: () => unawaited(_preferences()),
            icon: const Icon(Icons.tune),
          ),
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
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final category in NoticeCategory.values)
              Tab(
                key: Key('tab-${category.name}'),
                text: homiziText(context, categoryLabel(category)),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              homiziText(context, InboxCopy.safety),
              key: const Key('inbox-safety'),
            ),
            if (_inbox.note != null) ...[
              const SizedBox(height: 12),
              Text(
                homiziText(context, _inbox.note!),
                key: const Key('inbox-note'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(homiziText(context, _error!), key: const Key('inbox-error')),
              TextButton(
                onPressed: () => unawaited(_load()),
                child: Text(homiziText(context, 'Try again')),
              ),
            ],
            const SizedBox(height: 16),
            if (_loading)
              Text(homiziText(context, 'Loading notifications…'))
            else if (_inbox.items.isEmpty)
              Text(
                homiziText(context, InboxCopy.empty),
                key: const Key('inbox-empty'),
              )
            else if (visible.isEmpty)
              Text(
                homiziText(context, 'Nothing in this category.'),
                key: const Key('inbox-category-empty'),
              )
            else
              Column(
                key: const Key('notification-list'),
                children: [
                  for (final notice in visible)
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
    );
  }
}

class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.initial});

  final NotificationPreferences initial;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late NotificationPreferences _prefs = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            homiziText(context, 'Notification preferences'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'Turn a category off to stop new alerts of that kind. This does not send a phone alert.',
            ),
          ),
          _switch(
            'pref-matches',
            'Matches',
            _prefs.matches,
            (value) => _prefs = _prefs.copyWith(matches: value),
          ),
          _switch(
            'pref-visits',
            'Visits',
            _prefs.visits,
            (value) => _prefs = _prefs.copyWith(visits: value),
          ),
          _switch(
            'pref-chat',
            'Chat',
            _prefs.chat,
            (value) => _prefs = _prefs.copyWith(chat: value),
          ),
          _switch(
            'pref-listings',
            'Listings',
            _prefs.listings,
            (value) => _prefs = _prefs.copyWith(listings: value),
          ),
          _switch(
            'pref-system',
            'System',
            _prefs.system,
            (value) => _prefs = _prefs.copyWith(system: value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('save-notification-prefs'),
            onPressed: () => Navigator.pop(context, _prefs),
            child: Text(homiziText(context, 'Save')),
          ),
        ],
      ),
    );
  }

  Widget _switch(
    String key,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      key: Key(key),
      contentPadding: EdgeInsets.zero,
      title: Text(homiziText(context, label)),
      value: value,
      onChanged: (next) => setState(() => onChanged(next)),
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
                    onPressed: () => context.push(RoutePaths.chat(matchId)),
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
