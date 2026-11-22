import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/search_flow/flow_score.dart';

/// Bundled Indian home photos. Cards use these when a listing has no frame.
const homiziHomePhotoFallbacks = <String>[
  'assets/images/real/living.webp',
  'assets/images/real/living_b.webp',
  'assets/images/real/bedroom.webp',
  'assets/images/real/bedroom_b.webp',
  'assets/images/real/kitchen.webp',
  'assets/images/real/apartment.webp',
  'assets/images/real/exterior.webp',
  'assets/images/real/balcony.webp',
  'assets/images/real/dining.webp',
  'assets/images/real/bath.webp',
];

/// Bundled portraits. Person cards use these when a profile has no photo.
const homiziPersonPhotoFallbacks = <String>[
  'assets/avatars/avatar_01.webp',
  'assets/avatars/avatar_02.webp',
  'assets/avatars/avatar_03.webp',
  'assets/avatars/avatar_04.webp',
  'assets/avatars/avatar_05.webp',
  'assets/avatars/avatar_06.webp',
];

/// Stable stand-in so the same home or person always gets the same photo.
String homiziFallbackPhoto(String seed, {bool person = false}) {
  if (person) {
    return placeholderAvatarFor(seed);
  }
  const bank = homiziHomePhotoFallbacks;
  if (bank.isEmpty) {
    return '';
  }
  final index = seed.hashCode.abs() % bank.length;
  return bank[index];
}

/// Real frames only. An empty list becomes one bundled photo.
List<String> homiziCardPhotos(
  List<String> photos, {
  required String seed,
  bool person = false,
}) {
  final frames = <String>[];
  for (final photo in photos) {
    final value = photo.trim();
    if (photoKind(value) == PhotoKind.empty) {
      continue;
    }
    frames.add(value);
  }
  if (frames.isEmpty) {
    final fallback = homiziFallbackPhoto(seed, person: person);
    if (fallback.isNotEmpty) {
      frames.add(fallback);
    }
  }
  return frames;
}

/// One short label under the title. Verified labels use the green wash.
class HomiziCardChip {
  const HomiziCardChip(
    this.label, {
    this.chipKey,
    this.icon,
    this.verified = false,
    this.wash = false,
  });

  final String label;
  final Key? chipKey;
  final IconData? icon;
  final bool verified;
  final bool wash;
}

/// A round or labelled control on the shared card.
class HomiziCardAction {
  const HomiziCardAction({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.actionKey,
    this.label,
    this.primary = false,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Key? actionKey;
  final String? label;
  final bool primary;
  final bool filled;
}

/// The one listing and person card.
///
/// Photo, title, price, locality, a few chips, the match pill from
/// [scoreMatch], and the same actions. Person cards use the same layout
/// with a portrait. A missing photo is a bundled real photo, never a grey
/// box or a photo-count pill.
class HomiziMatchCard extends StatelessWidget {
  const HomiziMatchCard({
    required this.title,
    super.key,
    this.price,
    this.locality,
    this.photos = const [],
    this.photoSeed,
    this.person = false,
    this.photoHeight,
    this.chips = const [],
    this.qualityIcons = const [],
    this.lines = const [],
    this.badges = const [],
    this.matchPercent,
    this.importantMismatch = false,
    this.strength,
    this.verified = false,
    this.onTap,
    this.onMatchTap,
    this.onDragUpdate,
    this.onDragEnd,
    this.actions = const [],
    this.footer,
    this.compact = false,
    this.cardKey,
    this.tapKey,
    this.titleKey,
    this.priceKey,
    this.placeKey,
    this.photoKey,
    this.verifiedKey,
    this.matchKey,
    this.linesKey,
    this.badgesKey,
    this.semanticLabel,
  });

  final String title;
  final String? price;
  final String? locality;
  final List<String> photos;
  final String? photoSeed;
  final bool person;

  /// Taller photo-first frame for a swipe card. Null keeps the compact crop.
  final double? photoHeight;
  final List<HomiziCardChip> chips;

  /// Roommate quality symbols. The first icon is painted on the right.
  final List<(IconData, String)> qualityIcons;
  final List<String> lines;
  final List<String> badges;
  final int? matchPercent;
  final bool importantMismatch;
  final String? strength;
  final bool verified;
  final VoidCallback? onTap;
  final VoidCallback? onMatchTap;
  final ValueChanged<double>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final List<HomiziCardAction> actions;
  final Widget? footer;
  final bool compact;
  final Key? cardKey;
  final Key? tapKey;
  final Key? titleKey;
  final Key? priceKey;
  final Key? placeKey;
  final Key? photoKey;
  final Key? verifiedKey;
  final Key? matchKey;
  final Key? linesKey;
  final Key? badgesKey;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fill =
            constraints.maxHeight.isFinite && constraints.maxHeight > 240;
        final face = _face(context, fill: fill);
        final tappable = onTap == null
            ? face
            : InkWell(
                key: tapKey,
                onTap: onTap,
                hoverColor: HomiziColors.clear,
                child: face,
              );
        final dragged = onDragUpdate == null && onDragEnd == null
            ? tappable
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: onDragUpdate == null
                    ? null
                    : (details) => onDragUpdate!(details.delta.dx),
                onHorizontalDragEnd: onDragEnd == null
                    ? null
                    : (_) => onDragEnd!(),
                child: tappable,
              );
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: HomiziColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            key: cardKey,
            color: HomiziColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: dragged,
          ),
        );
      },
    );
  }

  Widget _face(BuildContext context, {required bool fill}) {
    final photo = _photo(context);
    final copy = _copy(context);
    if (!fill) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: photoHeight ?? (compact ? 132 : 176), child: photo),
          copy,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: photo),
        Flexible(child: SingleChildScrollView(child: copy)),
      ],
    );
  }

  Widget _photo(BuildContext context) {
    final seed = photoSeed ?? title;
    final frames = homiziCardPhotos(photos, seed: seed, person: person);
    final label = semanticLabel ?? title;
    final fallback = homiziFallbackPhoto('$seed-stand-in', person: person);
    Widget frameAt(int index) {
      return ListingPhoto(
        key: index == 0 ? photoKey : null,
        asset: frames[index],
        fallbackAsset: fallback,
        semanticLabel: label,
        alignment: person ? const Alignment(0, -0.3) : Alignment.center,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (frames.isEmpty)
          ListingPhoto(
            fallbackAsset: fallback,
            semanticLabel: label,
            alignment: person ? const Alignment(0, -0.3) : Alignment.center,
          )
        else if (frames.length == 1)
          frameAt(0)
        else
          PageView.builder(
            itemCount: frames.length,
            itemBuilder: (context, index) => frameAt(index),
          ),
        if (matchPercent != null)
          Positioned(
            left: 12,
            top: 12,
            child: _MatchPill(
              percent: matchPercent!,
              importantMismatch: importantMismatch,
              matchKey: matchKey,
              compact: compact,
              onTap: onMatchTap,
            ),
          ),
      ],
    );
  }

  Widget _copy(BuildContext context) {
    final shown = _visibleChips(chips);
    final priceLabel = price?.trim() ?? '';
    final place = locality?.trim() ?? '';
    final strengthLabel = strength?.trim() ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  homiziText(context, title),
                  key: titleKey,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: compact ? 15 : 18,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: HomiziColors.ink,
                  ),
                ),
              ),
              if (qualityIcons.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    for (final item in qualityIcons.take(4))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4),
                        child: Tooltip(
                          message: homiziText(context, item.$2),
                          child: Icon(
                            item.$1,
                            size: 18,
                            color: HomiziColors.logoOrange,
                          ),
                        ),
                      ),
                  ],
                ),
              if (verified) ...[
                const SizedBox(width: 8),
                _VerifiedTick(tickKey: verifiedKey),
              ],
            ],
          ),
          if (priceLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              homiziText(context, priceLabel),
              key: priceKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w800,
                color: HomiziColors.logoOrange,
              ),
            ),
          ],
          if (place.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: HomiziColors.muted,
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    homiziText(context, place),
                    key: placeKey,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: HomiziColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (strengthLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              homiziText(context, strengthLabel),
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                color: _strengthColor(matchPercent, importantMismatch),
              ),
            ),
          ],
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in shown) _Chip(chip: chip, compact: compact),
              ],
            ),
          ],
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
                      color: HomiziColors.inkSoft,
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
                        color: HomiziColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        homiziText(context, badge),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          color: HomiziColors.success,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 8), footer!],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [for (final action in actions) _Action(action: action)],
            ),
          ],
        ],
      ),
    );
  }
}

/// Photo counts, pending verification, and listed dates stay off the card.
List<HomiziCardChip> _visibleChips(List<HomiziCardChip> chips) {
  final shown = <HomiziCardChip>[];
  for (final chip in chips) {
    final label = chip.label.trim();
    if (label.isEmpty || _hiddenChip(label)) {
      continue;
    }
    shown.add(chip);
    if (shown.length == 4) {
      break;
    }
  }
  return shown;
}

bool _hiddenChip(String label) {
  if (RegExp(r'^\d+ photos$').hasMatch(label)) {
    return true;
  }
  if (label == 'Verification pending') {
    return true;
  }
  if (label.startsWith('Listed ')) {
    return true;
  }
  return false;
}

Color _strengthColor(int? percent, bool importantMismatch) {
  final fill = matchFill(percent ?? 0, importantMismatch: importantMismatch);
  if (fill.background == HomiziColors.success) {
    return HomiziColors.success;
  }
  if (fill.background == HomiziColors.error) {
    return HomiziColors.error;
  }
  return HomiziColors.warning;
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

/// Paints one [HomiziCardChip], including its icon.
class HomiziChipView extends StatelessWidget {
  const HomiziChipView({required this.chip, this.compact = false, super.key});

  final HomiziCardChip chip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _Chip(chip: chip, compact: compact);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip, required this.compact});

  final HomiziCardChip chip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final verified = chip.verified || _looksVerified(chip.label);
    final marked = chip.icon != null;
    final background = verified
        ? HomiziColors.successWash
        : marked
        ? HomiziColors.logoOrange.withValues(alpha: 0.14)
        : chip.wash
        ? HomiziColors.accentWash
        : HomiziColors.soft;
    final ink = verified
        ? HomiziColors.success
        : marked
        ? HomiziColors.logoOrange
        : HomiziColors.ink;
    return DecoratedBox(
      key: chip.chipKey,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chip.icon != null) ...[
              Icon(chip.icon, size: compact ? 13 : 15, color: ink),
              const SizedBox(width: 4),
            ],
            Text(
              homiziText(context, chip.label),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: compact ? 11 : 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _looksVerified(String label) {
  return label.toLowerCase().contains('verified');
}

class _MatchPill extends StatelessWidget {
  const _MatchPill({
    required this.percent,
    required this.importantMismatch,
    required this.compact,
    this.matchKey,
    this.onTap,
  });

  final int percent;
  final bool importantMismatch;
  final bool compact;
  final Key? matchKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = matchFill(percent, importantMismatch: importantMismatch);
    final pill = DecoratedBox(
      key: matchKey,
      decoration: BoxDecoration(
        color: fill.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        child: Text(
          homiziText(context, '$percent% Match'),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: compact ? 11 : 13,
            color: fill.foreground,
          ),
        ),
      ),
    );
    final tap = onTap;
    if (tap == null) {
      return pill;
    }
    return GestureDetector(
      onTap: tap,
      behavior: HitTestBehavior.opaque,
      child: pill,
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.action});

  final HomiziCardAction action;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onPressed != null;
    final label = homiziText(context, action.tooltip);
    final primary = action.primary || action.filled;
    final fill = primary ? HomiziColors.logoOrange : HomiziColors.white;
    final iconColor = enabled ? HomiziColors.ink : HomiziColors.muted;
    final face = action.label == null
        ? SizedBox(
            width: 44,
            height: 44,
            child: Icon(action.icon, size: 20, color: iconColor),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}
