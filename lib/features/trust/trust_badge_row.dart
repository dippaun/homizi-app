import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// Verification chips. Hidden when every flag is false.
class TrustBadgeRow extends StatelessWidget {
  const TrustBadgeRow({required this.badges, super.key});

  final UserBadges badges;

  @override
  Widget build(BuildContext context) {
    final chips = _trustChips(badges);
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

/// Aadhaar and face chips only. Shown on swipe cards and chat headers.
class IdentityBadgeRow extends StatelessWidget {
  const IdentityBadgeRow({required this.badges, super.key});

  final UserBadges badges;

  @override
  Widget build(BuildContext context) {
    if (!badges.anyIdentity) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (badges.aadhaarVerified)
          const _TrustChip(label: 'Aadhaar verified', emphasize: true),
        if (badges.faceVerified)
          const _TrustChip(label: 'Face verified', emphasize: true),
      ],
    );
  }
}

List<Widget> _trustChips(UserBadges badges) {
  return [
    if (badges.phoneVerified) const _TrustChip(label: 'Phone verified'),
    if (badges.emailVerified) const _TrustChip(label: 'Email verified'),
    if (badges.profileComplete) const _TrustChip(label: 'Profile complete'),
    if (badges.aadhaarVerified)
      const _TrustChip(label: 'Aadhaar verified', emphasize: true),
    if (badges.faceVerified)
      const _TrustChip(label: 'Face verified', emphasize: true),
  ];
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.label, this.emphasize = false});

  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        emphasize ? Icons.badge_outlined : Icons.verified_outlined,
        size: 16,
        color: HomiziColors.accent,
      ),
      label: Text(homiziText(context, label)),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: scheme.onSurface),
      side: BorderSide(
        color: emphasize ? HomiziColors.accent : scheme.outlineVariant,
      ),
      backgroundColor: emphasize ? HomiziColors.accentWash : scheme.surface,
    );
  }
}
