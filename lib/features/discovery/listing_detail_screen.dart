import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/compatibility.dart';
import 'package:homizi/features/interest/interest_log.dart';
import 'package:homizi/features/safety/domain/contact_visibility_policy.dart';
import 'package:homizi/features/session/session_controller.dart';

/// Sample preference used only to explain a score. Not a saved requirement.
const _demoPreference = CompatibilityPreference(
  budgetMinInr: 15000,
  budgetMaxInr: 25000,
  city: 'Bengaluru',
  locality: 'Koramangala',
  furnishing: 'furnished',
  propertyType: 'apartment',
);

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({required this.listingId, super.key});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = DemoCatalog.byId(listingId);
    if (listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: const EmptyMessage(
          text: 'That listing is not in the demo catalog.',
        ),
      );
    }
    final session = ref.watch(sessionProvider);
    final decision = evaluateContactVisibility(
      callerId: session.contact.isEmpty ? null : session.contact,
      participantA: 'self',
      participantB: 'host',
      matchActive: false,
      blocked: false,
      otherConsented: false,
      consentScope: null,
      otherPhone: null,
      otherEmail: null,
    );
    final fit = scoreCompatibility(
      preference: _demoPreference,
      listing: listing,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing'),
        actions: [
          IconButton(
            tooltip: 'Report',
            onPressed: () => context.push(
              '${RoutePaths.report}?targetType=listing&targetId=${listing.id}',
            ),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(listing.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${listing.locality}, ${listing.city}'),
          const SizedBox(height: 8),
          Text('${formatInr(listing.rentInr)} / month'),
          Text('Deposit ${formatInr(listing.depositInr)}'),
          const SizedBox(height: 12),
          Text(listing.summary),
          const SizedBox(height: 12),
          Text('Host: ${listing.hostDisplayName}'),
          const Text('Verification: not verified (mock status only)'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final amenity in listing.amenities)
                Chip(label: Text(amenity)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Fit with a sample Bengaluru budget: ${fit.score}/100'),
          for (final reason in fit.reasons) Text('• $reason'),
          const SizedBox(height: 16),
          const _ContactGate(visible: false),
          if (decision.phone != null || decision.email != null)
            const Text('Contact leaked into the detail view.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ref
                  .read(interestLogProvider.notifier)
                  .record(listing.id, InterestAction.like);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Like saved in this session. The server create_interest function is authoritative once connected.',
                  ),
                ),
              );
            },
            child: const Text('Interested'),
          ),
        ],
      ),
    );
  }
}

class _ContactGate extends StatelessWidget {
  const _ContactGate({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('contact-gate'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomiziColors.card,
        border: Border.all(color: HomiziColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        visible ? 'Contact is visible for this match.' : 'Contact stays hidden until you both match and they consent. This screen does not hold a phone number or an email address.',
      ),
    );
  }
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Text(text)),
    );
  }
}
