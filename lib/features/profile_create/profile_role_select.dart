import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Shared "Step 2: Create Your Profile & Verification — Select Your Role" page.
///
/// Final registration opens on this picker. Profile edit uses the same cards.
class ProfileRoleSelect extends StatelessWidget {
  const ProfileRoleSelect({
    required this.selected,
    required this.onToggle,
    this.goals = profileWizardRoles,
    this.heading = 'Select Your Role',
    this.error,
    this.errorKey,
    this.progressStep,
    super.key,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final List<(String, String, String)> goals;
  final String heading;
  final String? error;
  final Key? errorKey;

  /// When set, the nine-step wizard bar is shown. Registration leaves this null.
  final int? progressStep;

  @override
  Widget build(BuildContext context) {
    final step = progressStep;
    return Column(
      key: const Key('profile-role-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          homiziText(context, 'Step 2: Create Your Profile & Verification'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: HomiziColors.logoOrange,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          homiziText(context, heading),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 28,
            height: 1.12,
            fontWeight: FontWeight.w800,
            color: HomiziColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'I am a... (Select one or more)'),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: HomiziColors.inkSoft,
          ),
        ),
        if (step != null) ...[
          const SizedBox(height: 16),
          ProfileCreateProgress(step: step),
        ],
        const SizedBox(height: 18),
        OptionGrid(
          minTileWidth: 148,
          maxColumns: 2,
          children: [
            for (final role in goals)
              OptionTile(
                key: Key('profile-role-${role.$1}'),
                label: homiziText(context, role.$2),
                subtitle: homiziText(context, role.$3),
                subtitleMaxLines: 4,
                minHeight: 196,
                illustration: _RoleArt(
                  roleId: role.$1,
                  selected: selected.contains(role.$1),
                ),
                selected: selected.contains(role.$1),
                onTap: () => onToggle(role.$1),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            homiziText(context, error!),
            key: errorKey,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.35,
              color: HomiziColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _RoleArt extends StatelessWidget {
  const _RoleArt({required this.roleId, required this.selected});

  final String roleId;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (icon, badge) = switch (roleId) {
      'host' => (Icons.home_outlined, Icons.vpn_key_outlined),
      'partner' => (Icons.handshake_outlined, Icons.business_center_outlined),
      'sharer' => (Icons.groups_outlined, Icons.home_outlined),
      'finder' => (Icons.person_search_outlined, Icons.favorite_border),
      _ => (Icons.vpn_key_outlined, Icons.luggage_outlined),
    };
    final ink = selected ? HomiziColors.logoOrange : HomiziColors.inkSoft;
    return SizedBox(
      width: 72,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: selected
                  ? HomiziColors.white
                  : HomiziColors.logoOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: ink),
          ),
          Positioned(
            right: 2,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HomiziColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: HomiziColors.logoOrange.withValues(alpha: 0.45),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: HomiziColors.shadowSoft,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: SizedBox(
                width: 22,
                height: 22,
                child: Icon(badge, size: 13, color: HomiziColors.logoOrange),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
