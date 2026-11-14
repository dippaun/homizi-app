import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';

/// "Home & housemate details": rooms, who lives there, the housemate, and
/// the same match % as the card.
class SharedHomeDetailScreen extends ConsumerWidget {
  const SharedHomeDetailScreen({required this.homeId, super.key});

  final String homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sharedHomesProvider);
    final home = state.byId(homeId);
    return Scaffold(
      key: const Key('shared-detail-screen'),
      backgroundColor: HomiziColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Home & housemate details')),
      ),
      body: SafeArea(
        top: false,
        child: home == null
            ? (state.loading
                  ? const LoadingState(message: 'Loading this home…')
                  : EmptyState(
                      title: 'This home is not available',
                      message: 'It may have been rented or taken down.',
                      actionLabel: 'See other homes',
                      onAction: () =>
                          context.pushReplacement(SharedHomePaths.results()),
                    ))
            : _Body(home: home),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.home});

  final SharedHome home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final need = ref.watch(occupancyNeedProvider);
    final match = ref.watch(sharedHomeScoreProvider)(home);
    final requests = ref.watch(joinRequestsProvider);
    JoinRequest? open;
    for (final row in requests) {
      if (row.homeId == home.id && row.open) {
        open = row;
        break;
      }
    }
    final fit = fitFor(home, need);
    final full = (home.occupancy.freePlaces ?? 1) <= 0;
    final share = home.shareFor(need.occupancy);
    return ListView(
      key: const Key('shared-detail-list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        ShHomePhoto(
          asset: home.listing.photoAssets.isEmpty
              ? null
              : home.listing.photoAssets.first,
          match: match,
          pillKey: const Key('shared-detail-match'),
          height: 200,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Flexible(child: ShTag(label: home.tag)),
            if (home.sample) ...[
              const SizedBox(width: 8),
              const ShSampleChip(),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          home.listing.title,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('${home.place} · ${home.priceLine}'),
        if (home.listing.summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(home.listing.summary, style: text.bodyMedium),
        ],
        const SizedBox(height: 16),
        ShSection(
          title: 'About the home',
          icon: Icons.home_outlined,
          child: ShOccupancyTable(
            occupancy: home.occupancy,
            shareLine: '${formatInr(share)} / month',
            tableKey: const Key('shared-detail-occupancy'),
          ),
        ),
        const SizedBox(height: 14),
        ShSection(
          title: home.occupancy.housemates.length > 1
              ? 'Current housemates'
              : 'Current housemate',
          icon: Icons.person_outline,
          child: home.occupancy.housemates.isEmpty
              ? Text(
                  homiziText(
                    context,
                    home.occupancy.currentlyLiving == 0
                        ? 'Nobody lives here yet. You would be the first.'
                        : 'The host has not added who lives here yet.',
                  ),
                )
              : Column(
                  children: [
                    for (final mate in home.occupancy.housemates)
                      _Housemate(mate: mate),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              fit.fits ? Icons.check_circle : Icons.info_outline,
              color: fit.fits ? HomiziColors.success : HomiziColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                homiziText(context, fit.line),
                key: const Key('shared-detail-fit'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (open != null)
          ShGradientButton(
            buttonKey: const Key('shared-view-request'),
            icon: Icons.mark_email_read_outlined,
            label: 'View your join request',
            onPressed: () => context.push(SharedHomePaths.request(open!.id)),
          )
        else
          ShGradientButton(
            buttonKey: const Key('shared-request-join'),
            icon: Icons.send_outlined,
            label: full ? 'This home is full' : 'Request to join',
            onPressed: full
                ? null
                : () => context.push(SharedHomePaths.join(home.id)),
          ),
        if (!home.sample) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('shared-full-listing'),
            onPressed: () => context.push(RoutePaths.listing(home.id)),
            icon: const Icon(Icons.open_in_new),
            label: Text(homiziText(context, 'View full listing')),
          ),
        ],
      ],
    );
  }
}

class _Housemate extends StatelessWidget {
  const _Housemate({required this.mate});

  final Housemate mate;

  @override
  Widget build(BuildContext context) {
    final age = mate.age;
    final line = [
      if (age != null) '$age yrs',
      if (mate.occupation.isNotEmpty) mate.occupation,
    ].join(' | ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShAvatar(initial: mate.initial, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mate.displayName} (${homiziText(context, 'Existing tenant')})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: HomiziColors.ink,
                  ),
                ),
                if (line.isNotEmpty) Text(line),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in mate.tags) ShTraitChip(label: tag),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
