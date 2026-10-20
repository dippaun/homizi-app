import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_page.dart';
import 'package:homizi/features/owner/owner_dashboard_screen.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_rules.dart';

class BrokerListingsScreen extends ConsumerWidget {
  const BrokerListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(ownerListingsProvider);
    return Scaffold(
      key: const Key('broker-listings-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Listings'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('broker-new-listing'),
        onPressed: () => context.push('${RoutePaths.listingEditor}?fresh=1'),
        icon: const Icon(Icons.add_home_outlined),
        label: Text(homiziText(context, 'New listing')),
      ),
      body: listings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _Message(
          text: error is OwnerFailure
              ? error.message
              : 'Listings did not load.',
          action: 'Try again',
          onAction: () => ref.invalidate(ownerListingsProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return _Message(
              text: 'No listings yet. A draft stays private until you publish.',
              action: 'New listing',
              onAction: () =>
                  context.push('${RoutePaths.listingEditor}?fresh=1'),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              Text(
                homiziText(
                  context,
                  'Homes you manage. Open one to edit, see leads, or plan a visit.',
                ),
              ),
              const SizedBox(height: 12),
              for (final listing in rows)
                BrokerTapCard(
                  cardKey: Key('broker-listing-card-${listing.id}'),
                  onTap: () =>
                      context.push(RoutePaths.brokerListing(listing.id)),
                  child: _ListingSummary(listing: listing),
                ),
            ],
          );
        },
      ),
    );
  }
}

class BrokerListingScreen extends ConsumerWidget {
  const BrokerListingScreen({required this.listingId, super.key});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(ownerListingsProvider);
    return listings.when(
      loading: () => const Scaffold(
        key: Key('broker-listing-screen'),
        backgroundColor: HomiziColors.white,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => BrokerPage(
        screenKey: const Key('broker-listing-screen'),
        title: 'Listing',
        children: [
          Text(
            homiziText(
              context,
              error is OwnerFailure ? error.message : 'Listings did not load.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(ownerListingsProvider),
            child: Text(homiziText(context, 'Try again')),
          ),
        ],
      ),
      data: (rows) {
        OwnerListing? listing;
        for (final row in rows) {
          if (row.id == listingId) {
            listing = row;
            break;
          }
        }
        if (listing == null) {
          return BrokerPage(
            screenKey: const Key('broker-listing-screen'),
            title: 'Listing',
            children: [
              Text(homiziText(context, 'This listing is not on your account.')),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('broker-listing-home'),
                onPressed: () => context.go(RoutePaths.listings),
                child: Text(homiziText(context, 'Back to listings')),
              ),
            ],
          );
        }
        final current = listing;
        return BrokerPage(
          screenKey: const Key('broker-listing-screen'),
          title: 'Listing',
          children: [
            _ListingSummary(listing: current),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('broker-listing-edit'),
              onPressed: () =>
                  context.push('${RoutePaths.listingEditor}?id=${current.id}'),
              child: Text(homiziText(context, 'Edit listing')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('broker-listing-leads'),
              onPressed: () => context.push(RoutePaths.brokerLeads),
              child: Text(homiziText(context, 'Leads')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('broker-listing-visits'),
              onPressed: () => context.push(RoutePaths.brokerVisits),
              child: Text(homiziText(context, 'Visits')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('broker-listing-stats'),
              onPressed: () =>
                  context.push(RoutePaths.listingStats(current.id)),
              child: Text(homiziText(context, 'Listing performance')),
            ),
          ],
        );
      },
    );
  }
}

class _ListingSummary extends StatelessWidget {
  const _ListingSummary({required this.listing});

  final OwnerListing listing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, listing.title),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          homiziText(
            context,
            '${listing.place} · ${formatInr(listing.rentInr)}',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            '${ownerChipLabel(listing.chip)} · ${listing.interests} interests · ${listing.visitRequests} visit requests',
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.action,
    required this.onAction,
  });

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(homiziText(context, text), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(homiziText(context, action)),
            ),
          ],
        ),
      ),
    );
  }
}
