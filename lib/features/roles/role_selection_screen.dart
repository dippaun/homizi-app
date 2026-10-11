import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('How will you use HOMIZI?')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'One account can be a tenant, a host, or both. This is a product decision for the owner to confirm. Your primary role only changes what this demo shell highlights.',
          ),
          const SizedBox(height: 16),
          _RoleCard(
            title: 'Tenant',
            body: 'Post what you need and discover homes or flatmates.',
            onTap: () => ref
                .read(sessionProvider.notifier)
                .selectRole(AccountRole.tenant),
          ),
          _RoleCard(
            title: 'Host',
            body: 'List a home you have available. Broker, owner, or flatmate.',
            onTap: () =>
                ref.read(sessionProvider.notifier).selectRole(AccountRole.host),
          ),
          _RoleCard(
            title: 'Both',
            body: 'Look for a place and also list a room or a flat.',
            onTap: () =>
                ref.read(sessionProvider.notifier).selectRole(AccountRole.both),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Text(body),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
