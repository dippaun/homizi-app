import 'package:flutter/material.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/shared/widgets/homizi_match_card.dart';

enum HomiziFullPhotoSize { deck, compact }

enum HomiziPhotoChipTint { white, wash }

/// One label on the shared card.
class HomiziPhotoChip {
  const HomiziPhotoChip(
    this.label, {
    this.chipKey,
    this.icon,
    this.tint = HomiziPhotoChipTint.white,
  });

  final String label;
  final Key? chipKey;
  final IconData? icon;
  final HomiziPhotoChipTint tint;
}

/// Round action on the shared card. A [label] widens it into a pill.
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
    this.onTap,
  });

  final int percent;
  final bool importantMismatch;
  final Key matchKey;
  final VoidCallback? onTap;
}

/// Older call sites. Every one of them now paints [HomiziMatchCard], so the
/// dark full-bleed card is not reachable.
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
    this.price,
    this.locality,
    this.person = false,
    this.photoHeight,
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
  final String? price;
  final String? locality;
  final bool person;
  final double? photoHeight;
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

  @override
  Widget build(BuildContext context) {
    final scored = match;
    return HomiziMatchCard(
      title: title,
      price: price,
      locality: locality,
      photos: photos,
      photoSeed: title,
      person: person,
      photoHeight: photoHeight,
      compact: size == HomiziFullPhotoSize.compact,
      verified: verified,
      strength: strength,
      matchPercent: scored?.percent,
      importantMismatch: scored?.importantMismatch ?? false,
      matchKey: scored?.matchKey,
      onMatchTap: scored?.onTap,
      onTap: onTap,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      footer: footer,
      cardKey: cardKey,
      tapKey: tapKey,
      titleKey: titleKey,
      photoKey: photoKey,
      verifiedKey: verifiedKey,
      linesKey: linesKey,
      badgesKey: badgesKey,
      semanticLabel: semanticLabel,
      lines: lines,
      badges: badges,
      chips: [
        for (final chip in chips)
          HomiziCardChip(
            chip.label,
            chipKey: chip.chipKey,
            icon: chip.icon,
            wash: chip.tint == HomiziPhotoChipTint.wash,
          ),
      ],
      actions: [
        for (final action in actions)
          HomiziCardAction(
            tooltip: action.tooltip,
            icon: action.icon,
            onPressed: action.onPressed,
            actionKey: action.actionKey,
            label: action.label,
            primary: action.filled || action.emphasize,
            filled: action.filled,
          ),
      ],
    );
  }
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
