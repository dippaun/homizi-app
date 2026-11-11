import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/media/portrait_asset.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/search_flow/flow_actions.dart';
import 'package:homizi/features/search_flow/flow_decks.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:homizi/features/search_flow/listing_rank.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';
import 'package:homizi/features/search_flow/swipe_matcher.dart';
import 'package:homizi/features/search_flow/swipe_score_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final Map<String, Listing> _listings = {};
  final Map<String, RoommateSeeker> _people = {};

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
      case 'broker':
        if (demo) {
          return demandCards(
            prefs: prefs,
            draft: ref.read(listingDraftProvider),
            broker: widget.deck == 'broker',
          );
        }
        return _requirementCards();
      case 'people':
        if (demo) {
          return peopleCards(
            prefs: prefs,
            saved: ref.read(roomieProvider).brief,
          );
        }
        final seekers = await ref
            .read(roommateGatewayProvider)
            .load(const RoommateQuery());
        _people
          ..clear()
          ..addEntries([
            for (final seeker in seekers) MapEntry(seeker.id, seeker),
          ]);
        return [for (final seeker in seekers) _personCard(seeker)];
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
        final homes = listingsForRank(demoMode: false, remote: remote);
        _listings
          ..clear()
          ..addEntries([for (final home in homes) MapEntry(home.id, home)]);
        final scorer = ref.read(compatibilityScorerProvider);
        final ranked = await rankListings(
          listings: homes,
          prefs: prefs,
          score: scorer.score,
        );
        return [for (final card in ranked) _tagged(card, 'listing')];
    }
  }

  Future<List<SwipeMatchCardData>> _requirementCards() async {
    final raw = await Supabase.instance.client.rpc<dynamic>(
      'seekers_for_my_listings',
    );
    final rows = raw is List ? raw : const <dynamic>[];
    final cards = <SwipeMatchCardData>[];
    for (final item in rows) {
      if (item is! Map) {
        continue;
      }
      final row = Map<String, dynamic>.from(item);
      final id = row['requirement_id']?.toString() ?? '';
      if (id.isEmpty) {
        continue;
      }
      final name = (row['display_name']?.toString() ?? '').trim();
      final title = name.isEmpty ? 'Seeker' : name;
      final percent = row['match_percent'];
      cards.add(
        SwipeMatchCardData(
          id: id,
          title: title,
          subtitle: row['city']?.toString() ?? '',
          meta: row['about_me']?.toString() ?? '',
          photoAsset: portraitForName(title),
          percent: percent is int ? percent : 0,
          importantMismatch: false,
          reasons: const ['Their brief is saved on the server.'],
          badges: const [],
          portrait: true,
          persistTarget: 'requirement',
        ),
      );
    }
    return cards;
  }

  SwipeMatchCardData _personCard(RoommateSeeker seeker) {
    return SwipeMatchCardData(
      id: seeker.id,
      title: seeker.name,
      subtitle: seeker.localityLabel,
      meta: '${seeker.budgetLabel} · ${seeker.profession}',
      photoAsset: seeker.photoRef ?? portraitForName(seeker.name),
      percent: seeker.score,
      importantMismatch: false,
      reasons: const ['Saved when you like or pass.'],
      badges: const [],
      portrait: true,
      persistTarget: 'person',
    );
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SwipeDeckChip(
                        key: const Key('owner-post-flat'),
                        icon: Icons.add_home_outlined,
                        label: 'Post a flat',
                        onPressed: () =>
                            context.push('${RoutePaths.listingEditor}?fresh=1'),
                      ),
                      SwipeDeckChip(
                        key: const Key('swipe-edit-preferences'),
                        label: 'Edit preferences',
                        onPressed: () => _edit(context),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.deck == 'property' || widget.deck == 'people')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SwipeDeckChip(
                    key: const Key('swipe-open-shared'),
                    icon: Icons.travel_explore,
                    label: widget.deck == 'people'
                        ? 'Find Your Roomie'
                        : 'Match details',
                    onPressed: () => context.push(
                      widget.deck == 'people'
                          ? RoutePaths.roomie
                          : RoutePaths.intelligentMatch,
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
    final peopleDeck = widget.deck == 'demand' || widget.deck == 'broker';
    return SwipeMatcher(
      cards: cards,
      showEditPreferences: widget.deck != 'demand',
      onChat: peopleDeck ? _chat : null,
      onDecision: (card, decision) {
        final target = persistTargetFor(card.persistTarget);
        if (target != null) {
          unawaited(
            ref
                .read(flowActionsProvider)
                .record(
                  target: target,
                  id: card.id,
                  action: interestActionFor(decision),
                  listing: _listings[card.id],
                  person: _people[card.id],
                ),
          );
        }
        if (decision == SwipeDecision.like) {
          openDemoSuccess(
            context,
            title: _likeTitle(widget.deck),
            detail: target == null
                ? _likeDetail(card)
                : 'Saved on your account. They see it after a reload.',
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

  void _chat(SwipeMatchCardData card) {
    unawaited(
      guardVerifiedAction(
        context,
        ref,
        action: () async {
          if (!context.mounted) {
            return;
          }
          await context.push(
            RoutePaths.inboxChat(
              'demo-seeker-${card.id}',
              name: card.title,
              title: card.subtitle,
              avatar: card.photoAsset,
            ),
          );
        },
      ),
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

SwipeMatchCardData _tagged(SwipeMatchCardData card, String target) {
  return SwipeMatchCardData(
    id: card.id,
    title: card.title,
    subtitle: card.subtitle,
    meta: card.meta,
    photoAsset: card.photoAsset,
    percent: card.percent,
    importantMismatch: card.importantMismatch,
    reasons: card.reasons,
    badges: card.badges,
    highlights: card.highlights,
    facts: card.facts,
    portrait: card.portrait,
    persistTarget: target,
  );
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
