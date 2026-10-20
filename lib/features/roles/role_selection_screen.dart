import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_auth.dart';
import 'package:homizi/features/host/host_intent.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        title: Text(homiziText(context, 'How will you use HOMIZI?')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          const BrandLockup(),
          const SizedBox(height: 20),
          Text(
            homiziText(context, 'Pick one way in. You can change it later.'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'HOMIZI is for tenants, people looking for a flatmate, hosts, and brokers.',
            ),
          ),
          const SizedBox(height: 24),
          for (final option in _options) ...[
            _RoleCard(
              option: option,
              onTap: () => unawaited(_choose(context, ref, option.role)),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _RoleOption {
  const _RoleOption({
    required this.role,
    required this.title,
    required this.benefit,
    required this.icon,
  });

  final HomiziRole role;
  final String title;
  final String benefit;
  final IconData icon;
}

const _options = <_RoleOption>[
  _RoleOption(
    role: HomiziRole.roommate,
    title: 'Roommate',
    benefit: 'Find a flatmate',
    icon: Icons.groups_outlined,
  ),
  _RoleOption(
    role: HomiziRole.tenant,
    title: 'Rental',
    benefit: 'Find a home to rent',
    icon: Icons.apartment_outlined,
  ),
  _RoleOption(
    role: HomiziRole.host,
    title: 'Host',
    benefit: 'Rent out my property',
    icon: Icons.vpn_key_outlined,
  ),
  _RoleOption(
    role: HomiziRole.broker,
    title: 'Broker',
    benefit: "I'm an agent",
    icon: Icons.badge_outlined,
  ),
];

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.option, required this.onTap});

  final _RoleOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('role-card-${option.role.name}'),
      elevation: 0,
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: HomiziColors.accentWash,
                child: Icon(option.icon, color: HomiziColors.accent, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, option.title),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(homiziText(context, option.benefit)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _choose(
  BuildContext context,
  WidgetRef ref,
  HomiziRole role,
) async {
  if (role == HomiziRole.broker &&
      ref.read(sessionProvider).phase == SessionPhase.signedOut) {
    if (GoRouter.maybeOf(context) != null) {
      context.go(brokerProfileSignInLocation());
    }
    return;
  }
  final error = await ref
      .read(sessionProvider.notifier)
      .selectPrimaryRole(homiziRoleWire(role));
  if (!context.mounted) {
    return;
  }
  if (error != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(homiziText(context, error))));
    return;
  }
  if (GoRouter.maybeOf(context) == null) {
    return;
  }
  if (role != HomiziRole.host) {
    ref.read(hostIntentProvider.notifier).consumeAuth();
  }
  final next = switch (role) {
    HomiziRole.roommate => '${RoutePaths.requirement}?kind=roommate',
    HomiziRole.tenant => '${RoutePaths.requirement}?kind=tenant',
    HomiziRole.host => _hostNext(ref),
    HomiziRole.broker => RoutePaths.brokerRegister,
  };
  context.go(next);
}

String _hostNext(WidgetRef ref) {
  final pending = ref.read(hostIntentProvider).afterAuth;
  ref.read(hostIntentProvider.notifier).consumeAuth();
  return pending ?? RoutePaths.home;
}
