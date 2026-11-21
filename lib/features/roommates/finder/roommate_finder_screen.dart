import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/city_locality_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/compartment_bar.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/saved_summary.dart';
import 'package:homizi/core/widgets/section_masthead.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/find_roomie/find_roomie_widgets.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/finder_widgets.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/features/roommates/finder/roommate_profile_pane.dart';
import 'package:homizi/features/roommates/finder/roommate_requirements_board.dart';
import 'package:homizi/features/roommates/finder/roommate_suggested_grid.dart';
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

class _RoommateFinderScreenState extends ConsumerState<RoommateFinderScreen> {
  var _tab = 0;
  var _askReady = false;
  var _wants = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) {
        return;
      }
      await RoommateAskStore.read();
      if (!mounted) {
        return;
      }
      setState(() => _askReady = true);
      if (ref.read(finderProvider).people.isEmpty) {
        await ref.read(finderProvider.notifier).load();
      }
    });
  }

  bool _showBack(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return true;
    }
    return !homiziPathIsRootHome(
      router.routeInformationProvider.value.uri.path,
    );
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

  void _open(FinderPerson person) {
    context.push(RoutePaths.roommatePerson(person.id));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(finderProvider);
    return MinTouchScope(
      child: Scaffold(
        key: const Key('roommate-screen'),
        backgroundColor: HomiziColors.white,
        body: PageBackground(
          variant: PageBackgroundVariant.soft,
          child: SafeArea(
            child: RepaintBoundary(
              key: const Key('roommate-shot'),
              child: Column(
                children: [
                  if (snapshot.sample) const FindRoomieSampleChip(),
                  _header(),
                  Expanded(child: _page(snapshot)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionMasthead(
          leading: _showBack(context) ? const HomiziBackButton() : null,
        ),
      ],
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tabs(snapshot),
              const SizedBox(height: 8),
              _LocationButton(
                place: ref.watch(browsePlaceProvider),
                onSelected: (place) => unawaited(
                  ref.read(browsePlaceProvider.notifier).setPlace(place),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: _tab == 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _requirements(snapshot),
                )
              : _tab == 1
              ? _signedIn
                    ? _find(snapshot)
                    : const _RoomieLoginPrompt()
              : _signedIn
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _matches(snapshot),
                )
              : const _RoomieLoginPrompt(),
        ),
      ],
    );
  }

  Widget _tabs(FinderSnapshot snapshot) {
    final requirements = snapshot.requirementsSaved ? 1 : 0;
    return CompartmentBar(
      key: const Key('roommate-tabs'),
      selected: _tab,
      onSelected: (index) => setState(() => _tab = index),
      items: [
        CompartmentSpec(
          tileKey: const Key('roommate-tab-requirements'),
          icon: Icons.checklist_rounded,
          label: 'Your Roommate Profile',
          count: requirements,
        ),
        CompartmentSpec(
          tileKey: const Key('roommate-tab-find'),
          icon: Icons.groups_outlined,
          label: 'Find Roomie',
          count: snapshot.deck.length,
        ),
        CompartmentSpec(
          tileKey: const Key('roommate-tab-matches'),
          icon: Icons.auto_awesome,
          label: 'Roommate Matches',
          count: snapshot.suggestions.length,
        ),
      ],
    );
  }

  Widget _find(FinderSnapshot snapshot) {
    final narrowed = [
      for (final person in snapshot.people)
        if (finderPersonMatches(
          person: person,
          filters: snapshot.filters,
          city: snapshot.city,
        ))
          person,
    ];
    return Column(
      key: const Key('roommate-scroll'),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            key: const Key('roommate-filters'),
            tooltip: homiziText(context, 'Filter Roommates'),
            onPressed: _filters,
            icon: const Icon(Icons.tune, color: HomiziColors.ink),
          ),
        ),
        Expanded(
          child: RoommateSwipeDeck(
            people: snapshot.deck,
            requirements: snapshot.requirements,
            ask: snapshot.ask,
            requirementsSaved: snapshot.requirementsSaved,
            noPeople: narrowed.isEmpty,
            onSkip: _skip,
            onLater: (person) async {
              ref.read(finderProvider.notifier).markMaybe(person.id);
            },
            onInterested: _interested,
            onOpen: _open,
            onReview: () => ref.read(finderProvider.notifier).resetDeck(),
            onPreferences: () => setState(() => _tab = 0),
          ),
        ),
      ],
    );
  }

  Widget _matches(FinderSnapshot snapshot) {
    final people = snapshot.suggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('flatmate-rooms'),
            onPressed: () => context.push(RoutePaths.flatmateRooms),
            child: Text(
              homiziText(context, 'Shared rooms'),
              style: const TextStyle(color: HomiziColors.ink),
            ),
          ),
        ),
        Expanded(
          child: people.isEmpty
              ? EmptyState(
                  title: 'No roommates match',
                  message:
                      'Complete your preferences to see compatible roommates here.',
                  actionLabel: 'Fill preferences',
                  onAction: () => setState(() => _tab = 0),
                )
              : RoommateSuggestedGrid(
                  people: people,
                  requirements: snapshot.requirements,
                  ask: snapshot.ask,
                  saved: snapshot.requirementsSaved,
                  onOpen: _open,
                  onInterested: (person) => unawaited(_interested(person)),
                  onDismiss: (person) =>
                      ref.read(finderProvider.notifier).hidePerson(person.id),
                ),
        ),
      ],
    );
  }

  Widget _requirements(FinderSnapshot snapshot) {
    if (!_askReady) {
      return const PrefsSkeleton();
    }
    if (_wants) {
      final seed =
          snapshot.ask.want ??
          snapshot.ask.copyWith(order: RoommateAsk.wantOrder);
      return RoommateRequirementsBoard(
        initial: seed,
        saveLabel: 'Save requirements',
        showPublish: false,
        showBriefLink: false,
        catalog: RoommateAsk.wantOrder,
        onClose: () => setState(() => _wants = false),
        onSave: (want) =>
            _persist(snapshot.ask.copyWith(want: want), celebrate: true),
      );
    }
    return RoommateProfilePane(
      ask: snapshot.ask,
      onOpenWants: () => setState(() => _wants = true),
      onSave: (ask) => _persist(ask),
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
      setState(() => _wants = false);
      unawaited(context.push(RoutePaths.roommateSaved));
    }
  }
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.place, required this.onSelected});

  final BrowsePlace place;
  final ValueChanged<BrowsePlace> onSelected;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<BrowsePlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomiziColors.white,
      builder: (context) => _CitySearchSheet(initial: place),
    );
    if (picked != null && picked.city.trim().isNotEmpty) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = place.localities.isEmpty
        ? ''
        : ' · ${place.localities.length}';
    final heading = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: HomiziColors.ink,
      fontWeight: FontWeight.w800,
    );
    return InkWell(
      key: const Key('roommate-location'),
      onTap: () => _open(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.place,
            size: heading?.fontSize ?? 22,
            color: HomiziColors.logoOrange,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${place.city}$extra',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: heading,
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            size: (heading?.fontSize ?? 22) + 4,
            color: HomiziColors.ink,
          ),
        ],
      ),
    );
  }
}

class _RoomieLoginPrompt extends StatelessWidget {
  const _RoomieLoginPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        key: const Key('roommate-login-prompt'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 42,
            color: HomiziColors.logoOrange,
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Log in to find your roommate'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'Roommate cards stay hidden until you sign in. Your requirements can wait here.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: HomiziColors.inkSoft),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('roommate-login-button'),
            style: FilledButton.styleFrom(
              backgroundColor: HomiziColors.logoOrange,
              foregroundColor: HomiziColors.ink,
            ),
            onPressed: () => context.push(RoutePaths.login),
            child: Text(homiziText(context, 'Log in')),
          ),
        ],
      ),
    );
  }
}

class _CitySearchSheet extends StatefulWidget {
  const _CitySearchSheet({required this.initial});

  final BrowsePlace initial;

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  late String _city = widget.initial.city;
  late List<PickedPlace> _localities = [
    for (final name in widget.initial.localities) PickedPlace(label: name),
  ];
  late double _radius = widget.initial.radiusKm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                homiziText(context, 'Show homes and roommates here'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              CityLocalityField(
                city: _city,
                localities: _localities,
                onChanged: (selection) {
                  setState(() {
                    _city = selection.city;
                    _localities = selection.localities;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(
                  context,
                  'Within ${_radius.round()} km of a locality chip',
                ),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Slider(
                key: const Key('browse-radius'),
                min: 2,
                max: 25,
                divisions: 23,
                value: _radius.clamp(2, 25),
                activeColor: HomiziColors.logoOrange,
                label: '${_radius.round()} km',
                onChanged: (value) => setState(() => _radius = value),
              ),
              FilledButton(
                key: const Key('browse-place-apply'),
                style: FilledButton.styleFrom(
                  backgroundColor: HomiziColors.logoOrange,
                  foregroundColor: HomiziColors.ink,
                ),
                onPressed: _city.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                        BrowsePlace(
                          city: _city.trim(),
                          localities: [
                            for (final place in _localities) place.label,
                          ],
                          radiusKm: _radius,
                        ),
                      ),
                child: Text(homiziText(context, 'Use this location')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
