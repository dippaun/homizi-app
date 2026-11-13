import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/location/location.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_rank.dart';
import 'package:homizi/features/search_properties/search_store.dart';

const _steps = <String>[
  'Property Requirements',
  'Location & Connectivity',
  'Lifestyle Preferences',
  'Amenities & Rules',
  'Confirm & Search',
];

/// Search Properties at `/search/start`. The twelve sections from the spec.
class SearchPropertiesScreen extends ConsumerStatefulWidget {
  const SearchPropertiesScreen({super.key});

  @override
  ConsumerState<SearchPropertiesScreen> createState() =>
      _SearchPropertiesScreenState();
}

class _SearchPropertiesScreenState
    extends ConsumerState<SearchPropertiesScreen> {
  final _scroll = ScrollController();
  final _place = TextEditingController();
  final _sectionKeys = List<GlobalKey>.generate(5, (_) => GlobalKey());
  PropertySearch _draft = const PropertySearch();
  var _step = 0;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final saved = await ref.read(propertySearchStoreProvider).read();
    if (!mounted || saved == null) {
      return;
    }
    _place.text = saved.placeQuery;
    setState(() => _draft = saved);
  }

  void _edit(PropertySearch next) => setState(() => _draft = next);

  Future<void> _jump(int step) async {
    setState(() => _step = step);
    final context = _sectionKeys[step].currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _clear() async {
    _place.clear();
    setState(() => _draft = const PropertySearch());
    ref.read(listingFilterProvider.notifier).reset();
    await ref.read(propertySearchStoreProvider).write(const PropertySearch());
    ref.invalidate(savedPropertySearchProvider);
  }

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = _draft.copyWith(placeQuery: _place.text.trim());
    await ref.read(propertySearchStoreProvider).write(draft);
    ref.invalidate(savedPropertySearchProvider);
    ref.read(listingFilterProvider.notifier).replace(draft.toListingFilters());
    final discovery = ref.read(discoveryProvider);
    if (discovery.listings.isEmpty) {
      await ref.read(discoveryProvider.notifier).refresh();
    }
    if (!mounted) {
      return;
    }
    final state = ref.read(discoveryProvider);
    if (state.error != null && state.listings.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Homes could not be loaded. Try again.';
      });
      return;
    }
    final ranked = rankHomes(listings: state.listings, search: draft);
    ref.read(rankedHomesProvider.notifier).replace(ranked);
    setState(() {
      _draft = draft;
      _busy = false;
    });
    if (!mounted) {
      return;
    }
    await context.push(RoutePaths.searchMatches);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('search-properties-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        leading: const HomiziBackButton(),
        title: const Text('Search Properties'),
        actions: [
          TextButton(
            key: const Key('search-clear'),
            onPressed: () => unawaited(_clear()),
            child: const Text('Clear'),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: HomiziColors.white,
            child: SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                itemCount: _steps.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = _step == index;
                  return InkWell(
                    key: Key('search-step-$index'),
                    onTap: () => unawaited(_jump(index)),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 148,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected
                            ? HomiziColors.accentWash
                            : HomiziColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? HomiziColors.accent
                              : HomiziColors.line,
                        ),
                      ),
                      child: Text(
                        '${index + 1}. ${_steps[index]}',
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? HomiziColors.ink
                              : HomiziColors.muted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text(
                  key: _sectionKeys[0],
                  'Set your preferences to find the right home for you.',
                  style: const TextStyle(color: HomiziColors.inkSoft),
                ),
                const SizedBox(height: 12),
                _Card(
                  number: 1,
                  title: 'Occupancy Required',
                  child: _Radios<OccupancyChoice>(
                    values: OccupancyChoice.values,
                    selected: _draft.occupancy,
                    label: (value) => value.label,
                    onChanged: (value) =>
                        _edit(_draft.copyWith(occupancy: value)),
                  ),
                ),
                _Card(
                  number: 2,
                  title: 'Property Type',
                  child: _Radios<PropertyKindChoice>(
                    values: PropertyKindChoice.values,
                    selected: _draft.propertyKind,
                    label: (value) => value.label,
                    onChanged: (value) =>
                        _edit(_draft.copyWith(propertyKind: value)),
                  ),
                ),
                _Card(
                  number: 3,
                  title: 'Monthly Budget',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select your budget range',
                        style: TextStyle(color: HomiziColors.muted),
                      ),
                      Text(
                        '${formatInr(_draft.budgetMinInr)} – ${formatInr(_draft.budgetMaxInr)}',
                        key: const Key('search-budget-value'),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: HomiziColors.ink,
                        ),
                      ),
                      RangeSlider(
                        key: const Key('search-budget-slider'),
                        values: RangeValues(
                          _draft.budgetMinInr.toDouble(),
                          _draft.budgetMaxInr.toDouble(),
                        ),
                        min: searchBudgetFloor.toDouble(),
                        max: searchBudgetCeiling.toDouble(),
                        divisions:
                            (searchBudgetCeiling - searchBudgetFloor) ~/ 1000,
                        labels: RangeLabels(
                          formatInr(_draft.budgetMinInr),
                          formatInr(_draft.budgetMaxInr),
                        ),
                        onChanged: (values) {
                          var start = values.start.round();
                          var end = values.end.round();
                          if (start > end) {
                            final swap = start;
                            start = end;
                            end = swap;
                          }
                          _edit(
                            _draft.copyWith(
                              budgetMinInr: start,
                              budgetMaxInr: end,
                            ),
                          );
                        },
                      ),
                      Text(
                        'e.g. ${formatInr(5000)} – ${formatInr(15000)} per month',
                        style: const TextStyle(
                          color: HomiziColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _Card(
                  number: 4,
                  title: 'Preferred Location & Workplace',
                  anchor: _sectionKeys[1],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            key: const Key('search-office-toggle'),
                            label: const Text('My Office / Workplace'),
                            selected: _draft.useOffice,
                            onSelected: (value) =>
                                _edit(_draft.copyWith(useOffice: value)),
                          ),
                          FilterChip(
                            key: const Key('search-area-toggle'),
                            label: const Text('Preferred Area / Locality'),
                            selected: _draft.usePreferredArea,
                            onSelected: (value) =>
                                _edit(_draft.copyWith(usePreferredArea: value)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('search-area-field'),
                        controller: _place,
                        decoration: const InputDecoration(
                          hintText: 'Enter office, company or area name',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) =>
                            _edit(_draft.copyWith(placeQuery: value)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "We'll show properties with distance from your office when a maps key is set.",
                        style: TextStyle(
                          color: HomiziColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Preferred distance from office/work',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final km in preferredDistanceKm)
                            ChoiceChip(
                              key: Key('search-distance-$km'),
                              label: Text('$km km'),
                              selected: _draft.distanceKm == km,
                              onSelected: (_) =>
                                  _edit(_draft.copyWith(distanceKm: km)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _Card(
                  number: 5,
                  title: 'Possession Required From',
                  child: _Radios<PossessionChoice>(
                    values: PossessionChoice.values,
                    selected: _draft.possession,
                    label: (value) => value.label,
                    onChanged: (value) =>
                        _edit(_draft.copyWith(possession: value)),
                  ),
                ),
                if (_draft.possession == PossessionChoice.specificDate)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton(
                      key: const Key('search-possession-date'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDate:
                              _draft.possessionDate ??
                              DateTime.now().add(const Duration(days: 14)),
                        );
                        if (picked != null) {
                          _edit(_draft.copyWith(possessionDate: picked));
                        }
                      },
                      child: Text(
                        _draft.possessionDate == null
                            ? 'Choose a date'
                            : '${_draft.possessionDate!.day}/${_draft.possessionDate!.month}/${_draft.possessionDate!.year}',
                      ),
                    ),
                  ),
                _Card(
                  number: 6,
                  title: 'Flatmate / Roommate Gender Preference',
                  anchor: _sectionKeys[2],
                  child: _Radios<FlatmateGender>(
                    values: FlatmateGender.values,
                    selected: _draft.gender,
                    label: (value) => value.label,
                    onChanged: (value) => _edit(_draft.copyWith(gender: value)),
                  ),
                ),
                _Card(
                  number: 7,
                  title: 'Lifestyle Preference',
                  child: Column(
                    children: [
                      _LifestyleRow(
                        label: 'Smoking',
                        values: LifestyleChoice.values,
                        selected: _draft.smoking,
                        text: (value) => value.label,
                        onChanged: (value) =>
                            _edit(_draft.copyWith(smoking: value)),
                      ),
                      _LifestyleRow(
                        label: 'Drinking',
                        values: LifestyleChoice.values,
                        selected: _draft.drinking,
                        text: (value) => value.label,
                        onChanged: (value) =>
                            _edit(_draft.copyWith(drinking: value)),
                      ),
                      _LifestyleRow(
                        label: 'Food',
                        values: FoodChoice.values,
                        selected: _draft.food,
                        text: (value) => value.label,
                        onChanged: (value) =>
                            _edit(_draft.copyWith(food: value)),
                      ),
                      _LifestyleRow(
                        label: 'Cooking',
                        values: CookingChoice.values,
                        selected: _draft.cooking,
                        text: (value) => value.label,
                        onChanged: (value) =>
                            _edit(_draft.copyWith(cooking: value)),
                      ),
                      _LifestyleRow(
                        label: 'Cleaning',
                        values: CleaningChoice.values,
                        selected: _draft.cleaning,
                        text: (value) => value.label,
                        onChanged: (value) =>
                            _edit(_draft.copyWith(cleaning: value)),
                      ),
                    ],
                  ),
                ),
                _Card(
                  number: 8,
                  title: 'Furnishing Preference',
                  anchor: _sectionKeys[3],
                  child: _Radios<FurnishingChoice>(
                    values: FurnishingChoice.values,
                    selected: _draft.furnishing,
                    label: (value) => value.label,
                    onChanged: (value) =>
                        _edit(_draft.copyWith(furnishing: value)),
                  ),
                ),
                _Card(
                  number: 9,
                  title: 'Bathroom Preference',
                  child: _Radios<BathroomChoice>(
                    values: BathroomChoice.values,
                    selected: _draft.bathroom,
                    label: (value) => value.label,
                    onChanged: (value) =>
                        _edit(_draft.copyWith(bathroom: value)),
                  ),
                ),
                _Card(
                  number: 10,
                  title: 'Essential Amenities',
                  child: _Checks(
                    options: searchAmenities,
                    selected: _draft.amenities,
                    noneLabel: 'No Preference',
                    onChanged: (next) =>
                        _edit(_draft.copyWith(amenities: next)),
                  ),
                ),
                _Card(
                  number: 11,
                  title: 'Property Rules & Restrictions',
                  child: _Checks(
                    options: searchRules,
                    selected: _draft.rules,
                    noneLabel: 'No Preference',
                    onChanged: (next) => _edit(_draft.copyWith(rules: next)),
                  ),
                ),
                _Card(
                  number: 12,
                  title: 'Suitable For',
                  child: _Radios<SuitableFor>(
                    values: SuitableFor.values,
                    selected: _draft.suitableFor,
                    label: (value) => value.label,
                    onChanged: (value) =>
                        _edit(_draft.copyWith(suitableFor: value)),
                  ),
                ),
                SizedBox(key: _sectionKeys[4], height: 4),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Promise('Personalized property recommendations'),
                    _Promise('Distance & travel time from your workplace'),
                    _Promise('Matches as per your lifestyle and budget'),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: HomiziColors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      key: const Key('search-error'),
                      style: const TextStyle(color: HomiziColors.error),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    key: const Key('search-find-matches'),
                    onPressed: _busy ? null : () => unawaited(_find()),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.travel_explore),
                    label: Text(
                      _busy ? 'Finding homes' : 'Find My Best Matches',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchMatchesScreen extends ConsumerStatefulWidget {
  const SearchMatchesScreen({super.key});

  @override
  ConsumerState<SearchMatchesScreen> createState() =>
      _SearchMatchesScreenState();
}

class _SearchMatchesScreenState extends ConsumerState<SearchMatchesScreen> {
  var _loadingDistances = false;

  @override
  void initState() {
    super.initState();
    unawaited(_fillDistances());
  }

  Future<void> _fillDistances() async {
    final service = ref.read(locationServiceProvider);
    if (!service.mapsEnabled) {
      return;
    }
    final office = ref.read(officeRepositoryProvider).primary;
    if (office == null) {
      return;
    }
    setState(() => _loadingDistances = true);
    final homes = ref.read(rankedHomesProvider);
    for (final home in homes.take(8)) {
      final estimate = await service.commute(
        origin: office.endpoint,
        destination: PlaceEndpoint(
          label: '${home.listing.locality}, ${home.listing.city}',
          latitude: home.listing.approxLatitude,
          longitude: home.listing.approxLongitude,
        ),
        mode: office.transport,
      );
      ref
          .read(rankedHomesProvider.notifier)
          .update(home.listing.id, estimate.label);
    }
    if (mounted) {
      setState(() => _loadingDistances = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homes = ref.watch(rankedHomesProvider);
    final maps = ref.watch(locationServiceProvider).mapsEnabled;
    return Scaffold(
      key: const Key('search-matches-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: const Text('Your best matches'),
      ),
      body: homes.isEmpty
          ? EmptyState(
              title: 'No homes in this search',
              message:
                  'None of the published homes match these filters. Widen the budget or clear a rule.',
              actionLabel: 'Edit search',
              onAction: () => context.pop(),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      Text(
                        'Search saved. ${homes.length} homes match the filters you set.',
                        key: const Key('search-saved-count'),
                        style: const TextStyle(color: HomiziColors.inkSoft),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        maps
                            ? (_loadingDistances
                                  ? 'Checking commute…'
                                  : 'Commute is shown only when Google Routes returns it.')
                            : distanceUnavailableLabel,
                        key: const Key('search-distance-note'),
                      ),
                      const SizedBox(height: 12),
                      for (final home in homes)
                        Card(
                          key: Key('search-home-${home.listing.id}'),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: HomiziColors.line),
                          ),
                          child: ListTile(
                            title: Text(home.listing.title),
                            subtitle: Text(
                              '${home.listing.locality}, ${home.listing.city}\n${home.distanceLabel}',
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${formatInr(home.listing.rentInr)}/mo',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: HomiziColors.ink,
                                  ),
                                ),
                                if (home.percent != null)
                                  Text(
                                    '${home.percent}% match',
                                    style: const TextStyle(
                                      color: HomiziColors.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () => context.push(
                              RoutePaths.listing(home.listing.id),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton(
                    key: const Key('search-open-swipe'),
                    onPressed: () => context.push(RoutePaths.matchSwipe),
                    child: const Text('Open matches'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.number,
    required this.title,
    required this.child,
    this.anchor,
  });

  final int number;
  final String title;
  final Widget child;
  final Key? anchor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: anchor,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: HomiziColors.accent,
                foregroundColor: HomiziColors.ink,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800,
                    color: HomiziColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Radios<T> extends StatelessWidget {
  const _Radios({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final value in values)
          InkWell(
            key: Key('search-option-${label(value)}'),
            onTap: () => onChanged(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    selected == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected == value
                        ? HomiziColors.logoOrange
                        : HomiziColors.muted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label(value))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Checks extends StatelessWidget {
  const _Checks({
    required this.options,
    required this.selected,
    required this.noneLabel,
    required this.onChanged,
  });

  final List<String> options;
  final Set<String> selected;
  final String noneLabel;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final none = selected.isEmpty;
    return Column(
      children: [
        for (final option in options)
          _CheckRow(
            rowKey: Key('search-check-$option'),
            label: option,
            checked: selected.contains(option),
            onTap: () {
              final next = {...selected};
              if (next.contains(option)) {
                next.remove(option);
              } else {
                next.add(option);
              }
              onChanged(next);
            },
          ),
        _CheckRow(label: noneLabel, checked: none, onTap: () => onChanged({})),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
    this.rowKey,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              color: checked ? HomiziColors.logoOrange : HomiziColors.muted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _LifestyleRow<T> extends StatelessWidget {
  const _LifestyleRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.text,
  });

  final String label;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T value)? text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(
                    text == null ? '$value'.split('.').last : text!(value),
                  ),
                  selected: selected == value,
                  onSelected: (_) => onChanged(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.check, size: 16, color: HomiziColors.success),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: HomiziColors.successWash,
      side: BorderSide.none,
    );
  }
}
