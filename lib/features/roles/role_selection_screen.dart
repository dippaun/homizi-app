import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: const Text('How will you use HOMIZI?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const BrandLockup(),
          const SizedBox(height: 20),
          Text(
            'One account, two ways in.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'One account can be a tenant, a host, or both. This is a product decision for the owner to confirm. When Supabase is configured, the choice is saved on your account.',
          ),
          const SizedBox(height: 20),
          _RoleCard(
            icon: Icons.search,
            title: 'Tenant',
            body: 'Post what you need and discover homes or flatmates.',
            onTap: () => unawaited(_choose(context, ref, AccountRole.tenant)),
          ),
          _RoleCard(
            icon: Icons.home_outlined,
            title: 'Host',
            body: 'List a home you have available. Broker, owner, or flatmate.',
            onTap: () => unawaited(_choose(context, ref, AccountRole.host)),
          ),
          _RoleCard(
            icon: Icons.swap_horiz,
            title: 'Both',
            body: 'Look for a place and also list a room or a flat.',
            onTap: () => unawaited(_choose(context, ref, AccountRole.both)),
          ),
        ],
      ),
    );
  }
}

Future<void> _choose(
  BuildContext context,
  WidgetRef ref,
  AccountRole role,
) async {
  final error = await ref.read(sessionProvider.notifier).selectRole(role);
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: HomiziColors.accentWash,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(icon, color: HomiziColors.accent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(body),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
