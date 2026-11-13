import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/matching/match_catalog.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/post_analyzer/property_card_data.dart';
import 'package:homizi/features/post_analyzer/property_match_adapter.dart';
import 'package:homizi/shared/widgets/homizi_property_card.dart';

/// Full-screen property matching deck at `/match/swipe`.
class PropertySwipePage extends ConsumerStatefulWidget {
  const PropertySwipePage({super.key, this.onShowPeople});

  /// Hosts who also seek a home can open the people deck from here.
  final VoidCallback? onShowPeople;

  @override
  ConsumerState<PropertySwipePage> createState() => _PropertySwipePageState();
}

class _PropertySwipePageState extends ConsumerState<PropertySwipePage>
    with SingleTickerProviderStateMixin {
  final _gone = <String>{};
  final _localSaved = <String>{};
  var _chip = PropertySwipeChip.forYou;
  var _dx = 0.0;
  var _busy = false;
  var _animating = false;
  String? _banner;
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(viewPreviewProvider('discover'));
    final discovery = ref.watch(discoveryProvider);
    final filters = ref.watch(listingFilterProvider);
    final session = ref.watch(matchControllerProvider);
    final offline = keepHomesWhileOffline(
      error: discovery.error,
      hasHomes: discovery.listings.isNotEmpty,
    );
    final source = _source(discovery.listings);
    final visible = applyFilters(source, filters);
    final scored = [
      for (final listing in visible)
        if (!_gone.contains(listing.id) &&
            !discovery.likedIds.contains(listing.id))
          ScoredProperty(
            listing: listing,
            score: scoreSwipeProperty(
              listing: listing,
              priorities: session.tenant,
              commute: session.commute,
              signals: session.signals,
            ),
          ),
    ];
    final deck = filterScoredProperties(
      scored,
      _chip,
      priorities: session.tenant,
    );
    final status = preview != ViewStatus.ready
        ? preview
        : discovery.loading && discovery.listings.isEmpty
        ? ViewStatus.loading
        : !offline && discovery.error != null && discovery.listings.isEmpty
        ? ViewStatus.error
        : deck.isEmpty
        ? ViewStatus.empty
        : ViewStatus.ready;
    return Scaffold(
      key: const Key('property-swipe-page'),
      backgroundColor: HomiziColors.soft,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onShowPeople: widget.onShowPeople),
            if (ref.watch(showStatePreviewProvider))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: StatePreviewBar(
                  status: preview,
                  onChanged: ref
                      .read(viewPreviewProvider('discover').notifier)
                      .setStatus,
                ),
              ),
            _Chips(
              selected: _chip,
              onSelected: (chip) => setState(() {
                _chip = chip;
                _dx = 0;
                _banner = null;
              }),
            ),
            if (offline) const OfflineNote(),
            if (_banner != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  homiziText(context, _banner!),
                  style: const TextStyle(color: HomiziColors.error),
                ),
              ),
            Expanded(
              child: AsyncStateBody(
                status: status,
                loadingMessage: 'Finding homes that fit your priorities…',
                emptyTitle: _emptyTitle(filters),
                emptyMessage: _emptyMessage(filters),
                emptyActionLabel: _emptyAction(filters),
                onEmptyAction: _emptyAction(filters) == null
                    ? null
                    : () {
                        if (!filters.isDefault) {
                          ref.read(listingFilterProvider.notifier).reset();
                        }
                        setState(() => _chip = PropertySwipeChip.forYou);
                      },
                errorTitle: 'Matches did not load',
                errorMessage:
                    discovery.error ?? 'Retry to load published homes.',
                onRetry: () =>
                    unawaited(ref.read(discoveryProvider.notifier).refresh()),
                child: deck.isEmpty
                    ? const SizedBox.shrink()
                    : _Deck(
                        current: deck.first,
                        hasNext: deck.length > 1,
                        dx: _dx,
                        busy: _busy,
                        saved: _isSaved(deck.first.listing, discovery),
                        commuteLabel: _commute(session),
                        onDrag: _onDrag,
                        onRelease: () => unawaited(_release(deck.first)),
                        onOpen: () => _open(deck.first),
                        onSave: () => unawaited(_save(deck.first.listing)),
                        onSkip: () => unawaited(_skip(deck.first.listing)),
                        onInterested: () => unawaited(_interested(deck.first)),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Listing> _source(List<Listing> discovery) {
    final config = ref.read(appConfigProvider);
    final demo = !config.connectsToSupabase || ref.read(forceDemoModeProvider);
    if (!demo) {
      return discovery;
    }
    final ids = {for (final listing in discovery) listing.id};
    return [
      ...discovery,
      for (final home in demoMatchHomes)
        if (!ids.contains(home.id)) home,
    ];
  }

  bool _isSaved(Listing listing, DiscoveryState discovery) {
    return discovery.savedIds.contains(listing.id) ||
        _localSaved.contains(listing.id);
  }

  String? _commute(MatchSession session) {
    const mapsKey = String.fromEnvironment('MAPS_API_KEY');
    return officeCommuteLine(
      officeSaved: officeWasSaved(
        officeIds: [for (final office in session.offices) office.id],
        activeOfficeId: session.activeOfficeId,
      ),
      mapsEnabled: mapsKey.trim().isNotEmpty,
      providerLine: null,
    );
  }

  String _emptyTitle(ListingFilters filters) {
    if (!filters.isDefault) {
      return 'No homes match';
    }
    return switch (_chip) {
      PropertySwipeChip.near => 'No homes near you',
      PropertySwipeChip.budget => 'Nothing in your budget',
      PropertySwipeChip.top => 'No top matches yet',
      PropertySwipeChip.furnished => 'No furnished homes',
      PropertySwipeChip.forYou => 'Nothing left to review',
    };
  }

  String _emptyMessage(ListingFilters filters) {
    if (!filters.isDefault) {
      return 'Try a wider search or clear the filters.';
    }
    return switch (_chip) {
      PropertySwipeChip.near =>
        'Near Me uses your saved localities. Set them in priorities to see homes there.',
      PropertySwipeChip.budget =>
        'These homes sit outside the budget in your priorities.',
      _ => 'Published homes that fit your priorities show up here.',
    };
  }

  String? _emptyAction(ListingFilters filters) {
    if (!filters.isDefault || _chip != PropertySwipeChip.forYou) {
      return 'Show For You';
    }
    return null;
  }

  void _onDrag(double delta) {
    if (_animating || _busy) {
      return;
    }
    setState(() => _dx += delta);
  }

  Future<void> _release(ScoredProperty current) async {
    if (_animating || _busy) {
      return;
    }
    if (_dx > 110) {
      await _glide(MediaQuery.sizeOf(context).width);
      if (mounted) {
        await _interested(current);
      }
      return;
    }
    if (_dx < -110) {
      await _glide(-MediaQuery.sizeOf(context).width);
      if (mounted) {
        await _skip(current.listing);
      }
      return;
    }
    await _glide(0);
  }

  Future<void> _glide(double target) async {
    if (!mounted) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dx = target == 0 ? 0 : _dx);
      return;
    }
    _animating = true;
    final start = _dx;
    void tick() {
      if (!mounted) {
        return;
      }
      setState(() {
        _dx =
            start +
            (target - start) * Curves.easeOutCubic.transform(_motion.value);
      });
    }

    _motion.addListener(tick);
    await _motion.forward(from: 0);
    _motion.removeListener(tick);
    _animating = false;
    if (mounted && target == 0) {
      setState(() => _dx = 0);
    }
  }

  Future<void> _open(ScoredProperty current) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PropertyDetailPreview(
          data: _data(current, saved: _savedNow(current.listing)),
          onInterested: () async {
            Navigator.of(context).pop();
            await _interested(current);
          },
          onSkip: () async {
            Navigator.of(context).pop();
            await _skip(current.listing);
          },
        ),
      ),
    );
  }

  HomiziPropertyCardData _data(ScoredProperty current, {required bool saved}) {
    return propertyCardData(
      listing: current.listing,
      score: current.score,
      saved: saved,
      commuteLabel: _commute(ref.read(matchControllerProvider)),
    );
  }

  bool _savedNow(Listing listing) {
    return _isSaved(listing, ref.read(discoveryProvider));
  }

  Future<void> _save(Listing listing) async {
    setState(() => _busy = true);
    final known = ref.read(discoveryProvider).byId(listing.id) != null;
    if (known) {
      final notice = await ref
          .read(discoveryProvider.notifier)
          .toggleSave(listing.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _banner = notice.ok ? null : notice.message;
      });
      return;
    }
    final gateway = ref.read(discoveryGatewayProvider);
    final saved = _localSaved.contains(listing.id);
    try {
      final message = saved
          ? await gateway.unsaveListing(listing.id)
          : await gateway.saveListing(listing);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        if (saved) {
          _localSaved.remove(listing.id);
        } else {
          _localSaved.add(listing.id);
        }
        _banner = null;
      });
      ref.read(matchControllerProvider.notifier).toggleSave(listing.id);
      if (message.isEmpty) {
        return;
      }
    } on DiscoveryFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _banner = error.message;
      });
    }
  }

  Future<void> _skip(Listing listing) async {
    setState(() => _busy = true);
    final known = ref.read(discoveryProvider).byId(listing.id) != null;
    String? error;
    try {
      if (known) {
        final notice = await ref
            .read(discoveryProvider.notifier)
            .pass(listing.id);
        if (!notice.ok) {
          error = notice.message;
        }
      } else {
        await ref.read(discoveryGatewayProvider).passListing(listing);
      }
    } on DiscoveryFailure catch (failure) {
      error = failure.message;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _dx = 0;
      _banner = error;
      if (error == null) {
        _gone.add(listing.id);
      }
    });
  }

  Future<void> _interested(ScoredProperty current) async {
    final listing = current.listing;
    setState(() => _busy = true);
    final known = ref.read(discoveryProvider).byId(listing.id) != null;
    DiscoveryNotice notice;
    try {
      if (known) {
        notice = await ref.read(discoveryProvider.notifier).like(listing.id);
      } else {
        final message = await ref
            .read(discoveryGatewayProvider)
            .likeListing(listing);
        notice = DiscoveryNotice(message: message, ok: true);
      }
    } on DiscoveryFailure catch (failure) {
      notice = DiscoveryNotice(message: failure.message, ok: false);
    }
    if (!mounted) {
      return;
    }
    final mutual = ref.read(matchControllerProvider.notifier).like(listing.id);
    setState(() {
      _busy = false;
      _dx = 0;
      if (notice.ok) {
        _gone.add(listing.id);
        _banner = null;
      } else {
        _banner = notice.message;
      }
    });
    if (!notice.ok || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => InterestSentPage(
          hostName: listing.hostDisplayName,
          title: listing.title,
          detail: _interestDetail(notice.message, mutual),
          hostNotified: _hostNotified(notice.message),
        ),
      ),
    );
  }

  bool _hostNotified(String message) {
    return message == DiscoveryCopy.serverLike ||
        message == DiscoveryCopy.serverMatched;
  }

  String _interestDetail(String message, bool mutual) {
    if (mutual || message == DiscoveryCopy.demoLikeMatched) {
      return 'You both showed interest. Contact stays hidden until it is shared.';
    }
    return message;
  }
}

class _PopBack extends StatelessWidget {
  const _PopBack();

  @override
  Widget build(BuildContext context) {
    return BackButton(
      onPressed: () {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
          return;
        }
        HomiziBackButton.leave(context);
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onShowPeople});

  final VoidCallback? onShowPeople;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          const HomiziBackButton(),
          Expanded(
            child: Column(
              children: [
                const BrandLockup(markSize: 26),
                Text(
                  homiziText(context, 'Find the place which you deserve'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomiziColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('property-filter'),
            tooltip: homiziText(context, 'Filters'),
            onPressed: () => _push(context, RoutePaths.filters),
            icon: const Icon(Icons.tune, color: HomiziColors.ink),
          ),
          IconButton(
            key: const Key('property-bell'),
            tooltip: homiziText(context, 'Notifications'),
            onPressed: () => _push(context, RoutePaths.notifications),
            icon: const Icon(
              Icons.notifications_outlined,
              color: HomiziColors.ink,
            ),
          ),
          if (onShowPeople != null)
            IconButton(
              key: const Key('property-show-people'),
              tooltip: homiziText(context, 'People'),
              onPressed: onShowPeople,
              icon: const Icon(Icons.groups_outlined, color: HomiziColors.ink),
            ),
        ],
      ),
    );
  }

  void _push(BuildContext context, String path) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    router.push(path);
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.selected, required this.onSelected});

  final PropertySwipeChip selected;
  final ValueChanged<PropertySwipeChip> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final chip in PropertySwipeChip.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ChoiceChip(
                key: Key('property-chip-${chip.name}'),
                label: Text(homiziText(context, propertySwipeChipLabel(chip))),
                selected: selected == chip,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: selected == chip
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
                selectedColor: HomiziColors.accent,
                backgroundColor: HomiziColors.white,
                side: BorderSide(
                  color: selected == chip
                      ? HomiziColors.accent
                      : HomiziColors.line,
                ),
                onSelected: (_) => onSelected(chip),
              ),
            ),
        ],
      ),
    );
  }
}

class _Deck extends StatelessWidget {
  const _Deck({
    required this.current,
    required this.hasNext,
    required this.dx,
    required this.busy,
    required this.saved,
    required this.commuteLabel,
    required this.onDrag,
    required this.onRelease,
    required this.onOpen,
    required this.onSave,
    required this.onSkip,
    required this.onInterested,
  });

  final ScoredProperty current;
  final bool hasNext;
  final double dx;
  final bool busy;
  final bool saved;
  final String? commuteLabel;
  final ValueChanged<double> onDrag;
  final VoidCallback onRelease;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSkip;
  final VoidCallback onInterested;

  @override
  Widget build(BuildContext context) {
    final data = propertyCardData(
      listing: current.listing,
      score: current.score,
      saved: saved,
      commuteLabel: commuteLabel,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Stack(
        children: [
          if (hasNext)
            const Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomiziColors.white,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    border: Border.fromBorderSide(
                      BorderSide(color: HomiziColors.line),
                    ),
                  ),
                ),
              ),
            ),
          GestureDetector(
            onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
            onHorizontalDragEnd: (_) => onRelease(),
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.rotate(
                angle: (dx / 1600).clamp(-0.15, 0.15),
                child: HomiziPropertyCard(
                  key: const Key('swipe-card'),
                  data: data,
                  busy: busy,
                  onTap: onOpen,
                  onSave: onSave,
                  onSkip: onSkip,
                  onInterested: onInterested,
                  onWhy: onOpen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen preview of the same card. Opened by tapping the deck.
class PropertyDetailPreview extends StatelessWidget {
  const PropertyDetailPreview({
    required this.data,
    required this.onInterested,
    required this.onSkip,
    super.key,
  });

  final HomiziPropertyCardData data;
  final VoidCallback onInterested;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('property-preview'),
      backgroundColor: HomiziColors.soft,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const _PopBack(),
        title: Text(homiziText(context, data.title)),
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: HomiziPropertyCard(
          data: data,
          onSkip: onSkip,
          onInterested: onInterested,
        ),
      ),
    );
  }
}

/// Confirmation after interest is recorded.
class InterestSentPage extends StatelessWidget {
  const InterestSentPage({
    required this.hostName,
    required this.title,
    required this.detail,
    required this.hostNotified,
    super.key,
  });

  final String hostName;
  final String title;
  final String detail;
  final bool hostNotified;

  @override
  Widget build(BuildContext context) {
    final host = hostName.trim().isEmpty ? 'The host' : hostName.trim();
    return Scaffold(
      key: const Key('property-interest-sent'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const _PopBack(),
        title: Text(homiziText(context, 'Interest sent')),
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.check_circle, color: HomiziColors.success, size: 64),
          const SizedBox(height: 16),
          Text(
            homiziText(context, 'Interest sent'),
            key: const Key('property-interest-title'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              hostNotified
                  ? '$host has been notified about $title.'
                  : 'Your interest in $title is saved on this device.',
            ),
            style: const TextStyle(color: HomiziColors.ink, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, detail),
            style: const TextStyle(color: HomiziColors.inkSoft, fontSize: 15),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('property-interest-next'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(homiziText(context, 'Keep swiping')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('property-interest-matches'),
            onPressed: () {
              final router = GoRouter.maybeOf(context);
              if (router == null) {
                Navigator.of(context).maybePop();
                return;
              }
              router.go(RoutePaths.matches);
            },
            child: Text(homiziText(context, 'View matches')),
          ),
        ],
      ),
    );
  }
}
