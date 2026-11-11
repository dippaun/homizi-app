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

/// Home deck height. Every full-size card uses this so the action row
/// sits in the same place and stays above the bottom nav.
double homiziSwipeCardHeight(double width) {
  final raw = width * 1.28;
  if (raw < 420) {
    return 420;
  }
  if (raw > 560) {
    return 560;
  }
  return raw;
}

/// Yellow and gold never take white text. Ink stays readable on them.
Color homiziBadgeForeground({
  required Color background,
  required Color foreground,
}) {
  if (foreground != HomiziColors.white) {
    return foreground;
  }
  final value = background.toARGB32();
  const yellows = <Color>[
    HomiziColors.brandYellow,
    HomiziColors.brandGolden,
    HomiziColors.accentWash,
  ];
  for (final yellow in yellows) {
    if (yellow.toARGB32() == value) {
      return HomiziColors.ink;
    }
  }
  return foreground;
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
    this.compact = false,
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

  /// Scaled-down grid card. Same photo, gradient, title, and chips.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spoken = homiziText(context, title);
    final radius = compact ? 16.0 : 28.0;
    final chipLimit = compact ? 2 : 4;
    final shown = chips.length <= chipLimit
        ? chips
        : chips.sublist(0, chipLimit);
    final textBottom = actions.isEmpty
        ? (compact ? 12.0 : 20.0)
        : (compact ? 52.0 : 96.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
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
                          HomiziColors.clear,
                          HomiziColors.ink.withValues(alpha: 0.55),
                          HomiziColors.ink,
                          HomiziColors.ink,
                        ],
                        stops: const [0.0, 0.40, 0.62, 0.78, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: compact ? 10 : 16,
                    right: compact ? 10 : 16,
                    bottom: textBottom,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                spoken,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: compact ? 14 : 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: HomiziColors.white,
                                ),
                              ),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 8),
                              _VerifiedTick(
                                tickKey: verifiedKey,
                                compact: compact,
                              ),
                            ],
                          ],
                        ),
                        if (!compact && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            homiziText(context, subtitle),
                            maxLines: 1,
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
                        if (shown.isNotEmpty) ...[
                          SizedBox(height: compact ? 6 : 10),
                          _FittingChips(chips: shown, compact: compact),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: compact ? 8 : 12,
                right: compact ? 8 : 12,
                child: _Badge(badge: badge!, compact: compact),
              ),
            if (actions.isNotEmpty)
              Positioned(
                left: compact ? 8 : 12,
                right: compact ? 8 : 12,
                bottom: compact ? 8 : 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final action in actions)
                      _RoundAction(action: action, compact: compact),
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
  const _VerifiedTick({required this.tickKey, required this.compact});

  final Key? tickKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 16.0 : 22.0;
    return Semantics(
      label: homiziText(context, 'Verified'),
      child: DecoratedBox(
        key: tickKey,
        decoration: const BoxDecoration(
          color: HomiziColors.success,
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.check,
            size: compact ? 11 : 14,
            color: HomiziColors.onSuccess,
          ),
        ),
      ),
    );
  }
}

class _FittingChips extends StatelessWidget {
  const _FittingChips({required this.chips, required this.compact});

  final List<HomiziSwipeChip> chips;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final style = _chipStyle(compact);
        final pad = compact ? 16.0 : 20.0;
        const gap = 6.0;
        final kept = <HomiziSwipeChip>[];
        var used = 0.0;
        for (final chip in chips) {
          final label = homiziText(context, chip.label);
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            maxLines: 1,
            textDirection: Directionality.of(context),
          )..layout();
          // A little slack so a chip is never painted wider than the row.
          final width = painter.width + pad + 4;
          if (width > maxWidth) {
            continue;
          }
          final next = kept.isEmpty ? width : used + gap + width;
          if (next > maxWidth) {
            break;
          }
          kept.add(chip);
          used = next;
        }
        return Row(
          children: [
            for (var i = 0; i < kept.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _Chip(chip: kept[i], compact: compact),
            ],
          ],
        );
      },
    );
  }
}

TextStyle _chipStyle(bool compact) {
  return TextStyle(
    fontFamily: 'Inter',
    fontSize: compact ? 11 : 12,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip, required this.compact});

  final HomiziSwipeChip chip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pill = DecoratedBox(
      key: chip.chipKey,
      decoration: BoxDecoration(
        color: chip.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        child: Text(
          homiziText(context, chip.label),
          maxLines: 1,
          softWrap: false,
          style: _chipStyle(compact).copyWith(color: chip.foreground),
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
  const _Badge({required this.badge, required this.compact});

  final HomiziSwipeBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = homiziBadgeForeground(
      background: badge.background,
      foreground: badge.foreground,
    );
    return Material(
      key: badge.badgeKey,
      color: badge.background,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: badge.onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 4 : 6,
          ),
          child: Text(
            homiziText(context, badge.label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.action, required this.compact});

  final HomiziSwipeAction action;
  final bool compact;

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
                width: compact ? 32 : action.size,
                height: compact ? 32 : action.size,
                child: Icon(
                  action.icon,
                  size: compact ? 16 : 22,
                  color: enabled
                      ? (action.filled ? HomiziColors.ink : HomiziColors.ink)
                      : HomiziColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
