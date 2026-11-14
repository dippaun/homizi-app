import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/find_roomie/find_roomie_catalog.dart';
import 'package:homizi/features/find_roomie/find_roomie_paths.dart';
import 'package:homizi/features/find_roomie/find_roomie_providers.dart';
import 'package:homizi/features/find_roomie/find_roomie_widgets.dart';
import 'package:homizi/features/post_analyzer/property_card_data.dart';
import 'package:homizi/features/post_analyzer/property_match_adapter.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/shared/widgets/homizi_property_card.dart';

class FindRoomieExploreScreen extends ConsumerWidget {
  const FindRoomieExploreScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(findRoomieProvider);
    final discovery = ref.watch(discoveryProvider);
    final score = ref.watch(listingScorerProvider);
    final person = state.person(personId);
    final live =
        !discovery.loading &&
        discovery.error == null &&
        discovery.listings.isNotEmpty;
    final homes = live
        ? discovery.listings
        : (discovery.loading ? const <Listing>[] : sampleFindRoomieHomes);
    return FindRoomiePage(
      title: 'Homes together',
      shotKey: const Key('find-roomie-shot-explore'),
      body: person == null
          ? (state.loading
                ? const LoadingState(message: 'Opening homes…')
                : const EmptyState(
                    title: 'Choose a roommate first',
                    message: 'Connect with someone, then look at homes.',
                  ))
          : discovery.loading && homes.isEmpty
          ? const LoadingState(message: 'Looking at homes…')
          : _Body(
              personId: personId,
              partner: person.name,
              homes: homes,
              sample: !live,
              score: score,
              saved: (id) => state.shortlisted(personId, id),
            ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.personId,
    required this.partner,
    required this.homes,
    required this.sample,
    required this.score,
    required this.saved,
  });

  final String personId;
  final String partner;
  final List<Listing> homes;
  final bool sample;
  final ListingMatch Function(Listing listing) score;
  final bool Function(String id) saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const Key('find-roomie-explore-list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          homiziText(context, 'Homes you and $partner can look at.'),
          style: text.bodyLarge?.copyWith(color: HomiziColors.inkSoft),
        ),
        const SizedBox(height: 8),
        if (sample) const FindRoomieSampleChip(),
        const SizedBox(height: 16),
        for (final home in homes) ...[
          _HomeCard(
            personId: personId,
            listing: home,
            match: score(home),
            saved: saved(home.id),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _HomeCard extends ConsumerWidget {
  const _HomeCard({
    required this.personId,
    required this.listing,
    required this.match,
    required this.saved,
  });

  final String personId;
  final Listing listing;
  final ListingMatch match;
  final bool saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = propertyCardData(
      listing: listing,
      score: _cardScore(match),
      saved: saved,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomiziPropertyCard(
          data: data,
          // The full swipe card needs a fixed deck height. Lists use the
          // same card's photo layout.
          variant: HomiziPropertyCardVariant.compact,
          onTap: () => context.push(SharedHomePaths.home(listing.id)),
          onSave: () => ref
              .read(findRoomieProvider.notifier)
              .saveHome(personId, listing.id),
        ),
        const SizedBox(height: 8),
        FindRoomieButton(
          buttonKey: Key('find-roomie-request-${listing.id}'),
          label: 'Request together',
          icon: Icons.group_outlined,
          onPressed: () async {
            await ref
                .read(findRoomieProvider.notifier)
                .saveHome(personId, listing.id);
            if (context.mounted) {
              unawaited(
                context.push(FindRoomiePaths.request(personId, listing.id)),
              );
            }
          },
        ),
      ],
    );
  }
}

PropertyMatchScore _cardScore(ListingMatch match) {
  if (!match.showBadge) {
    return const PropertyMatchScore(
      percent: null,
      topReasons: [],
      missing: [],
      importantMismatch: false,
      strong: false,
    );
  }
  return PropertyMatchScore(
    percent: match.score,
    topReasons: [
      for (final factor in match.factors)
        if (factor.matched && factor.detail.isNotEmpty) factor.detail,
    ].take(5).toList(),
    missing: [
      for (final factor in match.factors)
        if (!factor.matched && factor.detail.isNotEmpty) factor.detail,
    ],
    importantMismatch: match.factors.any((factor) => !factor.matched),
    strong: match.isBest,
  );
}
