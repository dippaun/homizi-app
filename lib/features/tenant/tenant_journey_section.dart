import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/tenant/tenant_entries.dart';

/// Tenant home controls. Hidden for every other role.
class TenantJourneySection extends ConsumerWidget {
  const TenantJourneySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentRoleProvider) != HomiziRole.tenant) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Column(
      key: const Key('tenant-journey'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          homiziText(context, 'Your tenant home'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(context, 'Search, shortlist, and visit homes in India.'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: HomiziColors.inkSoft,
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in tenantEntries) ...[
          _EntryCard(entry: entry),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final TenantEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: HomiziColors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: InkWell(
        key: Key('tenant-entry-${entry.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => openTenantEntry(context, entry),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: HomiziColors.accentWash,
                child: Icon(entry.icon, color: HomiziColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, entry.label),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      homiziText(context, entry.detail),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: HomiziColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: HomiziColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
