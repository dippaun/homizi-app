import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/city_locality_field.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/saved_summary.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/find_roomie/find_roomie_widgets.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/finder_widgets.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/features/roommates/finder/roommate_requirements_board.dart';
import 'package:homizi/features/roommates/finder/roommate_suggested_grid.dart';
import 'package:homizi/features/roommates/finder/roommate_swipe_deck.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/shell/min_touch.dart';

class RoommateFinderScreen extends ConsumerStatefulWidget {
  const RoommateFinderScreen({super.key});

  @override
  ConsumerState<RoommateFinderScreen> createState() =>
      _RoommateFinderScreenState();
}

class _RoommateFinderScreenState extends ConsumerState<RoommateFinderScreen> {
  var _tab = 0;
  var _askReady = false;
  var _askSaved = false;
  var _editAsk = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) {
        return;
      }
      final saved = await RoommateAskStore.read();
      if (!mounted) {
        return;
      }
      setState(() {
        _askSaved = saved != null;
        _askReady = true;
      });
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
        body: SafeArea(
          child: RepaintBoundary(
            key: const Key('roommate-shot'),
            child: Material(
              color: HomiziColors.white,
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

  Widget _headerIcon(
    Key key,
    String tooltip,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return IconButton(
      key: key,
      tooltip: homiziText(context, tooltip),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
      onPressed: onPressed,
      icon: Icon(icon, color: HomiziColors.ink, size: 22),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          if (_showBack(context))
            const HomiziBackButton()
          else
            const SizedBox(width: 8),
          const HomiziMark(size: 22),
          const SizedBox(width: 4),
          const Text(
            'HOMIZI',
            maxLines: 1,
            style: TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
          _LocationButton(
            city: ref.watch(finderProvider).city,
            onSelected: (city) =>
                ref.read(finderProvider.notifier).setCity(city),
          ),
          _headerIcon(
            const Key('roommate-header-alerts'),
            'Alerts',
            Icons.notifications_none,
            () => unawaited(context.push(RoutePaths.notifications)),
          ),
          _headerIcon(
            const Key('roommate-header-chat'),
            'Chat',
            Icons.chat_bubble_outline,
            () => unawaited(context.push(RoutePaths.chats)),
          ),
          _headerIcon(
            const Key('roommate-header-profile'),
            'Profile',
            Icons.account_circle_outlined,
            () => unawaited(context.push(RoutePaths.profile)),
          ),
        ],
      ),
    );
  }

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
              Text(
                homiziText(context, 'Roommate Finder'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                homiziText(
                  context,
                  'Find a compatible roommate based on your lifestyle, budget and preferences.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: HomiziColors.inkSoft),
              ),
              const SizedBox(height: 8),
              const FindRoomieEntryLink(),
              const SizedBox(height: 8),
              _tabs(),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: _tab == 0
              ? _find(snapshot)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _tab == 1
                      ? _matches(snapshot)
                      : _requirements(snapshot),
                ),
        ),
      ],
    );
  }

  Widget _tabs() {
    return SingleChildScrollView(
      key: const Key('roommate-tabs'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tabButton(0, 'Find Roommate', 'roommate-tab-find'),
          const SizedBox(width: 8),
          _tabButton(1, 'My Roommate Matches', 'roommate-tab-matches'),
          const SizedBox(width: 8),
          _tabButton(2, 'My Requirements', 'roommate-tab-requirements'),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label, String keyName) {
    final selected = _tab == index;
    return Material(
      color: selected ? HomiziColors.logoOrange : HomiziColors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        key: Key(keyName),
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => _tab = index),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? HomiziColors.logoOrange : HomiziColors.line,
            ),
          ),
          child: Text(
            homiziText(context, label),
            maxLines: 1,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
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
            noPeople: narrowed.isEmpty,
            onSkip: _skip,
            onLater: (person) async {
              ref.read(finderProvider.notifier).markMaybe(person.id);
            },
            onInterested: _interested,
            onOpen: _open,
            onReview: () => ref.read(finderProvider.notifier).resetDeck(),
            onPreferences: () => setState(() => _tab = 2),
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
                  onAction: () => setState(() => _tab = 2),
                )
              : RoommateSuggestedGrid(
                  people: people,
                  requirements: snapshot.requirements,
                  ask: snapshot.ask,
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
    if (_askSaved && !_editAsk) {
      final ask = snapshot.ask;
      return ListView(
        children: [
          SavedSummaryCard(
            title: 'Priorities saved ✓',
            lines: [
              '${ask.city} · ${ask.localities}',
              'Budget ${ask.budgetMin}–${ask.budgetMax}',
              'Food ${ask.food}',
            ],
            onEdit: () => setState(() => _editAsk = true),
          ),
        ],
      );
    }
    return RoommateRequirementsBoard(
      initial: snapshot.ask,
      onSave: (ask) async {
        setState(() => _askSaved = true);
        ref.read(finderProvider.notifier).saveAsk(ask);
        final places = ask.localityList;
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
                  genderPreference: ask.gender,
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
                  workFromHome:
                      ask.occupation == 'wfh' || ask.schedule == 'home',
                  cooking: [ask.cooking],
                  languages: ask.languages,
                  hobbies: ask.hobbies,
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
                  flatmateNote:
                      'Looking for a ${ask.lookingFor} in ${ask.city}. ${ask.hometown.trim()}',
                ),
              );
        } on Object {
          // The ranked brief stays on this device.
        }
        if (!mounted) {
          return;
        }
        unawaited(context.push(RoutePaths.roommateSaved));
      },
    );
  }
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.city, required this.onSelected});

  final String city;
  final ValueChanged<String> onSelected;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomiziColors.white,
      builder: (context) => const _CitySearchSheet(),
    );
    if (picked != null && picked.trim().isNotEmpty) {
      onSelected(picked.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('roommate-location'),
      onTap: () => _open(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 16, color: HomiziColors.logoOrange),
          const SizedBox(width: 2),
          Text(
            city,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: HomiziColors.ink),
        ],
      ),
    );
  }
}

class _CitySearchSheet extends StatefulWidget {
  const _CitySearchSheet();

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final _city = TextEditingController();

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: PlaceAutocompleteField(
            controller: _city,
            fieldKey: const Key('roommate-city-search'),
            labelText: homiziText(context, 'City'),
            hintText: homiziText(context, 'Search a city'),
            includedPrimaryTypes: const ['locality'],
            nearbyLocalities: catalogCitySuggestions(),
            onSelected: (place) {
              final name = pickedCityName(place);
              if (name.isEmpty) {
                return;
              }
              Navigator.of(context).pop(name);
            },
          ),
        ),
      ),
    );
  }
}
