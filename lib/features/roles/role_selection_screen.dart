import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
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
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const BrandLockup(),
          const SizedBox(height: 20),
          Text(
            homiziText(context, 'One account, two ways in.'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'One account can be a tenant, a host, or both. This is a product decision for the owner to confirm. When Supabase is configured, the choice is saved on your account.',
            ),
          ),
          const SizedBox(height: 20),
          RadioGroup<AccountRole>(
            onChanged: (role) {
              if (role != null) {
                unawaited(_choose(context, ref, role));
              }
            },
            child: Column(
              children: [
                Card.outlined(
                  child: RadioListTile<AccountRole>(
                    value: AccountRole.tenant,
                    secondary: const Icon(Icons.search),
                    title: Text(homiziText(context, 'Tenant')),
                    subtitle: Text(
                      homiziText(
                        context,
                        'Post what you need and discover homes or flatmates.',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card.outlined(
                  child: RadioListTile<AccountRole>(
                    value: AccountRole.host,
                    secondary: const Icon(Icons.home_outlined),
                    title: Text(homiziText(context, 'Host')),
                    subtitle: Text(
                      homiziText(
                        context,
                        'List a home you have available. Broker, owner, or flatmate.',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card.outlined(
                  child: RadioListTile<AccountRole>(
                    value: AccountRole.both,
                    secondary: const Icon(Icons.swap_horiz),
                    title: Text(homiziText(context, 'Both')),
                    subtitle: Text(
                      homiziText(
                        context,
                        'Look for a place and also list a room or a flat.',
                      ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(homiziText(context, error))));
  }
}
