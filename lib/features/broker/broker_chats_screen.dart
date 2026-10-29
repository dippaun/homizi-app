import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/broker/broker_page.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';

/// Chats for the signed-in broker.
///
/// Real mutual matches come first. Demo mode falls back to the same seeded
/// match summaries the matches inbox uses when the server list is empty.
class BrokerChatsScreen extends ConsumerWidget {
  const BrokerChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final discovery = ref.watch(discoveryProvider);
    final offlineDemo = !config.connectsToSupabase || config.demoSkipLogin;
    final threads = discovery.matches.isNotEmpty
        ? discovery.matches
        : offlineDemo
        ? demoSeedMatchSummaries()
        : const <MatchSummary>[];
    return Scaffold(
      key: const Key('broker-chats-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Chats')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'Messages with seekers. A phone number or an email is refused in chat.',
            ),
          ),
          const SizedBox(height: 16),
          if (threads.isEmpty)
            Text(
              homiziText(
                context,
                'No matches yet. A chat opens after you and a seeker both agree.',
              ),
            )
          else
            for (final thread in threads)
              BrokerTapCard(
                cardKey: Key('broker-chat-card-${thread.matchId}'),
                onTap: () => context.push(
                  RoutePaths.chat(
                    thread.matchId,
                    name: thread.otherDisplayName,
                    title: thread.listingTitle,
                    otherUserId: thread.otherUserId,
                    avatar: thread.avatarUrl,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, thread.otherDisplayName),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (thread.listingTitle != null) ...[
                      const SizedBox(height: 6),
                      Text(homiziText(context, thread.listingTitle!)),
                    ],
                  ],
                ),
              ),
          OutlinedButton(
            key: const Key('broker-chats-matches'),
            onPressed: () => context.go(RoutePaths.matches),
            child: Text(homiziText(context, 'Mutual matches')),
          ),
        ],
      ),
    );
  }
}
