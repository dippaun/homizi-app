import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionProvider);
    final role = switch (session.role) {
      AccountRole.tenant => 'Tenant',
      AccountRole.host => 'Host',
      AccountRole.both => 'Tenant and host',
      null => 'Not chosen',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Environment'),
            subtitle: Text(
              '${config.environment.name} · ${config.connectsToSupabase ? 'Supabase configured' : 'demo mode, no project connected'}',
            ),
          ),
          ListTile(
            title: const Text('Signed in as'),
            subtitle: Text(
              session.contact.isEmpty ? 'Unknown' : session.contact,
            ),
          ),
          ListTile(title: const Text('Role'), subtitle: Text(role)),
          ListTile(
            title: const Text('Policy version'),
            subtitle: Text(session.policyVersion ?? 'Not accepted'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Tenant profile'),
            onTap: () => context.push(RoutePaths.tenantProfile),
          ),
          ListTile(
            title: const Text('Host profile'),
            onTap: () => context.push(RoutePaths.hostProfile),
          ),
          ListTile(
            title: const Text('Your requirement'),
            onTap: () => context.push(RoutePaths.requirement),
          ),
          ListTile(
            title: const Text('Create a listing'),
            onTap: () => context.push(RoutePaths.listingEditor),
          ),
          ListTile(
            title: const Text('Help and safety'),
            onTap: () => context.push(RoutePaths.help),
          ),
          const Divider(),
          const ListTile(
            title: Text('Account deletion'),
            subtitle: Text(
              'Deletion across auth, storage, and listings is a required later workflow. This button does not delete anything and will not pretend that it did.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Placeholder brand colors are still in use.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: HomiziColors.warning),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Log out'),
            onTap: () =>
                unawaited(ref.read(sessionProvider.notifier).signOut()),
          ),
        ],
      ),
    );
  }
}
