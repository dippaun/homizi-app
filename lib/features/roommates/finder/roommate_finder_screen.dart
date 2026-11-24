import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/saved_summary.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/live_account_sync.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/matching/homizi_ai_loader.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roommates/finder/finder_catalog.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/finder_widgets.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/features/roommates/finder/roommate_requirements_board.dart';
import 'package:homizi/features/roommates/finder/roommate_swipe_deck.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/ui/kit/page_background.dart';

class RoommateFinderScreen extends ConsumerStatefulWidget {
  const RoommateFinderScreen({super.key});

  @override
  ConsumerState<RoommateFinderScreen> createState() =>
      _RoommateFinderScreenState();
}

const roommatePostChoiceKey = 'roommate_finder_post';

bool roommatePostTestsSkipPrompt() {
  return WidgetsBinding.instance.runtimeType.toString().contains('Test');
}

class _RoommateFinderScreenState extends ConsumerState<RoommateFinderScreen> {
  var _askReady = false;
  var _wants = false;
  var _editWant = false;
  var _post = 'allow';
  var _postAsked = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) {
        return;
      }
      if (roommatePostTestsSkipPrompt()) {
        setState(() => _askReady = true);
      } else {
        await RoommateAskStore.read();
        if (!mounted) {
          return;
        }
        setState(() => _askReady = true);
        final brief = await LiveAccountSync.loadRoommateBrief();
        if (!mounted) {
          return;
        }
        final posted = brief?['profilePosted'] == true;
        final asked = brief?['postAsked'] == true;
        final saved = await readDeviceString(roommatePostChoiceKey);
        if (!mounted) {
          return;
        }
        final allow = posted || saved == 'allow';
        setState(() {
          _postAsked = asked || saved == 'allow' || saved == 'decline';
          _post = allow ? 'allow' : 'decline';
        });
      }
      if (ref.read(finderProvider).people.isEmpty) {
        await ref.read(finderProvider.notifier).load();
      }
    });
  }

  Future<void> _choosePost(bool allow, {bool alreadyAsked = false}) async {
    await writeDeviceString(roommatePostChoiceKey, allow ? 'allow' : 'decline');
    var ask = ref
        .read(finderProvider)
        .ask
        .copyWith(profilePosted: allow, postAsked: true);
    if (allow && !alreadyAsked) {
      ask = await _withMainProfile(ask);
    }
    await _persist(ask);
    await LiveAccountSync.roommateBrief(ask.toJson());
    if (!mounted) {
      return;
    }
    setState(() {
      _postAsked = true;
      _post = allow ? 'allow' : 'decline';
    });
  }

  Future<RoommateAsk> _withMainProfile(RoommateAsk ask) async {
    try {
      final profile = await ref
          .read(accountGatewayProvider)
          .loadTenantProfile();
      final city = profile.preferences.city.trim();
      final places = [
        for (final place in profile.preferences.localities)
          if (place.trim().isNotEmpty) place.trim(),
      ];
      final min = profile.preferences.budgetMinInr;
      final max = profile.preferences.budgetMaxInr;
      return ask.copyWith(
        city: city.isEmpty ? ask.city : city,
        localities: places.isEmpty ? ask.localities : places.join(', '),
        budgetMin: min ?? ask.budgetMin,
        budgetMax: max ?? ask.budgetMax,
        occupation: profile.occupation.trim().isEmpty
            ? ask.occupation
            : profile.occupation.trim(),
      );
    } on Object {
      return ask;
    }
  }

  Future<void> _filters() async {
    final current = ref.read(finderProvider).filters;
    final next = await showModalBottomSheet<FinderFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomiziColors.clear,
      builder: (context) => RoommateFilterSheet(
        initial: current,
        city: ref.read(finderProvider).city,
      ),
    );
    if (next == null) {
      return;
    }
    ref.read(finderProvider.notifier).applyFilters(next);
  }

  Future<void> _interested(FinderPerson person) async {
    await guardVerifiedAction(
      context,
      ref,
      action: () => _recordInterest(person),
    );
  }

  Future<void> _recordInterest(FinderPerson person) async {
    try {
      final message = await ref
          .read(roommateGatewayProvider)
          .like(person.seeker);
      if (!mounted) {
        return;
      }
      ref.read(finderProvider.notifier).markInterested(person.id);
      final mutual =
          person.seeker.likesYou ||
          message == DiscoveryCopy.demoLikeMatched ||
          message == DiscoveryCopy.serverMatched;
      if (mutual) {
        unawaited(context.push(RoutePaths.roommateMatch(person.id)));
        return;
      }
      unawaited(context.push(RoutePaths.roommateSent(person.id)));
    } on RoommateFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, error.message))),
      );
    }
  }

  Future<void> _skip(FinderPerson person) async {
    try {
      await ref.read(roommateGatewayProvider).pass(person.seeker);
    } on RoommateFailure {
      // A pass still leaves the deck so the next person can be reviewed.
    }
    if (!mounted) {
      return;
    }
    ref.read(finderProvider.notifier).pass(person.id);
  }

  DateTime _openedAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _open(FinderPerson person, {bool acted = false}) {
    final now = DateTime.now();
    if (now.difference(_openedAt) < const Duration(milliseconds: 500)) {
      return;
    }
    _openedAt = now;
    final path = RoutePaths.roommatePerson(person.id);
    context.push(acted ? '$path?acted=1' : path);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(finderProvider);
    final posted = _post == 'allow';
    return MinTouchScope(
      child: Scaffold(
        key: const Key('roommate-screen'),
        backgroundColor: HomiziColors.white,
        floatingActionButton: posted
            ? FloatingActionButton.extended(
                key: const Key('roommate-preferences'),
                onPressed: () => setState(() => _wants = !_wants),
                icon: const Icon(Icons.tune),
                label: Text(homiziText(context, 'Roommate preferences')),
              )
            : null,
        body: PageBackground(
          variant: PageBackgroundVariant.soft,
          child: SafeArea(
            child: RepaintBoundary(
              key: const Key('roommate-shot'),
              child: _page(snapshot),
            ),
          ),
        ),
      ),
    );
  }

  bool get _signedIn => ref.watch(signedInProvider);

  Widget _page(FinderSnapshot snapshot) {
    if (_wants || !_askReady) {
      return _loaded(snapshot);
    }
    final loading = snapshot.loading && snapshot.people.isEmpty;
    return HomiziAiMatchGate(
      loading: loading,
      kind: HomiziAiKind.roommates,
      child: _loaded(snapshot),
    );
  }

  Widget _loaded(FinderSnapshot snapshot) {
    if (snapshot.error != null && snapshot.people.isEmpty) {
      return ErrorState(
        title: 'Roommates did not load',
        message: snapshot.error!,
        onRetry: () => ref.read(finderProvider.notifier).load(),
      );
    }
    if (_wants) {
      return _preferences(snapshot);
    }
    return _find(snapshot);
  }

  Widget _find(FinderSnapshot snapshot) {
    final pool = snapshot.people.isEmpty && !_signedIn
        ? finderPeople
        : snapshot.people;
    final narrowed = [
      for (final person in pool)
        if (finderPersonMatches(
          person: person,
          filters: snapshot.filters,
          city: snapshot.city,
        ))
          person,
    ];
    final deck = snapshot.people.isEmpty && !_signedIn
        ? narrowed
        : snapshot.deck;
    final optedOut = _signedIn && !_postAsked && _post == 'decline';
    return Column(
      key: const Key('roommate-scroll'),
      children: [
        if (optedOut) _OptInCard(onAllow: () => unawaited(_choosePost(true))),
        Expanded(
          child: RoommateSwipeDeck(
            people: deck,
            requirements: snapshot.requirements,
            ask: snapshot.ask,
            requirementsSaved: snapshot.requirementsSaved,
            noPeople: narrowed.isEmpty,
            viewerCity: snapshot.city,
            onSkip: _skip,
            onLater: (person) async {
              ref.read(finderProvider.notifier).markMaybe(person.id);
            },
            onInterested: _interested,
            onOpen: (person) => _open(person),
            onReview: () => ref.read(finderProvider.notifier).resetDeck(),
            onPreferences: () => setState(() => _wants = true),
          ),
        ),
      ],
    );
  }

  Widget _preferences(FinderSnapshot snapshot) {
    if (!_askReady) {
      return const PrefsSkeleton();
    }
    final want = snapshot.ask.want;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            key: const Key('roommate-filters'),
            tooltip: homiziText(context, 'Filter Roommates'),
            onPressed: _filters,
            icon: const Icon(Icons.filter_list, color: HomiziColors.ink),
          ),
        ),
        Expanded(
          child: want == null || _editWant
              ? RoommateRequirementsBoard(
                  initial:
                      want ??
                      snapshot.ask.copyWith(order: RoommateAsk.wantOrder),
                  saveLabel: 'Save requirements',
                  showPublish: false,
                  showBriefLink: false,
                  catalog: RoommateAsk.wantOrder,
                  onClose: () => setState(() {
                    _wants = false;
                    _editWant = false;
                  }),
                  onSave: (next) => _persist(
                    snapshot.ask.copyWith(want: next),
                    celebrate: true,
                  ),
                )
              : SavedSummaryCard(
                  title: 'Roommate preferences',
                  fill: true,
                  fields: [
                    for (final id in RoommateAsk.wantOrder)
                      SavedField(
                        label: roommateAskTitle(id),
                        value: roommateAskValue(want, id),
                        icon: roommateAskIcon(id),
                      ),
                  ],
                  onEdit: () => setState(() => _editWant = true),
                ),
        ),
      ],
    );
  }

  Future<void> _persist(RoommateAsk ask, {bool celebrate = false}) async {
    ref.read(finderProvider.notifier).saveAsk(ask);
    final places = ask.localityList;
    final wants = ask.want ?? ask;
    try {
      await ref
          .read(roommateProfileGatewayProvider)
          .save(
            RequirementDraft(
              seekerKind: 'roommate',
              city: ask.city,
              locality: places.isEmpty ? '' : places.first,
              localities: places,
              budgetMinInr: ask.budgetMin,
              budgetMaxInr: ask.budgetMax,
              genderPreference: wants.gender,
              occupancyPreference: ask.room == 'own' ? 'just_me' : 'shared',
              foodHabits: ask.food == 'any' || ask.food == 'jain'
                  ? (ask.food == 'jain' ? const ['veg'] : const [])
                  : [ask.food],
              smoking: [
                switch (ask.smoking) {
                  'sometimes' => 'occasionally',
                  'regularly' => 'yes',
                  _ => 'no',
                },
              ],
              pets: ask.pets == 'has'
                  ? const ['have_pets']
                  : ask.pets == 'ok'
                  ? const ['pets_ok']
                  : const ['no_pets'],
              moveInDate: ask.moveIn,
              sleepSchedules: [ask.sleep],
              cleanliness: ask.cleanliness.clamp(1, 5),
              socialStyles: [
                ask.noise == 'quiet'
                    ? 'quiet'
                    : ask.noise == 'social'
                    ? 'social'
                    : 'balanced',
              ],
              workFromHome: ask.occupation == 'wfh' || ask.schedule == 'home',
              cooking: [ask.cooking],
              languages: ask.languages,
              hobbies: ask.hobbies,
              discoverable: ask.profilePosted,
              furnishings: [ask.furnishing],
              leaseMonths: ask.leaseMonths,
              roomTypes: [ask.room == 'own' ? 'private_room' : 'shared'],
              professions: [
                ask.occupation == 'student' ? 'student' : 'working',
              ],
              guestsPolicies: [
                ask.guests == 'often'
                    ? 'often'
                    : ask.guests == 'sometimes'
                    ? 'occasional'
                    : 'no_guests',
              ],
              flatmateNote: 'Looking for a ${ask.lookingFor} in ${ask.city}.',
            ),
          );
    } on Object {
      // The ranked brief stays on this device.
    }
    if (!mounted) {
      return;
    }
    if (celebrate) {
      setState(() {
        _wants = false;
        _editWant = false;
      });
      unawaited(context.push(RoutePaths.roommateSaved));
    }
  }
}

class _OptInCard extends StatelessWidget {
  const _OptInCard({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        key: const Key('roommate-post-opt-in-card'),
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.groups_outlined, color: HomiziColors.logoOrange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  homiziText(
                    context,
                    'Your profile is not listed as a roommate seeker.',
                  ),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                key: const Key('roommate-post-opt-in'),
                value: false,
                activeThumbColor: HomiziColors.logoOrange,
                onChanged: (value) {
                  if (value) {
                    onAllow();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
