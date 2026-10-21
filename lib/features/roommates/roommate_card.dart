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
                InitialsPortrait(
                  name: seeker.name,
                  gender: seeker.traits.gender,
                ),
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color:
                              (like ? HomiziColors.accent : HomiziColors.line)
                                  .withValues(
                                    alpha: (dx.abs() / 220).clamp(0.15, 0.5),
                                  ),
                        ),
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              homiziText(context, like ? 'Interested' : 'Pass'),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: HomiziColors.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 8),
                    TextButton(
                      key: Key('roommate-view-${seeker.id}'),
                      onPressed: onOpen,
                      child: Text(homiziText(context, 'View profile')),
                    ),
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
