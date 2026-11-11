import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// One fact painted as a soft pill on a swipe card.
class HomiziSwipeChip {
  const HomiziSwipeChip({
    required this.label,
    this.chipKey,
    this.background = HomiziColors.white,
    this.foreground = HomiziColors.ink,
    this.onTap,
  });

  final String label;
  final Key? chipKey;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;
}

/// A round action on the bottom of a swipe card.
class HomiziSwipeAction {
  const HomiziSwipeAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.actionKey,
    this.filled = false,
    this.size = 48,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Key? actionKey;
  final bool filled;
  final double size;
}

/// Optional match or score pill. The slot stays empty when a deck has no score.
class HomiziSwipeBadge {
  const HomiziSwipeBadge({
    required this.label,
    required this.background,
    required this.foreground,
    this.badgeKey,
    this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Key? badgeKey;
  final VoidCallback? onTap;
}

/// Full-bleed swipe card shared by every Homizi deck.
///
/// Photo, gradient, title, verified tick, chips, an optional score badge,
/// and round actions. Drag callbacks let a deck move the card. A parent that
/// already owns the drag (the shared swipe surface) leaves them null.
class HomiziSwipeCard extends StatelessWidget {
  const HomiziSwipeCard({
    required this.title,
    required this.photo,
    this.subtitle = '',
    this.chips = const [],
    this.actions = const [],
    this.badge,
    this.verified = false,
    this.verifiedKey,
    this.onTap,
    this.onDragUpdate,
    this.onDragEnd,
    this.cardKey,
    this.busy = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget photo;
  final List<HomiziSwipeChip> chips;
  final List<HomiziSwipeAction> actions;
  final HomiziSwipeBadge? badge;
  final bool verified;
  final Key? verifiedKey;
  final VoidCallback? onTap;
  final ValueChanged<double>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final Key? cardKey;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final spoken = homiziText(context, title);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              key: cardKey,
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : onTap,
              onHorizontalDragUpdate: busy || onDragUpdate == null
                  ? null
                  : (details) => onDragUpdate!(details.delta.dx),
              onHorizontalDragEnd: busy || onDragEnd == null
                  ? null
                  : (_) => onDragEnd!(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo,
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          HomiziColors.clear,
                          HomiziColors.ink.withValues(alpha: 0.2),
                          HomiziColors.ink,
                        ],
                        stops: const [0.28, 0.52, 0.74],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 86,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                spoken,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: HomiziColors.white,
                                ),
                              ),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 8),
                              _VerifiedTick(tickKey: verifiedKey),
                            ],
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            homiziText(context, subtitle),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: HomiziColors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final chip in chips) _Chip(chip: chip),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(top: 12, right: 12, child: _Badge(badge: badge!)),
            if (actions.isNotEmpty)
              Positioned(
                left: 12,
                right: 12,
                bottom: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final action in actions) _RoundAction(action: action),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedTick extends StatelessWidget {
  const _VerifiedTick({required this.tickKey});

  final Key? tickKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: homiziText(context, 'Verified'),
      child: DecoratedBox(
        key: tickKey,
        decoration: const BoxDecoration(
          color: HomiziColors.success,
          shape: BoxShape.circle,
        ),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: Icon(Icons.check, size: 14, color: HomiziColors.onSuccess),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip});

  final HomiziSwipeChip chip;

  @override
  Widget build(BuildContext context) {
    final pill = DecoratedBox(
      key: chip.chipKey,
      decoration: BoxDecoration(
        color: chip.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            homiziText(context, chip.label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: chip.foreground,
            ),
          ),
        ),
      ),
    );
    final tap = chip.onTap;
    if (tap == null) {
      return pill;
    }
    return GestureDetector(onTap: tap, child: pill);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge});

  final HomiziSwipeBadge badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: badge.badgeKey,
      color: badge.background,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: badge.onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            homiziText(context, badge.label),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: badge.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.action});

  final HomiziSwipeAction action;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onPressed != null;
    final label = homiziText(context, action.tooltip);
    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: HomiziColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: action.filled ? HomiziColors.accent : HomiziColors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: action.actionKey,
            onTap: action.onPressed,
            customBorder: const CircleBorder(),
            child: Semantics(
              button: true,
              enabled: enabled,
              label: label,
              child: SizedBox(
                width: action.size,
                height: action.size,
                child: Icon(
                  action.icon,
                  size: 22,
                  color: enabled ? HomiziColors.ink : HomiziColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
