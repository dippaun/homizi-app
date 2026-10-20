import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/discovery/contact_gate_panel.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/discovery/own_contact_share.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/explore_providers.dart';
import 'package:homizi/features/listings/domain/photo_caption.dart';
import 'package:homizi/features/maps/approximate_area_map.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/owner/owner_rules.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({required this.listingId, super.key});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  String? _note;
  PreciseAddress _address = const PreciseAddress.hidden();
  int? _replyHours;
  List<String>? _galleryLabels;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAddress());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(analyticsGatewayProvider)
            .log('listing_view', properties: {'listing_id': widget.listingId}),
      );
      unawaited(_recordView());
      unawaited(_loadReply());
      unawaited(_loadGalleryLabels());
    });
  }

  Future<void> _loadGalleryLabels() async {
    if (!ref.read(appConfigProvider).connectsToSupabase) {
      return;
    }
    try {
      final rawRows = await Supabase.instance.client
          .from('property_photos')
          .select('sort_order, photo_type, caption, moderation_status')
          .eq('property_id', widget.listingId)
          .order('sort_order');
      if (!mounted) {
        return;
      }
      final rows = <Map<String, dynamic>>[
        for (final raw in rawRows) raw,
      ];
      final listing = ref.read(discoveryProvider).byId(widget.listingId);
      final assets = listing?.photoAssets ?? const <String>[];
      setState(() {
        _galleryLabels = alignGalleryLabels(
          assets: assets,
          fromServer: galleryLabelsFromPhotoRows(rows),
        );
      });
    } catch (_) {
      // Demo mode, or a project that has not applied the caption column yet.
    }
  }

  Future<void> _loadReply() async {
    final listing = ref.read(discoveryProvider).byId(widget.listingId);
    final gateway = ref.read(ownerGatewayProvider);
    await gateway.recordView(widget.listingId);
    if (listing == null) {
      return;
    }
    final hours = await gateway.replyHours(listing.hostUserId);
    if (!mounted) {
      return;
    }
    setState(() => _replyHours = hours ?? listing.replyWithinHours);
  }

  Future<void> _recordView() async {
    try {
      await ref
          .read(exploreGatewayProvider)
          .recordListingView(widget.listingId);
      ref.invalidate(listingViewCountsProvider);
      ref.invalidate(recentlyViewedProvider);
    } on ExploreFailure {
      // A failed view write must not block the listing.
    }
  }

  Future<void> _requestPhotos() async {
    try {
      final result = await ref
          .read(exploreGatewayProvider)
          .requestPhotos(widget.listingId);
      if (!mounted) {
        return;
      }
      setState(() => _note = result.message);
    } on ExploreFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _note = error.message);
    }
  }

  Future<void> _loadAddress() async {
    final address = await ref
        .read(discoveryGatewayProvider)
        .preciseAddress(widget.listingId);
    if (!mounted) {
      return;
    }
    setState(() => _address = address);
  }

  Future<void> _toggleSave(String listingId) async {
    final notice = await ref
        .read(discoveryProvider.notifier)
        .toggleSave(listingId);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(homiziText(context, notice.message))),
    );
  }

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
        appBar: AppBar(title: Text(homiziText(context, 'Listing'))),
        body: EmptyMessage(
          text: homiziText(
            context,
            'That listing is not in the published feed.',
          ),
        ),
      );
    }
    final match = discovery.matchForHost(listing.hostUserId);
    final gate = match?.contact ?? const ContactGate.hidden('no_match');
    final matchScore = ref.watch(listingMatchesProvider)[listing.id];
    final saved = discovery.savedIds.contains(listing.id);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(homiziText(context, 'Listing')),
        actions: [
          IconButton(
            tooltip: homiziText(context, saved ? 'Remove save' : 'Save'),
            isSelected: saved,
            onPressed: discovery.busy
                ? null
                : () => unawaited(_toggleSave(listing.id)),
            icon: const Icon(Icons.favorite_border, color: HomiziColors.accent),
            selectedIcon: const Icon(
              Icons.favorite,
              color: HomiziColors.accent,
            ),
          ),
          IconButton(
            tooltip: homiziText(context, 'Report'),
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
                Text(
                  homiziText(context, _note!),
                  key: const Key('interest-note'),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                key: const Key('interested-button'),
                onPressed: discovery.busy
                    ? null
                    : () => unawaited(_like(listing)),
                child: Text(
                  homiziText(
                    context,
                    discovery.busy ? 'Saving…' : 'Interested',
                  ),
                ),
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
              labels:
                  _galleryLabels ?? galleryLabelsForAssets(listing.photoAssets),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, '${listing.photoCount} photos'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (listing.photoCount < 3) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('request-photos'),
                    onPressed: () => unawaited(_requestPhotos()),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(homiziText(context, 'Request photos')),
                  ),
                ],
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.98, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: child,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, listing.title),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    homiziText(context, '${listing.locality}, ${listing.city}'),
                  ),
                  const SizedBox(height: 14),
                  RentBlock(listing: listing, large: true),
                  const SizedBox(height: 14),
                  MetaChips(listing: listing),
                  if (listing.areaSqft != null) ...[
                    const SizedBox(height: 8),
                    Text(homiziText(context, '${listing.areaSqft} sq ft')),
                  ],
                  if (listing.preferredTenantsLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(homiziText(context, listing.preferredTenantsLabel)),
                  ],
                  if (listing.floorNo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      homiziText(
                        context,
                        listing.totalFloors == null
                            ? 'Floor ${listing.floorNo}'
                            : 'Floor ${listing.floorNo} of ${listing.totalFloors}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      HostAvatar(
                        name: listing.hostDisplayName,
                        photoRef: listing.hostAvatarUrl,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              homiziText(context, listing.hostDisplayName),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (listing.hostOccupation.isNotEmpty)
                              Text(
                                homiziText(context, listing.hostOccupation),
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
                        VerifiedBadge(
                          label: homiziText(context, 'Verified'),
                          showCheck: true,
                        ),
                      VerifiedBadge(label: listing.hostKind),
                    ],
                  ),
                  if (listing.trust.any) ...[
                    const SizedBox(height: 8),
                    TrustBadgeRow(badges: listing.trust),
                  ],
                  if ((_replyHours ?? listing.replyWithinHours) != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      key: const Key('owner-reply-badge'),
                      homiziText(
                        context,
                        replyWithinLabel(
                          _replyHours ?? listing.replyWithinHours ?? 1,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    homiziText(
                      context,
                      'Identity check in this build is a mock. No Aadhaar number or face scan is collected.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Text(homiziText(context, listing.summary)),
                  const SizedBox(height: 20),
                  const SectionLabel('Amenities'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final amenity in listing.amenities)
                        Chip(
                          label: Text(homiziText(context, amenity)),
                          labelStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (listing.restrictions.isNotEmpty) ...[
                    const SectionLabel('Restrictions'),
                    const SizedBox(height: 8),
                    Text(homiziText(context, listing.restrictions.join(', '))),
                    const SizedBox(height: 16),
                  ],
                  if (listing.suitability.isNotEmpty) ...[
                    const SectionLabel('Suitability'),
                    const SizedBox(height: 8),
                    Text(homiziText(context, listing.suitability.join(', '))),
                    const SizedBox(height: 16),
                  ],
                  const SectionLabel('Location'),
                  const SizedBox(height: 10),
                  LocationBlock(locality: listing.locality, city: listing.city),
                  const SizedBox(height: 12),
                  ApproximateAreaMap(
                    listing: listing,
                    address: _address,
                    tileUrl: ref.watch(appConfigProvider).osmTileUrl,
                    userAgent: ref.watch(appConfigProvider).osmUserAgent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    key: const Key('listing-address-gate'),
                    homiziText(
                      context,
                      _address.showsLine
                          ? _address.line!
                          : 'The exact address stays hidden until a visit is agreed.',
                    ),
                  ),
                  if (_address.showsLine && _address.landmark != null)
                    Text(homiziText(context, _address.landmark!)),
                  const SizedBox(height: 20),
                  if (matchScore != null && matchScore.showBadge) ...[
                    MatchBadge(
                      key: Key('match-badge-${listing.id}'),
                      match: matchScore,
                      onTap: () =>
                          showMatchBreakdown(context, match: matchScore),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: matchScore.score / 100),
                    const SizedBox(height: 16),
                  ],
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
                      child: Text(homiziText(context, 'Chat')),
                    ),
                  ],
                ],
              ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(homiziText(context, text)),
      ),
    );
  }
}
