import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roles/role_switch_bar.dart';
import 'package:homizi/features/roommates/finder/finder_catalog.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/finder_widgets.dart';
import 'package:homizi/features/roommates/flatmate_shortcuts.dart';
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
  var _showAll = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) {
        return;
      }
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
      builder: (context) => RoommateFilterSheet(initial: current),
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

  void _maybe(FinderPerson person) {
    ref.read(finderProvider.notifier).markMaybe(person.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          homiziText(
            context,
            'Saved as Maybe. This is not a match, and contact stays hidden.',
          ),
        ),
      ),
    );
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
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: RoleSwitchBar(),
        ),
        Expanded(
          child: ListView(
            key: const Key('roommate-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
              const SizedBox(height: 12),
              _tabs(),
              const SizedBox(height: 12),
              if (_tab == 0) _find(snapshot),
              if (_tab == 1) _matches(snapshot),
              if (_tab == 2) _requirements(snapshot),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabs() {
    return Row(
      children: [
        _tabButton(0, 'Find Roommate', 'roommate-tab-find'),
        const SizedBox(width: 6),
        _tabButton(1, 'My Roommate Matches', 'roommate-tab-matches'),
        const SizedBox(width: 6),
        _tabButton(2, 'My Requirements', 'roommate-tab-requirements'),
      ],
    );
  }

  Widget _tabButton(int index, String label, String keyName) {
    final selected = _tab == index;
    return Expanded(
      child: Material(
        color: selected ? HomiziColors.logoOrange : HomiziColors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          key: Key(keyName),
          borderRadius: BorderRadius.circular(24),
          onTap: () => setState(() => _tab = index),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? HomiziColors.logoOrange : HomiziColors.line,
              ),
            ),
            child: Text(
              homiziText(context, label),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _find(FinderSnapshot snapshot) {
    final deck = snapshot.deck;
    final current = snapshot.current;
    final score = current == null
        ? null
        : scoreFinderPerson(snapshot.requirements, current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _compatibility(score?.percent)),
            IconButton(
              key: const Key('roommate-filters'),
              tooltip: homiziText(context, 'Filter Roommates'),
              onPressed: _filters,
              icon: const Icon(Icons.tune, color: HomiziColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (current == null)
          _caughtUp(snapshot)
        else ...[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: RoommateStackCard(
              key: ValueKey(current.id),
              person: current,
              index: deck.indexWhere((person) => person.id == current.id),
              total: deck.length,
              onOpen: () => _open(current),
            ),
          ),
          const SizedBox(height: 12),
          RoommateActionBar(
            onSkip: () => _skip(current),
            onMaybe: () => _maybe(current),
            onInterested: () => _interested(current),
          ),
        ],
        const SizedBox(height: 20),
        _topMatches(deck),
        const SizedBox(height: 16),
        const _ProTip(),
      ],
    );
  }

  Widget _compatibility(int? percent) {
    return Row(
      children: [
        CompatibilityRing(percent: percent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(context, 'Your Compatibility'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                homiziText(context, finderHeadline(percent)),
                style: TextStyle(
                  color: percent == null
                      ? HomiziColors.muted
                      : HomiziColors.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                homiziText(context, 'Based on your preferences'),
                style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _caughtUp(FinderSnapshot snapshot) {
    final filtered = snapshot.people.where(
      (person) => finderPersonMatches(
        person: person,
        filters: snapshot.filters,
        city: snapshot.city,
      ),
    );
    if (filtered.isEmpty) {
      return const EmptyState(
        title: 'No roommates match',
        message: 'Try a wider budget or another city.',
      );
    }
    return EmptyState(
      title: 'You are caught up',
      message: 'Likes wait for a mutual match. Contact stays hidden.',
      actionLabel: 'Review again',
      onAction: () => ref.read(finderProvider.notifier).resetDeck(),
    );
  }

  Widget _topMatches(List<FinderPerson> deck) {
    final requirements = ref.watch(finderProvider).requirements;
    final shown = _showAll ? deck : deck.take(4).toList();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                homiziText(context, 'Top Matches (${deck.length})'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              key: const Key('roommate-see-all'),
              onPressed: deck.length <= 4
                  ? null
                  : () => setState(() => _showAll = !_showAll),
              child: Text(
                homiziText(context, _showAll ? 'Show less' : 'See All'),
                style: const TextStyle(color: HomiziColors.ink),
              ),
            ),
          ],
        ),
        for (final person in shown)
          _MatchRow(
            person: person,
            percent: scoreFinderPerson(requirements, person).percent,
            onOpen: () => _open(person),
          ),
      ],
    );
  }

  Widget _matches(FinderSnapshot snapshot) {
    final rooms = Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: const Key('flatmate-rooms'),
        onPressed: () => context.push(RoutePaths.flatmateRooms),
        child: Text(
          homiziText(context, 'Shared rooms'),
          style: const TextStyle(color: HomiziColors.ink),
        ),
      ),
    );
    if (snapshot.matches.isEmpty && snapshot.savedMaybe.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          rooms,
          const EmptyState(
            title: 'No roommate matches yet',
            message:
                'When you are both interested, the match shows up here. Contact stays hidden until you each share it.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        rooms,
        if (snapshot.matches.isNotEmpty) ...[
          Text(
            homiziText(context, 'Mutual and sent interest'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final person in snapshot.matches)
            _MatchRow(
              person: person,
              percent: scoreFinderPerson(snapshot.requirements, person).percent,
              onOpen: () {
                if (person.seeker.likesYou) {
                  context.push(RoutePaths.roommateMatch(person.id));
                  return;
                }
                _open(person);
              },
            ),
        ],
        if (snapshot.savedMaybe.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Maybe'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final person in snapshot.savedMaybe)
            _MatchRow(
              person: person,
              percent: scoreFinderPerson(snapshot.requirements, person).percent,
              onOpen: () => _open(person),
            ),
        ],
      ],
    );
  }

  Widget _requirements(FinderSnapshot snapshot) {
    return _RequirementsForm(
      initial: snapshot.requirements,
      onSave: (requirements) async {
        ref.read(finderProvider.notifier).saveRequirements(requirements);
        try {
          await ref
              .read(roommateProfileGatewayProvider)
              .save(
                RequirementDraft(
                  seekerKind: 'roommate',
                  city: requirements.city,
                  locality: requirements.locality,
                  localities: [requirements.locality],
                  budgetMinInr: requirements.budgetMin,
                  budgetMaxInr: requirements.budgetMax,
                  genderPreference: requirements.genderPreference,
                  occupancyPreference: 'shared',
                  foodHabits: requirements.diet == 'any'
                      ? const []
                      : [requirements.diet],
                  smoking: [
                    switch (requirements.smoking) {
                      'never' => 'no',
                      'sometimes' => 'occasionally',
                      'regularly' => 'yes',
                      _ => 'no',
                    },
                  ],
                  pets: requirements.petFriendly
                      ? const ['pets_ok']
                      : const ['no_pets'],
                  moveInDate: requirements.moveIn,
                  flatmateNote:
                      'Looking for a ${requirements.lookingFor} in ${requirements.city}.',
                ),
              );
        } on Object {
          // The deck still uses the copy kept on this device.
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

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('roommate-location'),
      initialValue: city,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final name in finderCities)
          PopupMenuItem(value: name, child: Text(name)),
      ],
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

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.person,
    required this.percent,
    required this.onOpen,
  });

  final FinderPerson person;
  final int? percent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final photo = person.seeker.photoRef;
    return ListTile(
      key: Key('roommate-row-${person.id}'),
      contentPadding: EdgeInsets.zero,
      onTap: onOpen,
      leading: CircleAvatar(
        backgroundImage: photo == null ? null : AssetImage(photo),
        backgroundColor: HomiziColors.soft,
      ),
      title: Text(
        person.name,
        style: const TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        percent == null
            ? 'Score unavailable · ${finderBudgetCompact(person.traits)}'
            : '$percent% Match · ${finderBudgetCompact(person.traits)}',
        style: TextStyle(
          color: percent == null ? HomiziColors.muted : HomiziColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(
        Icons.favorite_border,
        color: HomiziColors.logoOrange,
      ),
    );
  }
}

class _ProTip extends StatelessWidget {
  const _ProTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('roommate-pro-tip'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.home_outlined, color: HomiziColors.ink),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Tip',
                  style: TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Complete your preferences to get more accurate matches.',
                  style: TextStyle(color: HomiziColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementsForm extends StatefulWidget {
  const _RequirementsForm({required this.initial, required this.onSave});

  final FinderRequirements initial;
  final Future<void> Function(FinderRequirements requirements) onSave;

  @override
  State<_RequirementsForm> createState() => _RequirementsFormState();
}

class _RequirementsFormState extends State<_RequirementsForm> {
  late FinderRequirements _draft;
  late final TextEditingController _locality;
  late final TextEditingController _lookingFor;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _locality = TextEditingController(text: widget.initial.locality);
    _lookingFor = TextEditingController(text: widget.initial.lookingFor);
  }

  @override
  void dispose() {
    _locality.dispose();
    _lookingFor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'My Requirements'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('roommate-requirement-city'),
          initialValue: _draft.city,
          decoration: InputDecoration(labelText: homiziText(context, 'City')),
          items: [
            for (final city in finderCities)
              DropdownMenuItem(value: city, child: Text(city)),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _draft = _draft.copyWith(city: value));
          },
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('roommate-requirement-locality'),
          decoration: InputDecoration(
            labelText: homiziText(context, 'Preferred location'),
          ),
          controller: _locality,
          onChanged: (value) => _draft = _draft.copyWith(locality: value),
        ),
        const SizedBox(height: 8),
        Text(
          '${homiziText(context, 'Budget (per person)')}  ${formatInr(_draft.budgetMin)} – ${formatInr(_draft.budgetMax)}',
          style: const TextStyle(color: HomiziColors.ink),
        ),
        RangeSlider(
          min: 5000,
          max: 30000,
          divisions: 25,
          values: RangeValues(
            _draft.budgetMin.toDouble(),
            _draft.budgetMax.toDouble(),
          ),
          activeColor: HomiziColors.logoOrange,
          onChanged: (value) {
            setState(() {
              _draft = _draft.copyWith(
                budgetMin: value.start.round(),
                budgetMax: value.end.round(),
              );
            });
          },
        ),
        DropdownButtonFormField<String>(
          key: const Key('roommate-requirement-gender'),
          initialValue: _draft.genderPreference,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Gender preference'),
          ),
          items: const [
            DropdownMenuItem(value: 'any', child: Text('Any')),
            DropdownMenuItem(value: 'women', child: Text('Female')),
            DropdownMenuItem(value: 'men', child: Text('Male')),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _draft = _draft.copyWith(genderPreference: value));
          },
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('roommate-requirement-looking'),
          decoration: InputDecoration(
            labelText: homiziText(context, 'Looking for'),
          ),
          controller: _lookingFor,
          onChanged: (value) => _draft = _draft.copyWith(lookingFor: value),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('flatmate-edit-profile'),
            onPressed: () => context.push(flatmateProfilePath),
            child: Text(
              homiziText(context, 'Edit full roommate brief'),
              style: const TextStyle(color: HomiziColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('roommate-requirements-save'),
          style: FilledButton.styleFrom(
            backgroundColor: HomiziColors.logoOrange,
            foregroundColor: HomiziColors.ink,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await widget.onSave(_draft);
                  if (mounted) {
                    setState(() => _busy = false);
                  }
                },
          child: Text(
            homiziText(context, _busy ? 'Saving…' : 'Save requirements'),
          ),
        ),
      ],
    );
  }
}
