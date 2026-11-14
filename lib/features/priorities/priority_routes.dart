import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/priorities/priorities_screen.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/priorities/priority_widgets.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';

List<RouteBase> priorityRoutes() {
  return [
    GoRoute(
      path: RoutePaths.priorities,
      builder: (context, state) =>
          PrioritiesScreen(side: state.uri.queryParameters['side']),
    ),
    GoRoute(
      path: RoutePaths.prioritiesSaved,
      builder: (context, state) => PrioritiesSavedScreen(
        host: state.uri.queryParameters['side'] == 'host',
      ),
    ),
  ];
}

/// The confirmation after Save: "Your priorities summary".
class PrioritiesSavedScreen extends ConsumerWidget {
  const PrioritiesSavedScreen({this.host = false, super.key});

  final bool host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(prioritySyncProvider);
    final where = sync == PrioritySync.account
        ? 'Saved to your HOMIZI account and on this device. Matches use it now.'
        : 'Your order is saved on this device and matches use it now. It syncs to your account after the priorities table is applied on staging.';
    return RepaintBoundary(
      key: const Key('priority-saved-shot'),
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: HomiziColors.white,
          foregroundColor: HomiziColors.ink,
          leading: HomiziBackButton(
            onPressed: () =>
                context.go(host ? RoutePaths.hostOptions : RoutePaths.home),
          ),
          title: Text(homiziText(context, 'Your priorities summary')),
        ),
        body: host ? _HostSummary(where: where) : _TenantSummary(where: where),
      ),
    );
  }
}

class _Saved extends StatelessWidget {
  const _Saved({required this.where});

  final String where;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: HomiziColors.success, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(context, 'Priorities saved'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                homiziText(context, where),
                key: const Key('priority-saved-where'),
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TenantSummary extends ConsumerWidget {
  const _TenantSummary({required this.where});

  final String where;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(searchPrioritiesProvider);
    final score = ref.watch(listingScorerProvider);
    final discovery = ref.watch(discoveryProvider);
    final ranked = [
      for (final listing in discovery.listings)
        (listing: listing, match: score(listing)),
    ]..sort((a, b) => b.match.score.compareTo(a.match.score));
    final preview = ranked.where((row) => row.match.showBadge).take(3).toList();
    final readiness = matchReadiness(p);
    return ListView(
      key: const Key('priority-summary'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Saved(where: where),
        const SizedBox(height: 16),
        Center(child: _ReadinessRing(percent: readiness)),
        const SizedBox(height: 16),
        ShSection(
          child: Column(
            children: [
              for (final c in p.activeOrdered)
                _SummaryRow(
                  rowKey: Key('priority-summary-${criterionWire(c)}'),
                  rank: p.activeOrdered.indexOf(c) + 1,
                  label: '${criterionTitle(c)}: ${criterionValue(p, c)}',
                  mustHave: p.isMustHave(c),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _BetterMatches(),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Match preview (based on your priorities)'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomiziColors.brandDeepRed,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (discovery.loading && discovery.listings.isEmpty)
          Padding(
            key: const Key('priority-preview-loading'),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top, color: HomiziColors.muted),
                const SizedBox(width: 8),
                Text(homiziText(context, 'Finding homes that fit…')),
              ],
            ),
          )
        else if (preview.isEmpty)
          Text(
            homiziText(
              context,
              discovery.error != null
                  ? 'Homes could not be loaded right now. Find matches to try again.'
                  : 'No homes to preview yet. Find matches to search.',
            ),
            key: const Key('priority-preview-empty'),
            style: const TextStyle(color: HomiziColors.muted),
          )
        else
          for (final row in preview)
            _PreviewCard(listing: row.listing, match: row.match),
        const SizedBox(height: 16),
        ShGradientButton(
          buttonKey: const Key('priority-find-matches'),
          label: 'Find Matches Now',
          icon: Icons.chevron_right,
          onPressed: () => context.go(RoutePaths.explore),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('priority-edit-again'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HomiziColors.brandDeepRed,
            minimumSize: const Size.fromHeight(46),
          ),
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              router.go(RoutePaths.priorities);
            }
          },
          child: Text(homiziText(context, 'Edit priorities')),
        ),
        TextButton(
          key: const Key('priority-saved-home'),
          onPressed: () => context.go(RoutePaths.home),
          child: Text(homiziText(context, 'Back to Home')),
        ),
      ],
    );
  }
}

class _HostSummary extends ConsumerWidget {
  const _HostSummary({required this.where});

  final String where;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(hostTenantPrioritiesProvider);
    return ListView(
      key: const Key('priority-summary'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Saved(where: where),
        const SizedBox(height: 16),
        ShSection(
          title: 'Preferred tenant profile',
          icon: Icons.badge_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.propertyLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${homiziText(context, 'For')} ${p.propertyLabel}',
                    style: const TextStyle(color: HomiziColors.inkSoft),
                  ),
                ),
              for (final c in p.activeOrdered)
                _SummaryRow(
                  rowKey: Key('priority-summary-${hostCriterionWire(c)}'),
                  rank: p.activeOrdered.indexOf(c) + 1,
                  label: '${hostCriterionTitle(c)}: ${p.valueLine(c)}',
                  mustHave: p.isMustHave(c),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          homiziText(
            context,
            'Top match profiles now rank seekers by this list. A must-have miss moves a seeker to Other profiles.',
          ),
          style: const TextStyle(color: HomiziColors.ink),
        ),
        const SizedBox(height: 16),
        ShGradientButton(
          buttonKey: const Key('priority-see-top-matches'),
          label: 'See Top Match Profiles',
          icon: Icons.groups_outlined,
          onPressed: () => context.push(RoutePaths.hostTopMatches),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('priority-saved-done'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HomiziColors.brandDeepRed,
            minimumSize: const Size.fromHeight(46),
          ),
          onPressed: () => context.go(RoutePaths.hostOptions),
          child: Text(homiziText(context, 'Done')),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.rowKey,
    required this.rank,
    required this.label,
    required this.mustHave,
  });

  final Key rowKey;
  final int rank;
  final String label;
  final bool mustHave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          PriorityBadge(rank: rank),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              homiziText(context, label),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          PriorityTypeChip(mustHave: mustHave),
        ],
      ),
    );
  }
}

class _BetterMatches extends StatelessWidget {
  const _BetterMatches();

  @override
  Widget build(BuildContext context) {
    const lines = [
      'Matches based on your priority ranking',
      'A home that misses a must-have stays out of the top band',
      'Flexible preferences still count, just less',
    ];
    return Container(
      key: const Key('priority-better-matches'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiziColors.successWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: HomiziColors.success),
              const SizedBox(width: 8),
              Text(
                homiziText(context, 'Get better matches'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: HomiziColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      homiziText(context, line),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.listing, required this.match});

  final Listing listing;
  final ListingMatch match;

  @override
  Widget build(BuildContext context) {
    final factors = match.factors.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HomiziColors.line),
        ),
        child: InkWell(
          key: Key('priority-preview-${listing.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(RoutePaths.listing(listing.id)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 92,
                    height: 92,
                    child: ListingPhoto(
                      asset: listing.photoAssets.isEmpty
                          ? null
                          : listing.photoAssets.first,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, listing.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${formatInr(listing.rentInr)} / ${homiziText(context, 'month')}',
                        style: const TextStyle(
                          color: HomiziColors.inkSoft,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (var i = 0; i < factors.length; i++)
                            _FactorChip(
                              rank: i + 1,
                              matched: factors[i].matched,
                              partly:
                                  !factors[i].matched && factors[i].points > 0,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ShMatchPill(
                  match: match,
                  pillKey: Key('priority-preview-match-${listing.id}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FactorChip extends StatelessWidget {
  const _FactorChip({
    required this.rank,
    required this.matched,
    required this.partly,
  });

  final int rank;
  final bool matched;

  /// Near, not exact: counts part of its weight.
  final bool partly;

  @override
  Widget build(BuildContext context) {
    final ink = matched
        ? HomiziColors.success
        : partly
        ? HomiziColors.warning
        : HomiziColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: matched
            ? HomiziColors.successWash
            : partly
            ? HomiziColors.warningWash
            : HomiziColors.errorWash,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'P$rank',
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          Icon(
            matched
                ? Icons.check
                : partly
                ? Icons.remove
                : Icons.close,
            size: 13,
            color: ink,
            semanticLabel: matched
                ? 'fits'
                : partly
                ? 'partly fits'
                : 'misses',
          ),
        ],
      ),
    );
  }
}

class _ReadinessRing extends StatelessWidget {
  const _ReadinessRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('priority-readiness'),
      width: 150,
      height: 150,
      child: CustomPaint(
        painter: _RingPainter(percent / 100),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                homiziText(context, 'Match readiness'),
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  fontSize: 12,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = HomiziColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawArc(rect.deflate(8), 0, math.pi * 2, false, track);
    final arc = Paint()
      ..shader = const SweepGradient(
        colors: [
          HomiziColors.brandYellow,
          HomiziColors.logoOrange,
          HomiziColors.success,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14;
    canvas.drawArc(
      rect.deflate(8),
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0, 1),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
