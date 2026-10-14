import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/contact_gate_panel.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/compatibility.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/own_contact_share.dart';

/// Sample preference used only to explain a score. Not a saved requirement.
const _demoPreference = CompatibilityPreference(
  budgetMinInr: 15000,
  budgetMaxInr: 25000,
  city: 'Bengaluru',
  locality: 'Koramangala',
  furnishing: 'furnished',
  propertyType: 'apartment',
);

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({required this.listingId, super.key});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  String? _note;

  Future<void> _like(Listing listing) async {
    final notice = await ref.read(discoveryProvider.notifier).like(listing.id);
    if (!mounted) {
      return;
    }
    setState(() => _note = notice.message);
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryProvider);
    if (discovery.loading && discovery.byId(widget.listingId) == null) {
      return const Scaffold(
        body: LoadingState(message: 'Opening the listing…'),
      );
    }
    final listing = discovery.byId(widget.listingId);
    if (listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: const EmptyMessage(
          text: 'That listing is not in the published feed.',
        ),
      );
    }
    final match = discovery.matchForHost(listing.hostUserId);
    final gate = match?.contact ?? const ContactGate.hidden('no_match');
    final fit = scoreCompatibility(
      preference: _demoPreference,
      listing: listing,
    );
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        title: const Text('Listing'),
        actions: [
          IconButton(
            tooltip: 'Report',
            onPressed: () => context.push(
              RoutePaths.reportLocation(
                targetType: 'property',
                targetId: listing.id,
                blockedUserId: listing.hostUserId,
              ),
            ),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_note != null) ...[
                Text(_note!, key: const Key('interest-note')),
                const SizedBox(height: 8),
              ],
              FilledButton(
                key: const Key('interested-button'),
                onPressed: discovery.busy
                    ? null
                    : () => unawaited(_like(listing)),
                child: Text(discovery.busy ? 'Saving…' : 'Interested'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 320,
            child: ListingGallery(
              assets: listing.photoAssets,
              heroTag: listing.heroTag,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text('${listing.locality}, ${listing.city}'),
                const SizedBox(height: 14),
                RentBlock(listing: listing, large: true),
                const SizedBox(height: 14),
                MetaChips(listing: listing),
                const SizedBox(height: 20),
                Row(
                  children: [
                    HostAvatar(name: listing.hostDisplayName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.hostDisplayName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (listing.hostOccupation.isNotEmpty)
                            Text(
                              listing.hostOccupation,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (listing.hostVerified)
                      const VerifiedBadge(label: 'Verified', showCheck: true),
                    VerifiedBadge(label: listing.hostKind),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Identity check in this build is a mock. No Aadhaar number or face scan is collected.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                Text(listing.summary),
                const SizedBox(height: 20),
                const SectionLabel('Amenities'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final amenity in listing.amenities)
                      ActionChip(label: Text(amenity), onPressed: () {}),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionLabel('Location'),
                const SizedBox(height: 10),
                LocationBlock(locality: listing.locality, city: listing.city),
                const SizedBox(height: 20),
                Text(
                  'Fit with a sample Bengaluru budget: ${fit.score}/100',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final reason in fit.reasons) Text('• $reason'),
                const SizedBox(height: 16),
                ContactGatePanel(gate: gate),
                if (match != null) ...[
                  const SizedBox(height: 12),
                  OwnContactShare(
                    match: match,
                    onDeviceOnly: !ref
                        .watch(appConfigProvider)
                        .connectsToSupabase,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: Key('open-chat-${match.matchId}'),
                    onPressed: () => context.push(
                      RoutePaths.chat(
                        match.matchId,
                        name: match.otherDisplayName,
                        title: listing.title,
                        otherUserId: listing.hostUserId,
                      ),
                    ),
                    child: const Text('Chat'),
                  ),
                ],
              ],
            ),
          ),
        ],
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
