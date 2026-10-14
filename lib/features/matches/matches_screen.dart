import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/notifications_button.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/contact_gate_panel.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/own_contact_share.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final preview = ref.watch(viewPreviewProvider('matches'));
    final discovery = ref.watch(discoveryProvider);
    final onDeviceOnly = !config.connectsToSupabase;
    final status = preview != ViewStatus.ready
        ? preview
        : discovery.loading
        ? ViewStatus.loading
        : discovery.error != null
        ? ViewStatus.error
        : discovery.matches.isEmpty
        ? ViewStatus.empty
        : ViewStatus.ready;

    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        title: const ScreenTitle('Matches'),
        actions: const [NotificationsButton(), SettingsButton()],
      ),
      body: Column(
        children: [
          if (ref.watch(showStatePreviewProvider))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: StatePreviewBar(
                status: preview,
                onChanged: ref
                    .read(viewPreviewProvider('matches').notifier)
                    .setStatus,
              ),
            ),
          Expanded(
            child: AsyncStateBody(
              status: status,
              loadingMessage: 'Checking mutual interest…',
              emptyTitle: 'No mutual matches yet',
              emptyMessage: 'A match is created only when both sides like each other. Like the Koramangala demo home to see a sample card. Passing later does not remove it. Contact appears only when the server says it is visible.',
              errorTitle: 'Matches did not load',
              errorMessage:
                  discovery.error ?? 'Retry to read matches from the server.',
              onRetry: () {
                ref
                    .read(viewPreviewProvider('matches').notifier)
                    .setStatus(ViewStatus.ready);
                if (ref.read(discoveryProvider).error != null) {
                  unawaited(ref.read(discoveryProvider.notifier).refresh());
                }
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  for (final match in discovery.matches) ...[
                    Card.outlined(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                HostAvatar(name: match.otherDisplayName),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        homiziText(
                                          context,
                                          match.otherDisplayName,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        homiziText(
                                          context,
                                          match.listingTitle ?? 'Mutual match',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ContactGatePanel(
                              gate: match.contact,
                              matchId: match.matchId,
                            ),
                            const SizedBox(height: 12),
                            OwnContactShare(
                              match: match,
                              onDeviceOnly: onDeviceOnly,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: Key('open-chat-${match.matchId}'),
                                onPressed: () => context.push(
                                  RoutePaths.chat(
                                    match.matchId,
                                    name: match.otherDisplayName,
                                    title: match.listingTitle,
                                    otherUserId: match.otherUserId,
                                  ),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: Text(homiziText(context, 'Chat')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
