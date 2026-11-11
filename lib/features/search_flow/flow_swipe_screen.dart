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
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/search_flow/flow_decks.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:homizi/features/search_flow/listing_rank.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';
import 'package:homizi/features/search_flow/swipe_matcher.dart';

/// Property, seeker-demand, people, and broker decks. One matcher widget.
///
/// Property cards use `score_compatibility`. Demo mode is the only path that
/// fills the deck from the offline catalog.
class FlowSwipeScreen extends ConsumerStatefulWidget {
  const FlowSwipeScreen({required this.deck, super.key});

  /// `property`, `demand`, `people`, or `broker`.
  final String deck;

  @override
  ConsumerState<FlowSwipeScreen> createState() => _FlowSwipeScreenState();
}

class _FlowSwipeScreenState extends ConsumerState<FlowSwipeScreen> {
  List<SwipeMatchCardData>? _cards;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = ref.read(flowPrefsProvider);
    final demo = rankedDeckUsesDemo(
      ref.read(appConfigProvider),
      forceDemo: ref.read(forceDemoModeProvider),
    );
    try {
      final cards = await _cardsFor(prefs, demo: demo);
      if (!mounted) {
        return;
      }
      setState(() {
        _cards = cards;
        _error = null;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _cards = const [];
        _error = 'Matches could not be loaded.';
      });
    }
  }

  Future<List<SwipeMatchCardData>> _cardsFor(
    FlowPrefs prefs, {
    required bool demo,
  }) async {
    switch (widget.deck) {
      case 'demand':
        return demandCards(
          prefs: prefs,
          draft: ref.read(listingDraftProvider),
          broker: false,
        );
      case 'broker':
        return demandCards(
          prefs: prefs,
          draft: ref.read(listingDraftProvider),
          broker: true,
        );
      case 'people':
        return peopleCards(prefs: prefs, saved: ref.read(roomieProvider).brief);
      default:
        if (demo) {
          return propertyCards(prefs);
        }
        final remote = await ref
            .read(discoveryGatewayProvider)
            .searchListings(
              ListingFilters(
                city: prefs.city,
                locality: prefs.localities.isEmpty
                    ? null
                    : prefs.localities.first,
                budgetMinInr: prefs.budgetLow,
                budgetMaxInr: prefs.budgetHigh,
                furnishing: prefs.furnishing,
              ),
            );
        final scorer = ref.read(compatibilityScorerProvider);
        return rankListings(
          listings: listingsForRank(demoMode: false, remote: remote),
          prefs: prefs,
          score: scorer.score,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.deck) {
      'demand' => 'Seeker demand',
      'people' => 'Roomie matches',
      'broker' => 'Property matches',
      _ => 'Property matches',
    };
    final cards = _cards;
    return Scaffold(
      key: const Key('flow-swipe-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, title)),
      ),
      body: HomiziFrame(
        child: Column(
          children: [
            if (widget.deck == 'demand')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('owner-post-flat'),
                  onPressed: () =>
                      context.push('${RoutePaths.listingEditor}?fresh=1'),
                  child: Text(homiziText(context, 'Post a flat')),
                ),
              ),
            if (widget.deck == 'property' || widget.deck == 'people')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('swipe-open-shared'),
                  onPressed: () => context.push(
                    widget.deck == 'people'
                        ? RoutePaths.roomie
                        : RoutePaths.intelligentMatch,
                  ),
                  child: Text(
                    homiziText(
                      context,
                      widget.deck == 'people'
                          ? 'Find Your Roomie'
                          : 'Match details',
                    ),
                  ),
                ),
              ),
            Expanded(child: _body(cards)),
          ],
        ),
      ),
    );
  }

  Widget _body(List<SwipeMatchCardData>? cards) {
    if (_error != null) {
      return Center(child: Text(homiziText(context, _error!)));
    }
    if (cards == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SwipeMatcher(
      cards: cards,
      onDecision: (card, decision) {
        if (decision == SwipeDecision.like) {
          openDemoSuccess(
            context,
            title: _likeTitle(widget.deck),
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
    );
  }

  void _edit(BuildContext context) {
    final path = switch (widget.deck) {
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
