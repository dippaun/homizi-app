import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/place_label.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/discovery/contact_gate_panel.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/listing_badges.dart';
import 'package:homizi/features/discovery/listing_detail_gallery.dart';
import 'package:homizi/features/discovery/listing_detail_sections.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/discovery/own_contact_share.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/explore_providers.dart';
import 'package:homizi/features/listings/domain/photo_caption.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/listings/rent_cost_breakdown.dart';
import 'package:homizi/features/maps/domain/geo.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/owner/owner_rules.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
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
  int? _commuteMinutes;
  int? _maxCommute;

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
    final config = ref.read(appConfigProvider);
    if (!config.connectsToSupabase || ref.read(forceDemoModeProvider)) {
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
      final rows = <Map<String, dynamic>>[for (final raw in rawRows) raw];
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
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Request sent',
        detail: 'The host can see this photo request in the demo.',
      );
      return;
    }
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
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Request sent',
        detail: 'This home is saved for the demo.',
      );
      return;
    }
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
    if (!ref.read(ownVerificationProvider).isVerified) {
      await guardVerifiedAction(context, ref, action: () => _like(listing));
      return;
    }
    final notice = await ref.read(discoveryProvider.notifier).like(listing.id);
    if (!mounted) {
      return;
    }
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Interest sent',
        detail: 'The host can see this interest in the demo.',
      );
      return;
    }
    setState(() => _note = notice.message);
  }

  Future<void> _skip(Listing listing) async {
    final notice = await ref.read(discoveryProvider.notifier).pass(listing.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(homiziText(context, notice.message))),
    );
  }

  void _share(Listing listing) {
    final place = listingPlaceLine(listing.locality, listing.city);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('listing-share-dialog'),
          backgroundColor: HomiziColors.white,
          title: Text(
            homiziText(context, 'Share this home'),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          content: Text(
            homiziText(
              context,
              '${listing.title}\n$place\n\nThis stays inside Homizi. Phone and email are not included.',
            ),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                homiziText(context, 'Close'),
                style: const TextStyle(color: HomiziColors.ink),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onCommute(int? minutes, int? maxMinutes) {
    if (!mounted || (_commuteMinutes == minutes && _maxCommute == maxMinutes)) {
      return;
    }
    setState(() {
      _commuteMinutes = minutes;
      _maxCommute = maxMinutes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(discoveryProvider);
    final published = ref.watch(publishedSearchProvider);
    if (discovery.loading && discovery.byId(widget.listingId) == null) {
      return const Scaffold(
        body: LoadingState(message: 'Opening the listing…'),
      );
    }
    final listing = discovery.byId(widget.listingId);
    PublishedHome? publishedHome;
    for (final home in published) {
      if (home.listing.id == widget.listingId) {
        publishedHome = home;
      }
    }
    if (listing == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, 'Listing')),
        ),
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
    final matchScore = ref.watch(listingScorerProvider)(listing);
    final areaPoint = publicPin(
      storedLatitude: listing.approxLatitude,
      storedLongitude: listing.approxLongitude,
      city: listing.city,
      locality: listing.locality,
      salt: listing.id,
    );
    final badges = listingBadges(listing, published: publishedHome);
    final saved = discovery.savedIds.contains(listing.id);
    final hours = _replyHours ?? listing.replyWithinHours;
    final labels =
        _galleryLabels ?? galleryLabelsForAssets(listing.photoAssets);
    final cost = publishedHome?.cost ?? rentingCostForListing(listing);
    return Scaffold(
      backgroundColor: HomiziColors.white,
      bottomNavigationBar: ListingActionBar(
        saved: saved,
        busy: discovery.busy,
        note: _note,
        onSkip: () => unawaited(_skip(listing)),
        onSave: () => unawaited(_toggleSave(listing.id)),
        onInterested: () => unawaited(_like(listing)),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ListingDetailGallery(
            assets: listing.photoAssets,
            labels: labels,
            heroTag: listing.heroTag,
            verified: badges.verifiedListing,
            saved: saved,
            onSave: discovery.busy
                ? null
                : () => unawaited(_toggleSave(listing.id)),
            onShare: () => _share(listing),
            onReport: () => context.push(
              RoutePaths.reportLocation(
                targetType: 'property',
                targetId: listing.id,
                blockedUserId: listing.hostUserId,
              ),
            ),
          ),
          if (listing.photoCount < 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('request-photos'),
                  onPressed: () => unawaited(_requestPhotos()),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(homiziText(context, 'Request photos')),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListingTitleBlock(listing: listing, match: matchScore),
                const SizedBox(height: 8),
                ListingPlaceRow(listing: listing),
                const SizedBox(height: 12),
                ListingPriceBlock(listing: listing),
                const SizedBox(height: 16),
                ListingSpecRow(listing: listing),
                const SizedBox(height: 20),
                ListingAmenityGrid(listing: listing),
                const SizedBox(height: 16),
                ListingPlaceCards(
                  listing: listing,
                  point: areaPoint,
                  onCommute: _onCommute,
                ),
                const SizedBox(height: 8),
                Text(
                  homiziText(
                    context,
                    'The circle is the locality, not the building. The exact point stays hidden until a visit is agreed.',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: HomiziColors.muted),
                ),
                const SizedBox(height: 20),
                ListingHostRow(
                  listing: listing,
                  verifiedHost: badges.hostVerified || badges.verified,
                  replyLabel: hours == null ? null : replyWithinLabel(hours),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (badges.verified)
                      VerifiedBadge(
                        label: homiziText(context, 'Verified'),
                        showCheck: true,
                      ),
                    if (badges.verifiedListing)
                      const VerifiedBadge(
                        label: 'Verified listing',
                        showCheck: true,
                      ),
                    VerifiedBadge(
                      label: badges.photosVerified
                          ? 'Photos verified'
                          : 'Photos declared',
                      showCheck: badges.photosVerified,
                    ),
                    VerifiedBadge(label: listing.hostKind),
                  ],
                ),
                if (listing.trust.any) ...[
                  const SizedBox(height: 8),
                  TrustBadgeRow(badges: listing.trust),
                ],
                if (!listing.trust.anyIdentity) ...[
                  const SizedBox(height: 8),
                  Text(
                    homiziText(
                      context,
                      'Aadhaar and face badges appear only after Digio confirms them.',
                    ),
                    key: const Key('listing-identity-note'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                ListingWhyMatch(
                  listing: listing,
                  match: matchScore,
                  commuteMinutes: _commuteMinutes,
                  maxCommuteMinutes: _maxCommute,
                ),
                const SizedBox(height: 8),
                ListingCostSection(cost: cost, detailed: publishedHome != null),
                const SizedBox(height: 16),
                Text(homiziText(context, listing.summary)),
                if (listing.preferredTenantsLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
                if (listing.restrictions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionLabel('Restrictions'),
                  const SizedBox(height: 8),
                  Text(homiziText(context, listing.restrictions.join(', '))),
                ],
                if (listing.suitability.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionLabel('Suitability'),
                  const SizedBox(height: 8),
                  Text(homiziText(context, listing.suitability.join(', '))),
                ],
                if (listing.friendlyTags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionLabel('Friendly tags'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in listing.friendlyTags)
                        Chip(
                          key: Key('detail-tag-$tag'),
                          label: Text(
                            homiziText(context, listingFriendlyTagLabel(tag)),
                          ),
                          side: BorderSide.none,
                          backgroundColor: HomiziColors.accentWash,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                ContactGatePanel(gate: gate),
                if (match != null) ...[
                  const SizedBox(height: 12),
                  OwnContactShare(
                    match: match,
                    onDeviceOnly:
                        !ref.watch(appConfigProvider).connectsToSupabase ||
                        ref.watch(forceDemoModeProvider),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: Key('open-chat-${match.matchId}'),
                    onPressed: () => unawaited(
                      guardVerifiedAction(
                        context,
                        ref,
                        action: () async {
                          if (!context.mounted) {
                            return;
                          }
                          await context.push(
                            RoutePaths.chat(
                              match.matchId,
                              name: match.otherDisplayName,
                              title: listing.title,
                              otherUserId: listing.hostUserId,
                            ),
                          );
                        },
                      ),
                    ),
                    child: Text(homiziText(context, 'Chat')),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(homiziText(context, text)),
      ),
    );
  }
}
