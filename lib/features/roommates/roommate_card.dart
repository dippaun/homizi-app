import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';

class RoommateCard extends StatelessWidget {
  const RoommateCard({
    required this.seeker,
    required this.onScore,
    this.compact = false,
    super.key,
  });

  final RoommateSeeker seeker;
  final VoidCallback onScore;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      key: Key('roommate-card-${seeker.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: compact ? 96 : 124,
            height: compact ? 148 : 176,
            child: ListingPhoto(asset: seeker.photoRef),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '$score%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              height: 1.1,
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
        Icons.verified_outlined,
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
    required this.dx,
    super.key,
  });

  final RoommateSeeker seeker;
  final VoidCallback onScore;
  final double dx;

  @override
  Widget build(BuildContext context) {
    final like = dx > 16;
    final pass = dx < -16;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListingPhoto(asset: seeker.photoRef),
                Positioned(
                  right: 16,
                  top: 16,
                  child: CompatibilityChip(
                    seekerId: seeker.id,
                    score: seeker.score,
                    onPressed: onScore,
                  ),
                ),
                if (like || pass)
                  IgnorePointer(
                    child: ColoredBox(
                      color: (like ? HomiziColors.accent : HomiziColors.line)
                          .withValues(alpha: (dx.abs() / 220).clamp(0.15, 0.5)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seeker.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text('${seeker.age} · ${seeker.profession}'),
                    if (seeker.trust.anyIdentity) ...[
                      const SizedBox(height: 10),
                      IdentityBadgeRow(badges: seeker.trust),
                    ],
                    const SizedBox(height: 10),
                    Text(seeker.localityLabel),
                    const SizedBox(height: 4),
                    Text(seeker.budgetLabel),
                    const SizedBox(height: 4),
                    Text(homiziText(context, seeker.moveInLabel)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
