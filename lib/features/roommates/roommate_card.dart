import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/portrait_asset.dart';
import 'package:homizi/core/widgets/homizi_swipe_card.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/search_flow/flow_score.dart';

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
    final fill = matchFill(seeker.score, importantMismatch: seeker.score < 40);
    final locality = chipPlace(
      seeker.traits.localities.isEmpty
          ? seeker.traits.city
          : seeker.traits.localities.first,
    );
    final budget = _budgetChip(seeker);
    final card = HomiziSwipeCard(
      compact: compact,
      cardKey: Key('roommate-open-${seeker.id}'),
      title: '${seeker.name}, ${seeker.age}',
      verified: seeker.trust.anyIdentity || seeker.trust.profileComplete,
      onTap: onOpen,
      photo: ListingPhoto(
        asset: _photo(seeker),
        semanticLabel: seeker.name,
        alignment: portraitAlignment,
        fit: BoxFit.fitWidth,
      ),
      chips: compact
          ? [HomiziSwipeChip(label: budget), HomiziSwipeChip(label: locality)]
          : [
              HomiziSwipeChip(label: budget),
              HomiziSwipeChip(label: locality),
              HomiziSwipeChip(label: seeker.profession),
            ],
      badge: HomiziSwipeBadge(
        badgeKey: Key('compatibility-chip-${seeker.id}'),
        label: '${seeker.score}% match',
        background: fill.background,
        foreground: fill.foreground,
        onTap: onScore,
      ),
      actions: compact
          ? const []
          : [
              HomiziSwipeAction(
                tooltip: 'View profile',
                icon: Icons.person_outline,
                onPressed: onOpen,
              ),
            ],
    );
    return KeyedSubtree(
      key: Key('roommate-card-${seeker.id}'),
      child: compact
          ? card
          : LayoutBuilder(
              builder: (context, constraints) {
                final raw = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 390.0;
                final width = raw > 480 ? 480.0 : raw;
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width,
                    height: homiziSwipeCardHeight(width),
                    child: card,
                  ),
                );
              },
            ),
    );
  }
}

String _photo(RoommateSeeker seeker) {
  final given = seeker.photoRef?.trim();
  if (given != null && given.isNotEmpty) {
    return given;
  }
  return portraitForPerson(
    name: seeker.name,
    gender: seeker.traits.gender ?? '',
  );
}

String _budgetChip(RoommateSeeker seeker) {
  final low = seeker.traits.budgetMinInr;
  final high = seeker.traits.budgetMaxInr;
  if (low != null && high != null) {
    return chipMoneySpan(low, high);
  }
  if (low != null) {
    return formatInrCompact(low);
  }
  if (high != null) {
    return formatInrCompact(high);
  }
  return seeker.budgetLabel;
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
    final fill = matchFill(score, importantMismatch: score < 40);
    return Material(
      color: fill.background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('compatibility-chip-$seekerId'),
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
            maxWidth: 96,
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
                    color: fill.foreground,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  homiziText(context, 'match'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: fill.foreground,
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
    return Transform.translate(
      offset: Offset(dx, 0),
      child: RoommateCard(seeker: seeker, onScore: onScore, onOpen: onOpen),
    );
  }
}
