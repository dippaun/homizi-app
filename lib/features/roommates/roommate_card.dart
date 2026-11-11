import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/portrait_asset.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_swipe_card.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';

class RoommateCard extends StatelessWidget {
  const RoommateCard({
    required this.seeker,
    required this.onScore,
    required this.onOpen,
    this.compact = false,
    super.key,
  });

  final RoommateSeeker seeker;
  final VoidCallback onScore;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      key: Key('roommate-card-${seeker.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('roommate-open-${seeker.id}'),
        onTap: onOpen,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: compact ? 96 : 124,
              height: compact ? 148 : 176,
              child: InitialsPortrait(
                name: seeker.name,
                gender: seeker.traits.gender,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            seeker.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CompatibilityChip(
                          seekerId: seeker.id,
                          score: seeker.score,
                          onPressed: onScore,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${seeker.age} · ${seeker.profession}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: HomiziColors.inkSoft,
                      ),
                    ),
                    if (seeker.trust.anyIdentity) ...[
                      const SizedBox(height: 8),
                      IdentityBadgeRow(badges: seeker.trust),
                    ] else if (seeker.trust.profileComplete) ...[
                      const SizedBox(height: 8),
                      const _VerifiedChip(),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      seeker.localityLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      seeker.budgetLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      homiziText(context, seeker.moveInLabel),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: HomiziColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompatibilityChip extends StatelessWidget {
  const CompatibilityChip({
    required this.seekerId,
    required this.score,
    required this.onPressed,
    super.key,
  });

  final String seekerId;
  final int score;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.accent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('compatibility-chip-$seekerId'),
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
            maxWidth: 84,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  homiziText(context, 'match'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip();

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: const Icon(
        Icons.check_circle,
        size: 16,
        color: HomiziColors.accent,
      ),
      label: Text(homiziText(context, 'Verified')),
      side: const BorderSide(color: HomiziColors.accent),
      backgroundColor: HomiziColors.accentWash,
    );
  }
}

class RoommateSwipeCard extends StatelessWidget {
  const RoommateSwipeCard({
    required this.seeker,
    required this.onScore,
    required this.onOpen,
    required this.dx,
    super.key,
  });

  final RoommateSeeker seeker;
  final VoidCallback onScore;
  final VoidCallback onOpen;
  final double dx;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(dx, 0),
      child: HomiziSwipeCard(
        title: seeker.name,
        subtitle: '${seeker.age} · ${seeker.profession}',
        verified: seeker.trust.anyIdentity || seeker.trust.profileComplete,
        onTap: onOpen,
        photo: seeker.photoRef == null || seeker.photoRef!.isEmpty
            ? InitialsPortrait(name: seeker.name, gender: seeker.traits.gender)
            : ListingPhoto(
                asset: seeker.photoRef,
                semanticLabel: seeker.name,
                alignment: portraitAlignment,
              ),
        badge: HomiziSwipeBadge(
          label: '${seeker.score}% match',
          background: HomiziColors.accent,
          foreground: HomiziColors.ink,
          onTap: onScore,
        ),
        chips: [
          HomiziSwipeChip(label: seeker.localityLabel),
          HomiziSwipeChip(label: seeker.budgetLabel),
          HomiziSwipeChip(label: seeker.moveInLabel),
        ],
        actions: [
          HomiziSwipeAction(
            actionKey: Key('roommate-view-${seeker.id}'),
            tooltip: 'View profile',
            icon: Icons.person_outline,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
