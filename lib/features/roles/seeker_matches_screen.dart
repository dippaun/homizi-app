import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/media/portrait_asset.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/homizi_swipe_card.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roles/seeker_match.dart';
import 'package:homizi/features/roles/seeker_providers.dart';
import 'package:homizi/features/search_flow/flow_score.dart';

class SeekerMatchesScreen extends ConsumerStatefulWidget {
  const SeekerMatchesScreen({
    required this.title,
    this.showBrokerBadge = false,
    super.key,
  });

  final String title;
  final bool showBrokerBadge;

  @override
  ConsumerState<SeekerMatchesScreen> createState() =>
      _SeekerMatchesScreenState();
}

class _SeekerMatchesScreenState extends ConsumerState<SeekerMatchesScreen> {
  SeekerMatchPage? _page;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(seekerMatchGatewayProvider).load();
      if (!mounted) {
        return;
      }
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'The seeker list could not be loaded.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final empty = page == null || page.seekers.isEmpty;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, widget.title)),
        actions: [
          if (widget.showBrokerBadge)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: BrokerChip()),
            ),
        ],
      ),
      body: HomiziFrame(
        child: _loading
            ? const LoadingState(message: 'Finding seekers…')
            : _error != null
            ? ErrorState(
                title: 'Seekers unavailable',
                message: _error!,
                onRetry: () => unawaited(_load()),
              )
            : empty
            ? EmptyState(
                key: const Key('seekers-empty'),
                title: 'No matching seekers yet',
                message: 'No discoverable briefs match your listings yet.',
                actionLabel: 'Post a listing',
                onAction: () => context.go(RoutePaths.listingEditor),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Text(homiziText(context, page.basis)),
                  const SizedBox(height: 8),
                  Text(
                    homiziText(
                      context,
                      'Contact stays hidden until you both match and they share it.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final seeker in page.seekers)
                    _SeekerCard(
                      seeker: seeker,
                      onOpen: widget.showBrokerBadge
                          ? () => context.push(
                              RoutePaths.brokerBrief(seeker.requirementId),
                            )
                          : null,
                    ),
                ],
              ),
      ),
    );
  }
}

class _SeekerCard extends StatelessWidget {
  const _SeekerCard({required this.seeker, this.onOpen});

  final SeekerMatch seeker;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final fill = matchFill(seeker.matchPercent, importantMismatch: false);
    final places = seeker.localities.join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 390.0;
          return SizedBox(
            height: homiziSwipeCardHeight(width > 480 ? 480 : width),
            child: HomiziSwipeCard(
              cardKey: Key('seeker-card-${seeker.requirementId}'),
              title: seeker.displayName,
              onTap: onOpen,
              photo: ListingPhoto(
                asset: portraitForName(seeker.displayName),
                semanticLabel: seeker.displayName,
                alignment: portraitAlignment,
              ),
              chips: [
                HomiziSwipeChip(
                  label:
                      '${formatInr(seeker.budgetMinInr)} – ${formatInr(seeker.budgetMaxInr)}',
                ),
                HomiziSwipeChip(label: places.isEmpty ? seeker.city : places),
                HomiziSwipeChip(label: _professionLabel(seeker.profession)),
                HomiziSwipeChip(
                  label: joinRequirementLabels(
                    seeker.roomType.split(','),
                    requirementRoomTypeLabel,
                  ),
                ),
              ],
              badge: HomiziSwipeBadge(
                badgeKey: Key('seeker-match-${seeker.requirementId}'),
                label: '${seeker.matchPercent}% match',
                background: fill.background,
                foreground: fill.foreground,
              ),
              actions: [
                if (onOpen != null)
                  HomiziSwipeAction(
                    tooltip: 'Open',
                    icon: Icons.info_outline,
                    onPressed: onOpen,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _professionLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return 'Working';
  }
  return joinRequirementLabels(trimmed.split(','), requirementProfessionLabel);
}
