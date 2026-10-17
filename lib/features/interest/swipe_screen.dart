import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/format/place_label.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/notifications_button.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/core/widgets/settings_button.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/compatibility.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/sample_preference.dart';
import 'package:homizi/features/interest/people_providers.dart';
import 'package:homizi/features/interest/people_swipe_gateway.dart';
import 'package:homizi/features/interest/tenant_card.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';

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
      final cards = await ref.read(peopleSwipeGatewayProvider).load();
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
        title: const ScreenTitle('Swipe'),
        actions: const [NotificationsButton(), SettingsButton()],
      ),
      body: Column(
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
    return _DeckFrame(
      dx: _dx,
      busy: busy,
      note: _note,
      canUndo: _undo != null && !busy,
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
        dx: _dx,
        onOpen: () => context.push(RoutePaths.listing(listing.id)),
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
    final notice = pass
        ? await ref.read(discoveryProvider.notifier).pass(listing.id)
        : await ref.read(discoveryProvider.notifier).like(listing.id);
    if (!mounted) {
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
    if (widget.error != null) {
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
    if (widget.cards.isEmpty || _index >= visible.length) {
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
    final card = visible[_index];
    return _DeckFrame(
      dx: _dx,
      busy: _busy,
      note: _note,
      canUndo: _undo != null && !_busy,
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
      card: _PersonCard(card: card, dx: _dx),
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

class _DeckFrame extends StatelessWidget {
  const _DeckFrame({
    required this.card,
    required this.dx,
    required this.busy,
    required this.note,
    required this.canUndo,
    required this.likeLabel,
    required this.passLabel,
    required this.onDrag,
    required this.onRelease,
    required this.onLike,
    required this.onPass,
    required this.onUndo,
  });

  final Widget card;
  final double dx;
  final bool busy;
  final String? note;
  final bool canUndo;
  final String likeLabel;
  final String passLabel;
  final ValueChanged<double> onDrag;
  final VoidCallback onRelease;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (busy || event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          onLike();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          onPass();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyZ && canUndo) {
          onUndo();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: likeLabel): onLike,
          CustomSemanticsAction(label: passLabel): onPass,
          if (canUndo)
            const CustomSemanticsAction(label: 'Undo last swipe'): onUndo,
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const Key('swipe-card'),
                  onHorizontalDragUpdate: busy
                      ? null
                      : (details) => onDrag(details.delta.dx),
                  onHorizontalDragEnd: busy ? null : (_) => onRelease(),
                  child: Transform.translate(
                    offset: Offset(dx, 0),
                    child: Transform.rotate(angle: dx / 1400, child: card),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    key: const Key('swipe-undo'),
                    onPressed: canUndo ? onUndo : null,
                    icon: const Icon(Icons.undo),
                    label: Text(homiziText(context, 'Undo')),
                  ),
                  const Spacer(),
                  if (note != null)
                    Flexible(
                      child: Text(
                        homiziText(context, note!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.listing,
    required this.fit,
    required this.dx,
    required this.onOpen,
  });

  final Listing listing;
  final int fit;
  final double dx;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final km = aboutKmFromCityCentre(listing.locality);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey(listing.id),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoStrip(assets: listing.photoAssets, onTap: onOpen),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        homiziText(context, '$fit% match'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                ),
                _SwipeTint(dx: dx),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, listing.title),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    homiziText(context, '${listing.locality}, ${listing.city}'),
                  ),
                  if (km != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      homiziText(context, 'About $km km'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  RentBlock(listing: listing),
                  const SizedBox(height: 8),
                  MetaChips(listing: listing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.card, required this.dx});

  final TenantCard card;
  final double dx;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey(card.userId),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListingPhoto(asset: card.photoRef),
                _SwipeTint(dx: dx),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, card.name),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (card.trust.anyIdentity) ...[
                    const SizedBox(height: 8),
                    IdentityBadgeRow(badges: card.trust),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    homiziText(
                      context,
                      [
                        if (card.ageRange.isNotEmpty) card.ageRange,
                        if (card.occupation.isNotEmpty) card.occupation,
                        card.city,
                      ].join(' · '),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(homiziText(context, card.budgetLabel)),
                  const SizedBox(height: 4),
                  Text(homiziText(context, card.moveInLabel)),
                  if (card.lifestyle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in card.lifestyle)
                          Chip(
                            label: Text(
                              homiziText(context, tenantLifestyleLabel(tag)),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (card.about.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      homiziText(context, card.about),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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

class _SwipeTint extends StatelessWidget {
  const _SwipeTint({required this.dx});

  final double dx;

  @override
  Widget build(BuildContext context) {
    if (dx.abs() < 16) {
      return const SizedBox.shrink();
    }
    final like = dx > 0;
    final opacity = (dx.abs() / 220).clamp(0.15, 0.55);
    return IgnorePointer(
      child: ColoredBox(
        color: (like ? HomiziColors.accent : HomiziColors.line).withValues(
          alpha: opacity,
        ),
        child: Align(
          alignment: like ? Alignment.topLeft : Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HomiziColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  homiziText(context, like ? 'Interested' : 'Pass'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
