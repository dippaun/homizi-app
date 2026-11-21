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
        final asked =
            brief?['postAsked'] == true || brief?['profilePosted'] == true;
        if (asked) {
          final allow = brief?['profilePosted'] == true;
          setState(() => _post = allow ? 'allow' : 'decline');
          await writeDeviceString(
            roommatePostChoiceKey,
            allow ? 'allow' : 'decline',
          );
        } else {
          final saved = await readDeviceString(roommatePostChoiceKey);
          if (!mounted) {
            return;
          }
          if (saved == 'allow' || saved == 'decline') {
            setState(() => _post = saved!);
            await _choosePost(saved == 'allow', alreadyAsked: true);
          } else if (ref.read(signedInProvider)) {
            setState(() => _post = '');
            await _askToPost();
          }
        }
      }
      if (ref.read(finderProvider).people.isEmpty) {
        await ref.read(finderProvider.notifier).load();
      }
    });
  }

  Future<void> _askToPost() async {
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PostPrompt(),
    );
    if (!mounted || allow == null) {
      return;
    }
    await _choosePost(allow);
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
    setState(() => _post = allow ? 'allow' : 'decline');
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

  void _open(FinderPerson person, {bool acted = false}) {
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
    if (snapshot.loading && snapshot.people.isEmpty) {
      return const LoadingState(message: 'Finding roommates…');
    }
    if (snapshot.error != null && snapshot.people.isEmpty) {
      return ErrorState(
        title: 'Roommates did not load',
        message: snapshot.error!,
        onRetry: () => ref.read(finderProvider.notifier).load(),
      );
    }
    if (_signedIn && _post == 'decline') {
      return _PostBlocked(onAllow: () => unawaited(_choosePost(true)));
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
    return Column(
      key: const Key('roommate-scroll'),
      children: [
        Expanded(
          child: RoommateSwipeDeck(
            people: deck,
            requirements: snapshot.requirements,
            ask: snapshot.ask,
            requirementsSaved: snapshot.requirementsSaved,
            noPeople: narrowed.isEmpty,
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

class _PostPrompt extends StatelessWidget {
  const _PostPrompt();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('roommate-post-prompt'),
      backgroundColor: HomiziColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: HomiziColors.accentWash,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Icon(
                  Icons.groups_outlined,
                  color: HomiziColors.logoOrange,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              homiziText(context, 'Post your profile as a roommate finder?'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                'People looking for a roommate can see your profile and how you match. You can change this later in Settings.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('roommate-post-decline'),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(homiziText(context, "Don't allow")),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('roommate-post-allow'),
                    style: FilledButton.styleFrom(
                      backgroundColor: HomiziColors.logoOrange,
                      foregroundColor: HomiziColors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(homiziText(context, 'Allow')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostBlocked extends StatelessWidget {
  const _PostBlocked({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        key: const Key('roommate-post-blocked'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.visibility_off_outlined,
            size: 42,
            color: HomiziColors.logoOrange,
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(
              context,
              "Without posting your profile as a roommate, we can't continue further",
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('roommate-post-opt-in'),
            style: FilledButton.styleFrom(
              backgroundColor: HomiziColors.logoOrange,
              foregroundColor: HomiziColors.ink,
            ),
            onPressed: onAllow,
            child: Text(homiziText(context, 'Post my profile')),
          ),
        ],
      ),
    );
  }
}
