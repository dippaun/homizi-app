import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';
import 'package:homizi/features/search_flow/swipe_matcher.dart';
import 'package:homizi/features/tenant_flow/tenant_chrome.dart';
import 'package:homizi/features/tenant_flow/tenant_explain.dart';
import 'package:homizi/features/tenant_flow/tenant_journey.dart';
import 'package:homizi/features/tenant_flow/tenant_order.dart';

enum TenantFlowStep {
  intro,
  priorities,
  host,
  how,
  results,
  score,
  colour,
  happier,
  journey,
  rank,
  browse,
  swipe,
  detail,
  match,
  chat,
  contact,
  docs,
  visit,
  booked,
}

/// Tenant onboarding and the six-step match journey at `/flow/tenant`.
class TenantFlowScreen extends ConsumerStatefulWidget {
  const TenantFlowScreen({super.key});

  @override
  ConsumerState<TenantFlowScreen> createState() => _TenantFlowScreenState();
}

class _TenantFlowScreenState extends ConsumerState<TenantFlowScreen> {
  final List<TenantFlowStep> _stack = [TenantFlowStep.intro];
  String? _focusId;
  List<String>? _swipeOrder;
  String? _slot;

  TenantFlowStep get _step => _stack.last;

  void _push(TenantFlowStep step) {
    setState(() => _stack.add(step));
  }

  void _back() {
    if (_stack.length > 1) {
      setState(() => _stack.removeLast());
      return;
    }
    HomiziBackButton.leave(context);
  }

  MatchSession get _session => ref.watch(matchControllerProvider);

  List<TenantFlowPick> _properties(MatchSession session) {
    return orderedTenantProperties(
      priorities: session.tenant,
      commute: session.commute,
      signals: session.signals,
    );
  }

  List<TenantFlowPick> _roomies(MatchSession session) {
    return orderedTenantRoomies(viewer: session.viewer);
  }

  TenantFlowPick? _focus(MatchSession session) {
    final id = _focusId;
    if (id == null) {
      final homes = _properties(session);
      return homes.isEmpty ? null : homes.first;
    }
    return tenantPickById(
          id: id,
          priorities: session.tenant,
          commute: session.commute,
          signals: session.signals,
          viewer: session.viewer,
        ) ??
        (_properties(session).isEmpty ? null : _properties(session).first);
  }

  void _remember(TenantFlowPick pick) {
    _focusId = pick.id;
  }

  bool _like(TenantFlowPick pick) {
    final notifier = ref.read(matchControllerProvider.notifier);
    notifier.setSide(pick.roomie ? MatchSide.host : MatchSide.tenant);
    final mutual = notifier.like(pick.id);
    notifier.setSide(MatchSide.tenant);
    return mutual;
  }

  void _skip(TenantFlowPick pick) {
    final notifier = ref.read(matchControllerProvider.notifier);
    notifier.setSide(pick.roomie ? MatchSide.host : MatchSide.tenant);
    notifier.skip(pick.id);
    notifier.setSide(MatchSide.tenant);
  }

  void _save(TenantFlowPick pick) {
    final notifier = ref.read(matchControllerProvider.notifier);
    notifier.setSide(pick.roomie ? MatchSide.host : MatchSide.tenant);
    notifier.toggleSave(pick.id);
    notifier.setSide(MatchSide.tenant);
  }

  void _openDetail(TenantFlowPick pick) {
    setState(() {
      _remember(pick);
      _stack.add(TenantFlowStep.detail);
    });
  }

  void _interested(TenantFlowPick pick) {
    final mutual = _like(pick);
    setState(() {
      _remember(pick);
      if (mutual) {
        _stack.add(TenantFlowStep.match);
      } else if (_step != TenantFlowStep.detail) {
        _stack.add(TenantFlowStep.detail);
      }
    });
  }

  void _openSwipe(List<TenantFlowPick> picks) {
    setState(() {
      _swipeOrder = [for (final pick in picks) pick.id];
      _stack.add(TenantFlowStep.swipe);
    });
  }

  void _book(String slot) {
    final id = _focusId;
    if (id != null) {
      ref.read(matchControllerProvider.notifier).bookVisit(id, slot);
    }
    setState(() {
      _slot = slot;
      _stack.add(TenantFlowStep.booked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final properties = _properties(session);
    final visible = [
      for (final pick in properties)
        if (!session.skipped.contains(pick.id)) pick,
    ];
    final roomies = _roomies(session);
    final focus = _focus(session);
    return KeyedSubtree(
      key: const Key('tenant-flow-screen'),
      child: switch (_step) {
        TenantFlowStep.intro => TenantIntroPage(
          onBack: _back,
          onNext: () {
            ref
                .read(matchControllerProvider.notifier)
                .setSide(MatchSide.tenant);
            _push(TenantFlowStep.priorities);
          },
        ),
        TenantFlowStep.priorities => TenantPrioritiesExplainPage(
          onBack: _back,
          onNext: () {
            ref.read(matchControllerProvider.notifier).setSide(MatchSide.host);
            _push(TenantFlowStep.host);
          },
          tenant: session.tenant,
          host: session.host,
          side: session.side,
          onSide: (side) {
            ref.read(matchControllerProvider.notifier).setSide(side);
          },
        ),
        TenantFlowStep.host => TenantPrioritiesExplainPage(
          pageKey: const Key('tenant-flow-host-explain'),
          showToggle: false,
          onBack: () {
            ref
                .read(matchControllerProvider.notifier)
                .setSide(MatchSide.tenant);
            _back();
          },
          onNext: () {
            ref
                .read(matchControllerProvider.notifier)
                .setSide(MatchSide.tenant);
            _push(TenantFlowStep.how);
          },
          tenant: session.tenant,
          host: session.host,
          side: MatchSide.host,
          onSide: (side) {
            ref.read(matchControllerProvider.notifier).setSide(side);
          },
        ),
        TenantFlowStep.how => TenantHowPage(
          onBack: _back,
          onNext: () => _push(TenantFlowStep.results),
        ),
        TenantFlowStep.results => TenantResultsPage(
          onBack: _back,
          onNext: () => _push(TenantFlowStep.score),
          properties: properties,
          roomies: roomies,
        ),
        TenantFlowStep.score => TenantScorePage(
          onBack: _back,
          onNext: () => _push(TenantFlowStep.colour),
          pick: properties.isEmpty ? null : properties.first,
        ),
        TenantFlowStep.colour => TenantColourPage(
          onBack: _back,
          onNext: () => _push(TenantFlowStep.happier),
        ),
        TenantFlowStep.happier => TenantHappierPage(
          onBack: _back,
          onNext: () => _push(TenantFlowStep.journey),
        ),
        TenantFlowStep.journey => TenantJourneyHubPage(
          onBack: _back,
          onNext: () {
            ref
                .read(matchControllerProvider.notifier)
                .setSide(MatchSide.tenant);
            _push(TenantFlowStep.rank);
          },
        ),
        TenantFlowStep.rank => TenantRankPage(
          onBack: _back,
          onSave: () => _push(TenantFlowStep.browse),
          side: session.side,
          tenant: session.tenant,
          host: session.host,
          onSide: (side) {
            ref.read(matchControllerProvider.notifier).setSide(side);
          },
          onReorderTenant: (oldIndex, newIndex) {
            ref
                .read(matchControllerProvider.notifier)
                .reorderTenant(oldIndex, newIndex);
          },
          onReorderHost: (oldIndex, newIndex) {
            ref
                .read(matchControllerProvider.notifier)
                .reorderHost(oldIndex, newIndex);
          },
        ),
        TenantFlowStep.browse => TenantBrowsePage(
          onBack: _back,
          onSwipe: () => _openSwipe(visible.isEmpty ? properties : visible),
          picks: visible,
          savedIds: session.saved,
          onSkip: _skip,
          onSave: _save,
          onInterested: _interested,
        ),
        TenantFlowStep.swipe => _SwipePage(
          picks: _swipePicks(properties),
          onBack: _back,
          onOpen: _openDetail,
          onDecision: (pick, decision) {
            if (decision == SwipeDecision.like) {
              final mutual = _like(pick);
              if (mutual && mounted) {
                setState(() {
                  _remember(pick);
                  _stack.add(TenantFlowStep.match);
                });
              }
            } else if (decision == SwipeDecision.skip) {
              _skip(pick);
            } else if (decision == SwipeDecision.save) {
              _save(pick);
            }
          },
          onDetails: () {
            final deck = _swipePicks(properties);
            if (deck.isNotEmpty) {
              _openDetail(deck.first);
            }
          },
        ),
        TenantFlowStep.detail =>
          focus == null
              ? _Missing(onBack: _back)
              : TenantDetailPage(
                  pick: focus,
                  onBack: _back,
                  onChat: () => _push(TenantFlowStep.chat),
                  onInterested: () => _interested(focus),
                ),
        TenantFlowStep.match =>
          focus == null
              ? _Missing(onBack: _back)
              : TenantMatchPage(
                  pick: focus,
                  onBack: _back,
                  onChat: () => _push(TenantFlowStep.chat),
                  onContact: () => _push(TenantFlowStep.contact),
                  onVisit: () => _push(TenantFlowStep.visit),
                ),
        TenantFlowStep.chat =>
          focus == null
              ? _Missing(onBack: _back)
              : TenantChatPage(
                  pick: focus,
                  messages: ref
                      .read(matchControllerProvider.notifier)
                      .messagesFor(focus.id),
                  onBack: _back,
                  onSend: (body) {
                    ref
                        .read(matchControllerProvider.notifier)
                        .send(focus.id, body);
                  },
                  onContact: () => _push(TenantFlowStep.contact),
                  onVisit: () => _push(TenantFlowStep.visit),
                  onDocs: () => _push(TenantFlowStep.docs),
                ),
        TenantFlowStep.contact =>
          focus == null
              ? _Missing(onBack: _back)
              : TenantContactPage(
                  pick: focus,
                  sharingOn: session.shareContact,
                  alreadyShared: session.contactShared.contains(focus.id),
                  onBack: _back,
                  onToggle: (value) {
                    ref
                        .read(matchControllerProvider.notifier)
                        .setShareContact(value);
                  },
                  onShare: () {
                    ref
                        .read(matchControllerProvider.notifier)
                        .shareContactWith(focus.id);
                    _back();
                  },
                ),
        TenantFlowStep.docs => TenantDocsPage(
          shared: focus != null && session.documentsShared.contains(focus.id),
          onBack: _back,
          onShare: () {
            final id = focus?.id;
            if (id != null) {
              ref.read(matchControllerProvider.notifier).shareDocumentsWith(id);
            }
          },
        ),
        TenantFlowStep.visit =>
          focus == null
              ? _Missing(onBack: _back)
              : TenantVisitPage(pick: focus, onBack: _back, onBook: _book),
        TenantFlowStep.booked =>
          focus == null
              ? _Missing(onBack: _back)
              : TenantBookedPage(
                  pick: focus,
                  slot: _slot ?? session.visits[focus.id] ?? visitSlots.first,
                  onBack: _back,
                ),
      },
    );
  }

  List<TenantFlowPick> _swipePicks(List<TenantFlowPick> properties) {
    final order = _swipeOrder;
    if (order == null) {
      return properties;
    }
    final byId = {for (final pick in properties) pick.id: pick};
    return [
      for (final id in order)
        if (byId[id] != null) byId[id]!,
    ];
  }
}

class _SwipePage extends StatelessWidget {
  const _SwipePage({
    required this.picks,
    required this.onBack,
    required this.onOpen,
    required this.onDecision,
    required this.onDetails,
  });

  final List<TenantFlowPick> picks;
  final VoidCallback onBack;
  final ValueChanged<TenantFlowPick> onOpen;
  final void Function(TenantFlowPick pick, SwipeDecision decision) onDecision;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final cards = [for (final pick in picks) _swipeCard(pick)];
    final byId = {for (final pick in picks) pick.id: pick};
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-swipe'),
      onBack: onBack,
      title: 'Tinder-Style Matching',
      stepLabel: '3',
      bottom: TenantNextButton(label: 'Detailed View', onPressed: onDetails),
      body: SwipeMatcher(
        key: ValueKey(cards.map((card) => card.id).join(',')),
        cards: cards,
        likeKey: const Key('tenant-swipe-like'),
        openLabel: 'Details',
        openKeyPrefix: 'tenant-swipe-open',
        onOpen: (card) {
          final pick = byId[card.id];
          if (pick != null) {
            onOpen(pick);
          }
        },
        onDecision: (card, decision) {
          final pick = byId[card.id];
          if (pick != null) {
            onDecision(pick, decision);
          }
        },
        onFinished: onDetails,
        onEditPreferences: onBack,
      ),
    );
  }
}

SwipeMatchCardData _swipeCard(TenantFlowPick pick) {
  return SwipeMatchCardData(
    id: pick.id,
    title: pick.title,
    subtitle: pick.place,
    meta: pick.priceLabel,
    photoAsset: pick.photos.isEmpty ? '' : pick.photos.first,
    percent: pick.percent,
    importantMismatch: pick.importantMismatch,
    reasons: [...pick.reasons, ...pick.differences, ...pick.blockers],
    badges: [if (pick.verified) FlowBadge.identity],
  );
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-missing'),
      onBack: onBack,
      title: 'Match',
      body: Center(
        child: Text(homiziText(context, 'This match is not in the demo.')),
      ),
    );
  }
}
