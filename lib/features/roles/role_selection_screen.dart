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
          RadioGroup<AccountRole>(
            onChanged: (role) {
              if (role != null) {
                unawaited(_choose(context, ref, role));
              }
            },
            child: const Column(
              children: [
                Card.outlined(
                  child: RadioListTile<AccountRole>(
                    value: AccountRole.tenant,
                    secondary: Icon(Icons.search),
                    title: Text('Tenant'),
                    subtitle: Text(
                      'Post what you need and discover homes or flatmates.',
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Card.outlined(
                  child: RadioListTile<AccountRole>(
                    value: AccountRole.host,
                    secondary: Icon(Icons.home_outlined),
                    title: Text('Host'),
                    subtitle: Text(
                      'List a home you have available. Broker, owner, or flatmate.',
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Card.outlined(
                  child: RadioListTile<AccountRole>(
                    value: AccountRole.both,
                    secondary: Icon(Icons.swap_horiz),
                    title: Text('Both'),
                    subtitle: Text(
                      'Look for a place and also list a room or a flat.',
                    ),
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
