import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/search_flow/flow_decks.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';
import 'package:homizi/features/search_flow/swipe_matcher.dart';

/// Property, seeker-demand, people, and broker decks. One matcher widget.
class FlowSwipeScreen extends ConsumerWidget {
  const FlowSwipeScreen({required this.deck, super.key});

  /// `property`, `demand`, `people`, or `broker`.
  final String deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(flowPrefsProvider);
    final brief = ref.watch(roomieProvider).brief;
    final draft = ref.watch(listingDraftProvider);
    final cards = switch (deck) {
      'demand' => demandCards(prefs: prefs, draft: draft, broker: false),
      'people' => peopleCards(prefs: prefs, saved: brief),
      'broker' => demandCards(prefs: prefs, draft: draft, broker: true),
      _ => propertyCards(prefs),
    };
    final title = switch (deck) {
      'demand' => 'Seeker demand',
      'people' => 'Roomie matches',
      'broker' => 'Property matches',
      _ => 'Property matches',
    };
    return Scaffold(
      key: const Key('flow-swipe-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, title)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              if (deck == 'demand')
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('owner-post-flat'),
                    onPressed: () => context.push(
                      '${RoutePaths.listingEditor}?fresh=1',
                    ),
                    child: Text(homiziText(context, 'Post a flat')),
                  ),
                ),
              Expanded(
                child: SwipeMatcher(
                  cards: cards,
                  onDecision: (card, decision) {
                    if (decision == SwipeDecision.like) {
                      openDemoSuccess(
                        context,
                        title: _likeTitle(deck),
                        detail: _likeDetail(card),
                      );
                    }
                  },
                  onFinished: () => openDemoSuccess(
                    context,
                    title: 'Deck finished',
                    detail:
                        'You have seen this deck. Edit preferences any time and come back.',
                  ),
                  onEditPreferences: () => _edit(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _edit(BuildContext context) {
    final path = switch (deck) {
      'people' => RoutePaths.roomiePreferences,
      'demand' => RoutePaths.listingEditor,
      'broker' => RoutePaths.flowBroker,
      _ => RoutePaths.flowRequirements,
    };
    context.push(path);
  }
}

String _likeTitle(String deck) => switch (deck) {
  'demand' => 'Seeker liked',
  'people' => 'Roomie liked',
  'broker' => 'Match saved',
  _ => 'Home liked',
};

String _likeDetail(SwipeMatchCardData card) {
  return '${card.title} is saved as a like. ${card.percent}% match. Contact stays hidden until you both agree.';
}
