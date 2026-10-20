import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/owner/owner_dashboard_screen.dart';

class ForOwnersScreen extends ConsumerWidget {
  const ForOwnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(ownerListingsProvider);
    final hasDraft = listings.maybeWhen(
      data: (rows) => rows.any((row) => row.chip == 'draft'),
      orElse: () => false,
    );
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('for-owners-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'For owners')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(context, 'List your home free'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(
              context,
              'Post a rental on HOMIZI and meet tenants who already verified a phone or an email. There is no brokerage.',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Card(
            color: HomiziColors.accentWash,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, color: HomiziColors.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      homiziText(
                        context,
                        'Zero brokerage. HOMIZI does not charge a fee to list a home or to rent one. Any other monthly charge you type is shown on its own.',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            homiziText(context, 'Three steps'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const _OwnerStep(
            index: '1',
            title: 'List',
            body:
                'Add the home, the rent, house rules, and photos. A draft is saved as you go and you can come back to it.',
          ),
          const _OwnerStep(
            index: '2',
            title: 'Match with verified tenants',
            body:
                'People who fit the home can show interest. You see mock verification badges, not their phone number.',
          ),
          const _OwnerStep(
            index: '3',
            title: 'Meet and finalise',
            body:
                'Agree a visit in the app, then decide together. The street address stays hidden until you accept the visit.',
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('for-owners-start'),
            onPressed: () =>
                context.push('${RoutePaths.listingEditor}?fresh=1'),
            child: Text(homiziText(context, 'Start a listing')),
          ),
          if (hasDraft) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('for-owners-resume'),
              onPressed: () => context.push(RoutePaths.listingEditor),
              child: Text(homiziText(context, 'Continue your draft')),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            key: const Key('for-owners-dashboard'),
            onPressed: () => context.push(RoutePaths.ownerDashboard),
            child: Text(homiziText(context, 'My listings')),
          ),
        ],
      ),
    );
  }
}

class _OwnerStep extends StatelessWidget {
  const _OwnerStep({
    required this.index,
    required this.title,
    required this.body,
  });

  final String index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: HomiziColors.accent,
                foregroundColor: HomiziColors.ink,
                child: Text(index),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(homiziText(context, body)),
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
