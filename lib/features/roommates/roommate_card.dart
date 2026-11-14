import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/shared/widgets/homizi_full_photo_card.dart';

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
    final trust = seeker.trust;
    return HomiziFullPhotoCard(
      cardKey: Key('roommate-card-${seeker.id}'),
      tapKey: Key('roommate-open-${seeker.id}'),
      title: seeker.name,
      photos: [if (seeker.photoRef != null) seeker.photoRef!],
      size: compact ? HomiziFullPhotoSize.compact : HomiziFullPhotoSize.deck,
      verified: trust.anyIdentity || trust.profileComplete,
      onTap: onOpen,
      match: HomiziPhotoMatch(
        percent: seeker.score,
        matchKey: Key('compatibility-chip-${seeker.id}'),
      ),
      chips: [
        HomiziPhotoChip('${seeker.age} · ${seeker.profession}'),
        HomiziPhotoChip(seeker.localityLabel),
        HomiziPhotoChip(seeker.budgetLabel),
        HomiziPhotoChip(seeker.moveInLabel),
        if (trust.aadhaarVerified) const HomiziPhotoChip('Aadhaar verified'),
        if (trust.faceVerified) const HomiziPhotoChip('Face verified'),
        if (!trust.anyIdentity && trust.profileComplete)
          const HomiziPhotoChip('Verified'),
      ],
      actions: [
        HomiziPhotoAction(
          tooltip: 'Compatibility',
          icon: Icons.pie_chart_outline,
          onPressed: onScore,
        ),
        HomiziPhotoAction(
          tooltip: 'Open',
          icon: Icons.favorite,
          filled: true,
          emphasize: !compact,
          onPressed: onOpen,
        ),
      ],
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
    return Stack(
      fit: StackFit.expand,
      children: [
        RoommateCard(seeker: seeker, onScore: onScore, onOpen: onOpen),
        if (like || pass)
          IgnorePointer(
            child: ColoredBox(
              color: (like ? HomiziColors.accent : HomiziColors.line)
                  .withValues(alpha: (dx.abs() / 220).clamp(0.15, 0.45)),
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    homiziText(context, like ? 'Interested' : 'Pass'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
