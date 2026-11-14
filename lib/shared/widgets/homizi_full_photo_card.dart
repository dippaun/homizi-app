import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/search_flow/flow_score.dart';

enum HomiziFullPhotoSize { deck, compact }

enum HomiziPhotoChipTint { white, wash }

/// One label drawn on the photo, in the same pill as the home rental card.
class HomiziPhotoChip {
  const HomiziPhotoChip(
    this.label, {
    this.chipKey,
    this.tint = HomiziPhotoChipTint.white,
  });

  final String label;
  final Key? chipKey;
  final HomiziPhotoChipTint tint;
}

/// Round action on the photo. A [label] widens it into a pill.
class HomiziPhotoAction {
  const HomiziPhotoAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.actionKey,
    this.filled = false,
    this.emphasize = false,
    this.label,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Key? actionKey;
  final bool filled;
  final bool emphasize;
  final String? label;
}

/// Match pill. Colour follows the 70 / 40 bands, and a hard miss stays red.
class HomiziPhotoMatch {
  const HomiziPhotoMatch({
    required this.percent,
    this.importantMismatch = false,
    this.matchKey = const Key('swipe-match-score'),
  });

  final int percent;
  final bool importantMismatch;
  final Key matchKey;
}

/// The full-bleed photo card from the home rental deck.
///
/// Lists use [HomiziFullPhotoSize.deck]. Mutual interest uses
/// [HomiziFullPhotoSize.compact] in a two-column grid. One widget, so the
/// title, chips, verified tick, and actions stay the same shape.
class HomiziFullPhotoCard extends StatelessWidget {
  const HomiziFullPhotoCard({
    required this.title,
    super.key,
    this.photos = const [],
    this.chips = const [],
    this.actions = const [],
    this.lines = const [],
    this.badges = const [],
    this.size = HomiziFullPhotoSize.deck,
    this.verified = false,
    this.match,
    this.strength,
    this.footer,
    this.onTap,
    this.onDragUpdate,
    this.onDragEnd,
    this.cardKey,
    this.tapKey,
    this.titleKey,
    this.photoKey,
    this.verifiedKey,
    this.linesKey,
    this.badgesKey,
    this.semanticLabel,
  });

  final String title;
  final List<String> photos;
  final List<HomiziPhotoChip> chips;
  final List<HomiziPhotoAction> actions;
  final List<String> lines;
  final List<String> badges;
  final HomiziFullPhotoSize size;
  final bool verified;
  final HomiziPhotoMatch? match;
  final String? strength;
  final Widget? footer;
  final VoidCallback? onTap;
  final ValueChanged<double>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final Key? cardKey;
  final Key? tapKey;
  final Key? titleKey;
  final Key? photoKey;
  final Key? verifiedKey;
  final Key? linesKey;
  final Key? badgesKey;
  final String? semanticLabel;

  bool get _compact => size == HomiziFullPhotoSize.compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fill =
            constraints.maxHeight.isFinite && constraints.maxHeight > 180;
        final height = fill
            ? constraints.maxHeight
            : (_compact ? 248.0 : _deckHeight(constraints.maxWidth));
        return SizedBox(height: height, child: _face(context));
      },
    );
  }

  double _deckHeight(double width) {
    final usable = width.isFinite ? width : 360.0;
    final scaled = usable * (_compact ? 1.35 : 1.28);
    if (_compact) {
      return scaled.clamp(220.0, 280.0);
    }
    final extra = footer == null && lines.isEmpty ? 0.0 : 48.0;
    return (scaled + extra).clamp(420.0, 560.0);
  }

  Widget _face(BuildContext context) {
    final radius = _compact ? 20.0 : 28.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onHorizontalDragUpdate: onDragUpdate == null
          ? null
          : (details) => onDragUpdate!(details.delta.dx),
      onHorizontalDragEnd: onDragEnd == null ? null : (_) => onDragEnd!(),
      child: KeyedSubtree(
        key: tapKey,
        child: DecoratedBox(
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
                _photo(context),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          HomiziColors.clear,
                          HomiziColors.ink,
                          HomiziColors.ink,
                        ],
                        stops: [0.28, 0.62, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _compact ? 10 : 16,
                  right: _compact ? 10 : 16,
                  top: _compact ? 36 : 48,
                  bottom: actions.isEmpty
                      ? (_compact ? 12 : 16)
                      : (_compact ? 58 : 86),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _copy(context),
                      if (footer != null) ...[
                        const SizedBox(height: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: HomiziColors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            child: footer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (cardKey != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _compact ? 96 : 180,
                    child: GestureDetector(
                      key: cardKey,
                      behavior: HitTestBehavior.translucent,
                      onTap: onTap,
                    ),
                  ),
                if (actions.isNotEmpty)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: _compact ? 8 : 14,
                    child: _actionRow(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photo(BuildContext context) {
    final label = semanticLabel ?? title;
    final frames = [
      for (final photo in photos)
        if (photo.trim().isNotEmpty) photo,
    ];
    if (frames.isEmpty) {
      return ColoredBox(
        color: HomiziColors.mist,
        child: Center(
          child: Text(
            _initials(title),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: _compact ? 28 : 42,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
        ),
      );
    }
    if (frames.length == 1) {
      return ListingPhoto(
        key: photoKey,
        asset: frames.first,
        semanticLabel: label,
      );
    }
    return PageView.builder(
      itemCount: frames.length,
      itemBuilder: (context, index) {
        return ListingPhoto(
          key: index == 0 ? photoKey : null,
          asset: frames[index],
          semanticLabel: label,
        );
      },
    );
  }

  Widget _copy(BuildContext context) {
    final titleSize = _compact ? 15.0 : 22.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                homiziText(context, title),
                key: titleKey,
                maxLines: _compact ? 2 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: titleSize,
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
        if (match != null) ...[
          SizedBox(height: _compact ? 6 : 8),
          _MatchPill(match: match!, compact: _compact),
        ],
        if (strength != null && strength!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            homiziText(context, strength!),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              color: HomiziColors.white,
            ),
          ),
        ],
        if (chips.isNotEmpty || lines.isNotEmpty || badges.isNotEmpty) ...[
          SizedBox(height: _compact ? 6 : 10),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _compact ? 72 : (footer == null ? 132 : 88),
            ),
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxHeight: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (chips.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final chip in chips)
                            _Chip(chip: chip, compact: _compact),
                        ],
                      ),
                    if (lines.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Column(
                        key: linesKey,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in lines)
                            Text(
                              homiziText(context, line),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                height: 1.35,
                                color: HomiziColors.white,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        key: badgesKey,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final badge in badges)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified,
                                  size: 14,
                                  color: HomiziColors.accentWash,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  homiziText(context, badge),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    color: HomiziColors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _actionRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final action in actions)
          _Action(action: action, compact: _compact),
      ],
    );
  }
}

class _VerifiedTick extends StatelessWidget {
  const _VerifiedTick({this.tickKey});

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
  const _Chip({required this.chip, required this.compact});

  final HomiziPhotoChip chip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final wash = chip.tint == HomiziPhotoChipTint.wash;
    return DecoratedBox(
      key: chip.chipKey,
      decoration: BoxDecoration(
        color: wash ? HomiziColors.accentWash : HomiziColors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        child: Text(
          homiziText(context, chip.label),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: compact ? 11 : 12,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: HomiziColors.ink,
          ),
        ),
      ),
    );
  }
}

class _MatchPill extends StatelessWidget {
  const _MatchPill({required this.match, required this.compact});

  final HomiziPhotoMatch match;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fill = matchFill(
      match.percent,
      importantMismatch: match.importantMismatch,
    );
    return DecoratedBox(
      key: match.matchKey,
      decoration: BoxDecoration(
        color: fill.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 3 : 6,
        ),
        child: Text(
          homiziText(context, '${match.percent}% Match'),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: compact ? 11 : 13,
            color: fill.foreground,
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.action, required this.compact});

  final HomiziPhotoAction action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onPressed != null;
    final label = homiziText(context, action.tooltip);
    final size = action.emphasize
        ? (compact ? 44.0 : 56.0)
        : (compact ? 36.0 : 48.0);
    final fill = action.filled ? HomiziColors.accent : HomiziColors.white;
    final iconColor = enabled ? HomiziColors.ink : HomiziColors.muted;
    final face = action.label == null
        ? SizedBox(
            width: size,
            height: size,
            child: Icon(action.icon, size: compact ? 18 : 22, color: iconColor),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  homiziText(context, action.label!),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800,
                    color: HomiziColors.ink,
                  ),
                ),
              ],
            ),
          );
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
          color: fill,
          shape: action.label == null
              ? const CircleBorder()
              : const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: action.actionKey,
            onTap: action.onPressed,
            customBorder: action.label == null
                ? const CircleBorder()
                : const StadiumBorder(),
            child: Semantics(
              button: true,
              enabled: enabled,
              label: label,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: size, minHeight: size),
                child: Center(child: face),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'H';
  }
  if (parts.length == 1) {
    return parts.first[0].toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

/// Strength line that matches the colour bands on the pill.
String? homiziPhotoStrength(HomiziPhotoMatch? match) {
  if (match == null) {
    return null;
  }
  return matchStrengthLabel(
    cappedStrength(match.percent, importantMismatch: match.importantMismatch),
  );
}
