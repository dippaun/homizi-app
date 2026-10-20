import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';

/// Switches Tenant, Host, Broker, and Flatmate without another sign-in.
class RoleSwitchBar extends ConsumerWidget {
  const RoleSwitchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentRoleProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final role in HomiziRole.values)
            ChoiceChip(
              key: Key('role-switch-${role.name}'),
              label: Text(homiziText(context, _label(role))),
              selected: current == role,
              selectedColor: HomiziColors.accentWash,
              labelStyle: TextStyle(
                color: HomiziColors.ink,
                fontWeight: current == role ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide(
                color: current == role
                    ? HomiziColors.accent
                    : HomiziColors.line,
              ),
              onSelected: (selected) async {
                if (!selected || current == role) {
                  return;
                }
                final error = await ref
                    .read(sessionProvider.notifier)
                    .selectPrimaryRole(homiziRoleWire(role));
                if (!context.mounted) {
                  return;
                }
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(homiziText(context, error))),
                  );
                  return;
                }
                context.go(RoutePaths.home);
              },
            ),
        ],
      ),
    );
  }
}

String _label(HomiziRole role) {
  return switch (role) {
    HomiziRole.tenant => 'Tenant',
    HomiziRole.host => 'Host',
    HomiziRole.broker => 'Broker',
    HomiziRole.roommate => 'Flatmate',
  };
}
