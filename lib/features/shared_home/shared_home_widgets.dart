import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';

/// Orange-red primary action used across the shared home screens.
class ShGradientButton extends StatelessWidget {
  const ShGradientButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    super.key,
  });

  final Key buttonKey;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [HomiziColors.logoOrange, HomiziColors.brandRedOrange],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: buttonKey,
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 52,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: HomiziColors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: HomiziColors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              homiziText(context, label),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HomiziColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Green action, for match and move-in steps.
class ShGreenButton extends StatelessWidget {
  const ShGreenButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final Key buttonKey;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton.icon(
        key: buttonKey,
        style: FilledButton.styleFrom(
          backgroundColor: HomiziColors.success,
          foregroundColor: HomiziColors.onSuccess,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.check_circle_outline),
        label: Text(
          homiziText(context, label),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}

/// White rounded section with a small orange heading.
class ShSection extends StatelessWidget {
  const ShSection({
    required this.child,
    this.title,
    this.icon,
    this.color = HomiziColors.white,
    super.key,
  });

  final String? title;
  final IconData? icon;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: HomiziColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: HomiziColors.brandOrange, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      homiziText(context, title!),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: HomiziColors.brandDeepRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Green "96% Match" pill from the shared listing scorer. Tapping opens the
/// same breakdown the listing detail screen shows.
class ShMatchPill extends StatelessWidget {
  const ShMatchPill({required this.match, required this.pillKey, super.key});

  final ListingMatch match;
  final Key pillKey;

  @override
  Widget build(BuildContext context) {
    if (!match.showBadge) {
      return const SizedBox.shrink();
    }
    return Material(
      color: HomiziColors.success,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: pillKey,
        borderRadius: BorderRadius.circular(14),
        onTap: () => showMatchBreakdown(context, match: match),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${match.score}%',
                style: const TextStyle(
                  color: HomiziColors.onSuccess,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  height: 1.1,
                ),
              ),
              Text(
                homiziText(context, 'Match'),
                style: const TextStyle(
                  color: HomiziColors.onSuccess,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark pill naming the home, e.g. "3 BHK – Shared Home".
class ShTag extends StatelessWidget {
  const ShTag({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.brandDeepRed,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          homiziText(context, label),
          style: const TextStyle(
            color: HomiziColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class ShSampleChip extends StatelessWidget {
  const ShSampleChip({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.warningWash,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomiziColors.warning),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          homiziText(context, 'Sample home'),
          style: const TextStyle(
            color: HomiziColors.warning,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Photo with the match pill in the corner.
class ShHomePhoto extends StatelessWidget {
  const ShHomePhoto({
    required this.asset,
    required this.match,
    required this.pillKey,
    this.height = 170,
    this.trailing,
    super.key,
  });

  final String? asset;
  final ListingMatch match;
  final Key pillKey;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ListingPhoto(asset: asset),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: ShMatchPill(match: match, pillKey: pillKey),
          ),
          if (trailing != null)
            Positioned(bottom: 8, right: 8, child: trailing!),
        ],
      ),
    );
  }
}

/// Total rooms / currently living / vacant rooms / total capacity.
class ShOccupancyTable extends StatelessWidget {
  const ShOccupancyTable({
    required this.occupancy,
    this.shareLine,
    this.tableKey,
    super.key,
  });

  final HomeOccupancy occupancy;
  final String? shareLine;
  final Key? tableKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: tableKey,
      children: [
        ShInfoRow(
          icon: Icons.meeting_room_outlined,
          label: 'Total rooms',
          value: '${occupancy.totalRooms}',
        ),
        ShInfoRow(
          icon: Icons.person_outline,
          label: 'Currently living',
          value: occupancy.livingLine,
        ),
        ShInfoRow(
          icon: Icons.bed_outlined,
          label: 'Vacant rooms',
          value: occupancy.vacantLine,
        ),
        ShInfoRow(
          icon: Icons.groups_outlined,
          label: 'Total capacity',
          value: occupancy.capacityLine,
        ),
        if (shareLine != null)
          ShInfoRow(
            icon: Icons.currency_rupee,
            label: 'Your share (per person)',
            value: shareLine!,
          ),
      ],
    );
  }
}

class ShInfoRow extends StatelessWidget {
  const ShInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: HomiziColors.brandOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(homiziText(context, label), style: text.bodyMedium),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              homiziText(context, value),
              textAlign: TextAlign.right,
              style: text.bodyMedium?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShAvatar extends StatelessWidget {
  const ShAvatar({
    required this.initial,
    this.size = 44,
    this.you = false,
    super.key,
  });

  final String initial;
  final double size;
  final bool you;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: you ? HomiziColors.brandOrange : HomiziColors.accentWash,
      child: Text(
        initial,
        style: TextStyle(
          color: you ? HomiziColors.white : HomiziColors.brandDeepRed,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// Green-tinted tag chip, e.g. "Vegetarian".
class ShTraitChip extends StatelessWidget {
  const ShTraitChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.successWash,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 14,
              color: HomiziColors.success,
            ),
            const SizedBox(width: 4),
            Text(
              homiziText(context, label),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four "How it works" steps from the design.
class ShHowItWorks extends StatelessWidget {
  const ShHowItWorks({super.key});

  static const steps = [
    (Icons.tune, 'Set your occupancy need', 'Single, double, or a group.'),
    (
      Icons.home_outlined,
      'See homes with actual room availability',
      'For example 3 BHK: 1 living, 2 vacant rooms.',
    ),
    (Icons.groups_outlined, 'Choose to join as an individual or a group', ''),
    (Icons.task_alt, 'Request, connect and move in', ''),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ShSection(
      key: const Key('occ-how'),
      title: 'How it works',
      icon: Icons.lightbulb_outline,
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: HomiziColors.accentWash,
                    child: Icon(
                      steps[i].$1,
                      size: 18,
                      color: HomiziColors.brandOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          homiziText(context, steps[i].$2),
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: HomiziColors.ink,
                          ),
                        ),
                        if (steps[i].$3.isNotEmpty)
                          Text(
                            homiziText(context, steps[i].$3),
                            style: text.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Plain yes/no check row.
class ShCheckRow extends StatelessWidget {
  const ShCheckRow({required this.check, super.key});

  final JoinCheck check;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            check.ok ? Icons.check_circle : Icons.info_outline,
            color: check.ok ? HomiziColors.success : HomiziColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              homiziText(context, check.label),
              style: TextStyle(
                color: HomiziColors.ink,
                fontWeight: check.ok ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (!check.ok)
            Text(
              homiziText(context, 'Differs'),
              style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// Big green tick used on confirmation screens.
class ShDoneMark extends StatelessWidget {
  const ShDoneMark({super.key, this.icon = Icons.task_alt});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircleAvatar(
        radius: 40,
        backgroundColor: HomiziColors.successWash,
        child: Icon(icon, size: 44, color: HomiziColors.success),
      ),
    );
  }
}
