import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/media/portrait_asset.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/homizi_swipe_card.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/notifications_button.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/compatibility.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/sample_preference.dart';
import 'package:homizi/features/interest/demo_people_swipe_gateway.dart';
import 'package:homizi/features/interest/people_providers.dart';
import 'package:homizi/features/interest/people_swipe_gateway.dart';
import 'package:homizi/features/interest/swipe_deck.dart';
import 'package:homizi/features/interest/tenant_card.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  var _people = false;
  List<TenantCard> _tenants = const [];
  var _loadingPeople = false;
  String? _peopleError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPeople());
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loadingPeople = true;
      _peopleError = null;
    });
    try {
      var cards = await ref.read(peopleSwipeGatewayProvider).load();
      if (cards.isEmpty && ref.read(appConfigProvider).demoSkipLogin) {
        cards = await DemoPeopleSwipeGateway().load();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _tenants = cards;
        _loadingPeople = false;
      });
    } on PeopleSwipeFailure catch (error) {
      if (!mounted) {
        return;
      }
      if (ref.read(appConfigProvider).demoSkipLogin) {
        final cards = await DemoPeopleSwipeGateway().load();
        if (!mounted) {
          return;
        }
        setState(() {
          _tenants = cards;
          _loadingPeople = false;
          _peopleError = null;
        });
        return;
      }
      setState(() {
        _loadingPeople = false;
        _peopleError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(sessionProvider).role;
    final hostOnly = role == AccountRole.host;
    final both = role == AccountRole.both;
    final showPeople = hostOnly || (both && _people);
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: const ScreenTitle('Swipe'),
        actions: const [NotificationsButton(), SettingsButton()],
      ),
      body: HomiziFrame(
        child: Column(
          children: [
            if (both)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(homiziText(context, 'Homes')),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(homiziText(context, 'People')),
                    ),
                  ],
                  selected: {_people},
                  onSelectionChanged: (next) =>
                      setState(() => _people = next.first),
                ),
              ),
            Expanded(
              child: showPeople
                  ? _PeopleDeck(
                      cards: _tenants,
                      loading: _loadingPeople,
                      error: _peopleError,
                      onRetry: _loadPeople,
                    )
                  : const _HomeDeck(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDeck extends ConsumerWidget {
  const _HomeDeck();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(viewPreviewProvider('discover'));
    final discovery = ref.watch(discoveryProvider);
    final filters = ref.watch(listingFilterProvider);
    final visible = applyFilters(discovery.listings, filters);
    final noMatches =
        !filters.isDefault && visible.isEmpty && discovery.listings.isNotEmpty;
    final offline = keepHomesWhileOffline(
      error: discovery.error,
      hasHomes: discovery.listings.isNotEmpty,
    );
    final status = preview != ViewStatus.ready
        ? preview
        : discovery.loading
        ? ViewStatus.loading
        : !offline && discovery.error != null
        ? ViewStatus.error
        : visible.isEmpty
        ? ViewStatus.empty
        : ViewStatus.ready;
    return Column(
      children: [
        if (ref.watch(showStatePreviewProvider))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: StatePreviewBar(
              status: preview,
              onChanged: ref
                  .read(viewPreviewProvider('discover').notifier)
                  .setStatus,
            ),
          ),
        if (offline) const OfflineNote(),
        Expanded(
          child: AsyncStateBody(
            status: status,
            loadingMessage: 'Shuffling homes…',
            emptyTitle: noMatches ? 'No homes match' : 'Nothing left to review',
            emptyMessage: noMatches
                ? 'Try a wider budget or clear the filters.'
                : 'Published homes show up here. A pass does not remove a match.',
            emptyActionLabel: noMatches ? 'Clear filters' : null,
            onEmptyAction: noMatches
                ? () => ref.read(listingFilterProvider.notifier).reset()
                : null,
            errorTitle: 'Swipe is unavailable',
            errorMessage:
                discovery.error ?? 'Retry to see the sample deck again.',
            onRetry: () {
              ref
                  .read(viewPreviewProvider('discover').notifier)
                  .setStatus(ViewStatus.ready);
              if (ref.read(discoveryProvider).error != null) {
                unawaited(ref.read(discoveryProvider.notifier).refresh());
              }
            },
            child: _ListingDeck(listings: visible),
          ),
        ),
      ],
    );
  }
}

class _SwipeUndo {
  const _SwipeUndo({required this.id, required this.pass});

  final String id;
  final bool pass;
}

class _ListingDeck extends ConsumerStatefulWidget {
  const _ListingDeck({required this.listings});

  final List<Listing> listings;

  @override
  ConsumerState<_ListingDeck> createState() => _ListingDeckState();
}

class _ListingDeckState extends ConsumerState<_ListingDeck> {
  var _index = 0;
  var _dx = 0.0;
  String? _note;
  _SwipeUndo? _undo;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.listings.length) {
      return const EmptyState(
        title: 'You are caught up',
        message: 'Swipes were sent. An existing match stays in place.',
      );
    }
    final listing = widget.listings[_index];
    final busy = ref.watch(discoveryProvider).busy;
    final fit = scoreCompatibility(
      preference: sampleCompatibilityPreference,
      listing: listing,
    );
    final note = _note;
    return Column(
      children: [
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              homiziText(context, note),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: HomiziColors.inkSoft,
              ),
            ),
          ),
        Expanded(
          child: SwipeDeck(
            dx: _dx,
            busy: busy,
            note: null,
            canUndo: _undo != null && !busy,
            showUndo: false,
            likeLabel: 'Interested in ${listing.title}',
            passLabel: 'Pass on ${listing.title}',
            onDrag: (delta) => setState(() => _dx += delta),
            onRelease: () => _release(listing),
            onLike: () => unawaited(_act(listing, pass: false)),
            onPass: () => unawaited(_act(listing, pass: true)),
            onUndo: () => unawaited(_undoLast()),
            card: _HomeCard(
              listing: listing,
              fit: fit.score,
              busy: busy,
              canUndo: _undo != null && !busy,
              onOpen: () => context.push(RoutePaths.listing(listing.id)),
              onPass: () => unawaited(_act(listing, pass: true)),
              onLike: () => unawaited(_act(listing, pass: false)),
              onUndo: () => unawaited(_undoLast()),
              onChat: () => _openChat(listing),
            ),
          ),
        ),
      ],
    );
  }

  void _openChat(Listing listing) {
    final match = ref.read(discoveryProvider).matchForHost(listing.hostUserId);
    unawaited(
      guardVerifiedAction(
        context,
        ref,
        action: () async {
          if (!context.mounted) {
            return;
          }
          await context.push(
            RoutePaths.chat(
              match?.matchId ?? 'demo-match-${listing.id}',
              name: match?.otherDisplayName ?? listing.hostDisplayName,
              title: listing.title,
              otherUserId: listing.hostUserId,
              avatar: listing.hostAvatarUrl,
            ),
          );
        },
      ),
    );
  }

  void _release(Listing listing) {
    final pass = _dx < -90;
    final like = _dx > 90;
    setState(() => _dx = 0);
    if (pass || like) {
      unawaited(_act(listing, pass: pass));
    }
  }

  Future<void> _act(Listing listing, {required bool pass}) async {
    if (!pass && !ref.read(ownVerificationProvider).isVerified) {
      await guardVerifiedAction(
        context,
        ref,
        action: () => _act(listing, pass: false),
      );
      return;
    }
    final notice = pass
        ? await ref.read(discoveryProvider.notifier).pass(listing.id)
        : await ref.read(discoveryProvider.notifier).like(listing.id);
    if (!mounted) {
      return;
    }
    if (!pass && demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Interest sent',
        detail: 'The host can see this interest in the demo.',
      );
      return;
    }
    setState(() {
      _note = notice.message;
      _dx = 0;
      if (notice.ok) {
        _undo = _SwipeUndo(id: listing.id, pass: pass);
        _index += 1;
      }
    });
  }

  Future<void> _undoLast() async {
    final last = _undo;
    if (last == null || _index == 0) {
      return;
    }
    final notice = await ref.read(discoveryProvider.notifier).undo(last.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _note = notice.message;
      if (notice.ok) {
        _index -= 1;
        _undo = null;
      }
    });
  }
}

class _PeopleDeck extends ConsumerStatefulWidget {
  const _PeopleDeck({
    required this.cards,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<TenantCard> cards;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  ConsumerState<_PeopleDeck> createState() => _PeopleDeckState();
}

class _PeopleDeckState extends ConsumerState<_PeopleDeck> {
  var _index = 0;
  var _dx = 0.0;
  var _busy = false;
  String? _note;
  _SwipeUndo? _undo;
  int _budgetMin = InrRangeScale.min;
  int _budgetMax = InrRangeScale.max;

  @override
  void didUpdateWidget(covariant _PeopleDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards != widget.cards && _index > widget.cards.length) {
      _index = widget.cards.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const LoadingState(message: 'Loading people…');
    }
    final demo = ref.watch(appConfigProvider).demoSkipLogin;
    if (widget.error != null && !demo) {
      return ErrorState(
        title: 'People did not load',
        message: widget.error!,
        onRetry: () => unawaited(widget.onRetry()),
      );
    }
    final open = openBounds(
      start: _budgetMin,
      end: _budgetMax,
      min: InrRangeScale.min,
      max: InrRangeScale.max,
    );
    final visible = [
      for (final card in widget.cards)
        if (budgetOverlaps(
          min: card.budgetMinInr,
          max: card.budgetMaxInr,
          filterMin: open.start,
          filterMax: open.end,
        ))
          card,
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: HomiziRangeField(
            label: 'Tenant budget',
            min: InrRangeScale.min,
            max: InrRangeScale.max,
            step: InrRangeScale.step,
            start: _budgetMin,
            end: _budgetMax,
            formatValue: formatInr,
            openAtBounds: true,
            minSemantics: 'Budget minimum (INR)',
            maxSemantics: 'Budget maximum (INR)',
            sliderKey: const Key('people-budget-slider'),
            valueKey: const Key('people-budget-value'),
            onChanged: (start, end) => setState(() {
              _budgetMin = start;
              _budgetMax = end;
              _index = 0;
              _dx = 0;
              _undo = null;
            }),
          ),
        ),
        Expanded(child: _peopleBody(visible)),
      ],
    );
  }

  Widget _peopleBody(List<TenantCard> visible) {
    final demo = ref.watch(appConfigProvider).demoSkipLogin;
    final shown = demo && visible.isEmpty ? widget.cards : visible;
    if (!demo && (widget.cards.isEmpty || _index >= shown.length)) {
      if (widget.cards.isNotEmpty && visible.isEmpty) {
        return const EmptyState(
          title: 'No tenants in this budget.',
          message: 'Widen the range to see more people.',
        );
      }
      return const EmptyState(
        title: 'No one left to review',
        message:
            'Tenant profiles for your listings show up here. Swipe right if you are interested.',
      );
    }
    if (shown.isEmpty) {
      return const EmptyState(
        title: 'No one left to review',
        message:
            'Tenant profiles for your listings show up here. Swipe right if you are interested.',
      );
    }
    final card = shown[_index % shown.length];
    final note = _note;
    return Column(
      children: [
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              homiziText(context, note),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Expanded(
          child: SwipeDeck(
            dx: _dx,
            busy: _busy,
            note: null,
            canUndo: _undo != null && !_busy,
            showUndo: false,
            likeLabel: 'Interested in ${card.name}',
            passLabel: 'Pass on ${card.name}',
            onDrag: (delta) => setState(() => _dx += delta),
            onRelease: () {
              final pass = _dx < -90;
              final like = _dx > 90;
              setState(() => _dx = 0);
              if (pass || like) {
                unawaited(_act(card, pass: pass));
              }
            },
            onLike: () => unawaited(_act(card, pass: false)),
            onPass: () => unawaited(_act(card, pass: true)),
            onUndo: () => unawaited(_undoLast(card)),
            card: _PersonCard(
              card: card,
              busy: _busy,
              canUndo: _undo != null && !_busy,
              onPass: () => unawaited(_act(card, pass: true)),
              onLike: () => unawaited(_act(card, pass: false)),
              onUndo: () => unawaited(_undoLast(card)),
              onChat: () => _openChat(card),
            ),
          ),
        ),
      ],
    );
  }

  void _openChat(TenantCard card) {
    unawaited(
      guardVerifiedAction(
        context,
        ref,
        action: () async {
          if (!context.mounted) {
            return;
          }
          await context.push(
            RoutePaths.inboxChat(
              'demo-person-${card.userId}',
              name: card.name,
              title: card.occupation,
              otherUserId: card.userId,
              avatar: card.photoRef,
            ),
          );
        },
      ),
    );
  }

  Future<void> _act(TenantCard card, {required bool pass}) async {
    setState(() => _busy = true);
    try {
      final gateway = ref.read(peopleSwipeGatewayProvider);
      final message = pass
          ? await gateway.pass(card)
          : await gateway.like(card);
      if (!mounted) {
        return;
      }
      if (!pass && demoModeOn(ref)) {
        setState(() => _busy = false);
        openDemoSuccess(
          context,
          title: 'Interest sent',
          detail: 'This person can see your interest in the demo.',
        );
        return;
      }
      setState(() {
        _busy = false;
        _note = message;
        _undo = _SwipeUndo(id: card.userId, pass: pass);
        _index += 1;
        _dx = 0;
      });
    } on PeopleSwipeFailure catch (error) {
      if (!mounted) {
        return;
      }
      if (!pass && demoModeOn(ref)) {
        setState(() => _busy = false);
        openDemoSuccess(
          context,
          title: 'Interest sent',
          detail: 'This person can see your interest in the demo.',
        );
        return;
      }
      setState(() {
        _busy = false;
        _note = error.message;
        _dx = 0;
      });
    }
  }

  Future<void> _undoLast(TenantCard current) async {
    final last = _undo;
    if (last == null || _index == 0) {
      return;
    }
    final previous = widget.cards[_index - 1];
    setState(() => _busy = true);
    try {
      final message = await ref.read(peopleSwipeGatewayProvider).undo(previous);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note = message;
        _index -= 1;
        _undo = null;
      });
    } on PeopleSwipeFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note = error.message;
      });
    }
    if (current.userId.isEmpty) {
      return;
    }
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.listing,
    required this.fit,
    required this.busy,
    required this.canUndo,
    required this.onOpen,
    required this.onPass,
    required this.onLike,
    required this.onUndo,
    required this.onChat,
  });

  final Listing listing;
  final int fit;
  final bool busy;
  final bool canUndo;
  final VoidCallback onOpen;
  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onUndo;
  final VoidCallback onChat;

  bool get _verified =>
      listing.hostVerified ||
      listing.listingVerified ||
      listing.trust.anyIdentity;

  @override
  Widget build(BuildContext context) {
    return HomiziSwipeCard(
      busy: busy,
      title: listing.title,
      verified: _verified,
      onTap: onOpen,
      photo: PhotoStrip(assets: listing.photoAssets, onTap: onOpen),
      chips: [
        HomiziSwipeChip(label: '${formatInr(listing.rentInr)}/mo'),
        HomiziSwipeChip(label: listing.bhkLabel),
        HomiziSwipeChip(label: listing.locality),
        HomiziSwipeChip(label: listing.furnishingLabel),
      ],
      badge: HomiziSwipeBadge(
        label: '$fit% match',
        background: HomiziColors.ink,
        foreground: HomiziColors.white,
      ),
      actions: [
        HomiziSwipeAction(
          actionKey: const Key('swipe-undo'),
          tooltip: 'Undo',
          icon: Icons.replay,
          onPressed: !busy && canUndo ? onUndo : null,
        ),
        HomiziSwipeAction(
          tooltip: 'Pass',
          icon: Icons.close,
          onPressed: busy ? null : onPass,
        ),
        HomiziSwipeAction(
          tooltip: 'Interested',
          icon: Icons.favorite_border,
          size: 56,
          onPressed: busy ? null : onLike,
        ),
        HomiziSwipeAction(
          tooltip: 'Contact',
          icon: Icons.chat_bubble_outline,
          onPressed: busy ? null : onChat,
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.card,
    required this.busy,
    required this.canUndo,
    required this.onPass,
    required this.onLike,
    required this.onUndo,
    required this.onChat,
  });

  final TenantCard card;
  final bool busy;
  final bool canUndo;
  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onUndo;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final title = card.ageRange.isEmpty
        ? card.name
        : '${card.name}, ${card.ageRange}';
    return HomiziSwipeCard(
      busy: busy,
      title: title,
      verified: card.trust.anyIdentity,
      photo: ListingPhoto(
        asset: card.photoRef,
        semanticLabel: card.name,
        alignment: portraitAlignment,
      ),
      chips: [
        if (card.budgetLabel.isNotEmpty)
          HomiziSwipeChip(label: card.budgetLabel),
        if (card.city.isNotEmpty) HomiziSwipeChip(label: card.city),
        if (card.occupation.isNotEmpty) HomiziSwipeChip(label: card.occupation),
        if (card.moveInLabel.isNotEmpty)
          HomiziSwipeChip(label: card.moveInLabel),
      ],
      actions: [
        HomiziSwipeAction(
          actionKey: const Key('swipe-undo'),
          tooltip: 'Undo',
          icon: Icons.replay,
          onPressed: !busy && canUndo ? onUndo : null,
        ),
        HomiziSwipeAction(
          tooltip: 'Pass',
          icon: Icons.close,
          onPressed: busy ? null : onPass,
        ),
        HomiziSwipeAction(
          tooltip: 'Interested',
          icon: Icons.favorite_border,
          size: 56,
          onPressed: busy ? null : onLike,
        ),
        HomiziSwipeAction(
          tooltip: 'Chat',
          icon: Icons.chat_bubble_outline,
          onPressed: busy ? null : onChat,
        ),
      ],
    );
  }
}
