import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/location/location.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_rank.dart';
import 'package:homizi/features/search_properties/search_steps.dart';
import 'package:homizi/features/search_properties/search_store.dart';
import 'package:homizi/features/session/session_controller.dart';

const _steps = searchStepTitles;

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
  PropertySearch _draft = const PropertySearch();
  Set<String> _answered = <String>{};
  var _step = 0;
  var _busy = false;

  /// Steps where Continue was pressed with questions missing. Their cards
  /// show what is still needed.
  final _checked = <int>{};
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
    // A saved search already answered every question, so its tabs open.
    setState(() {
      _draft = saved;
      _answered = {...SearchQuestion.all};
    });
  }

  bool get _hasOffice => ref.read(officeRepositoryProvider).primary != null;

  List<String> _missing(int step) => searchStepMissing(
    step,
    draft: _draft,
    answered: _answered,
    hasSavedOffice: _hasOffice,
  );

  int get _unlocked => searchUnlockedStep(
    draft: _draft,
    answered: _answered,
    hasSavedOffice: _hasOffice,
  );

  void _edit(PropertySearch next) => setState(() => _draft = next);

  void _answer(String question, PropertySearch next) {
    setState(() {
      _draft = next;
      _answered = {..._answered, question};
    });
  }

  String? _errorFor(String question, String message) {
    if (!_checked.contains(_step) || _answered.contains(question)) {
      return null;
    }
    return message;
  }

  String? _locationError() {
    if (!_checked.contains(1)) {
      return null;
    }
    final missing = _missing(1);
    const text = 'Enter your office, company or preferred area.';
    return missing.contains(text) ? text : null;
  }

  void _open(int step) {
    if (step > _unlocked) {
      return;
    }
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  void _continue() {
    final missing = _missing(_step);
    if (missing.isNotEmpty) {
      setState(() {
        _checked.add(_step);
        _error = missing.length == 1
            ? missing.first
            : 'Answer ${missing.length} questions to continue: ${missing.join(' ')}';
      });
      return;
    }
    _open(_step + 1);
  }

  Future<void> _clear() async {
    _place.clear();
    setState(() {
      _draft = const PropertySearch();
      _answered = <String>{};
      _checked.clear();
      _step = 0;
      _error = null;
    });
    ref.read(listingFilterProvider.notifier).reset();
    await ref.read(propertySearchStoreProvider).write(const PropertySearch());
    ref.invalidate(savedPropertySearchProvider);
  }

  Future<void> _find() async {
    final blocked = _unlocked;
    if (blocked < searchConfirmStep) {
      setState(() {
        _checked.add(blocked);
        _step = blocked;
        _error = _missing(blocked).first;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = _draft.copyWith(placeQuery: _place.text.trim());
    await ref.read(propertySearchStoreProvider).write(draft);
    ref.invalidate(savedPropertySearchProvider);
    ref.read(listingFilterProvider.notifier).replace(draft.toListingFilters());
    final discovery = ref.read(discoveryProvider);
    if (discovery.listings.isEmpty || discovery.error != null) {
      await ref.read(discoveryProvider.notifier).refresh();
    }
    if (!mounted) {
      return;
    }
    final state = ref.read(discoveryProvider);
    if (state.error != null && state.listings.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Homes could not be loaded. ${state.error} Try again.';
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

  List<Widget> _stepCards() {
    switch (_step) {
      case 0:
        return [
          _Card(
            number: 1,
            title: 'Occupancy Required',
            error: _errorFor(
              SearchQuestion.occupancy,
              'Choose the occupancy you need.',
            ),
            child: _Radios<OccupancyChoice>(
              values: OccupancyChoice.values,
              selected: _draft.occupancy,
              label: (value) => value.label,
              onChanged: (value) => _answer(
                SearchQuestion.occupancy,
                _draft.copyWith(occupancy: value),
              ),
            ),
          ),
          _Card(
            number: 2,
            title: 'Property Type',
            error: _errorFor(
              SearchQuestion.propertyKind,
              'Choose a property type.',
            ),
            child: _Radios<PropertyKindChoice>(
              values: PropertyKindChoice.values,
              selected: _draft.propertyKind,
              label: (value) => value.label,
              onChanged: (value) => _answer(
                SearchQuestion.propertyKind,
                _draft.copyWith(propertyKind: value),
              ),
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
                  divisions: (searchBudgetCeiling - searchBudgetFloor) ~/ 1000,
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
                      _draft.copyWith(budgetMinInr: start, budgetMaxInr: end),
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
        ];
      case 1:
        return [
          _Card(
            number: 4,
            title: 'Preferred Location & Workplace',
            error: _locationError(),
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
                PlaceAutocompleteField(
                  fieldKey: const Key('search-area-field'),
                  controller: _place,
                  hintText: 'Enter office, company or area name',
                  prefixIcon: const Icon(Icons.search),
                  biasPoint:
                      ref.watch(locationServiceProvider).lastKnownPoint == null
                      ? cityCentreFor(ref.watch(personalizationProvider).city)
                      : null,
                  onChanged: (value) => _edit(
                    _draft.copyWith(placeQuery: value, clearPlacePoint: true),
                  ),
                  onSelected: (place) => _edit(
                    _draft.copyWith(
                      placeQuery: place.label,
                      placeLatitude: place.latitude,
                      placeLongitude: place.longitude,
                      clearPlacePoint: !place.hasCoordinates,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _draft.hasPlacePoint
                      ? 'Homes are shown within ${_draft.distanceKm} km of this place.'
                      : 'Pick a suggestion to filter homes by distance. Typed text matches the locality.',
                  key: const Key('search-area-note'),
                  style: const TextStyle(
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
            error: _errorFor(
              SearchQuestion.possession,
              'Choose when you need the home.',
            ),
            child: _Radios<PossessionChoice>(
              values: PossessionChoice.values,
              selected: _draft.possession,
              label: (value) => value.label,
              onChanged: (value) => _answer(
                SearchQuestion.possession,
                _draft.copyWith(possession: value),
              ),
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
                    lastDate: DateTime.now().add(const Duration(days: 365)),
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
        ];
      case 2:
        return [
          _Card(
            number: 6,
            title: 'Flatmate / Roommate Gender Preference',
            error: _errorFor(
              SearchQuestion.gender,
              'Choose a flatmate gender preference.',
            ),
            child: _Radios<FlatmateGender>(
              values: FlatmateGender.values,
              selected: _draft.gender,
              label: (value) => value.label,
              onChanged: (value) => _answer(
                SearchQuestion.gender,
                _draft.copyWith(gender: value),
              ),
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
                  onChanged: (value) => _edit(_draft.copyWith(smoking: value)),
                ),
                _LifestyleRow(
                  label: 'Drinking',
                  values: LifestyleChoice.values,
                  selected: _draft.drinking,
                  text: (value) => value.label,
                  onChanged: (value) => _edit(_draft.copyWith(drinking: value)),
                ),
                _LifestyleRow(
                  label: 'Food',
                  values: FoodChoice.values,
                  selected: _draft.food,
                  text: (value) => value.label,
                  onChanged: (value) => _edit(_draft.copyWith(food: value)),
                ),
                _LifestyleRow(
                  label: 'Cooking',
                  values: CookingChoice.values,
                  selected: _draft.cooking,
                  text: (value) => value.label,
                  onChanged: (value) => _edit(_draft.copyWith(cooking: value)),
                ),
                _LifestyleRow(
                  label: 'Cleaning',
                  values: CleaningChoice.values,
                  selected: _draft.cleaning,
                  text: (value) => value.label,
                  onChanged: (value) => _edit(_draft.copyWith(cleaning: value)),
                ),
              ],
            ),
          ),
        ];
      case 3:
        return [
          _Card(
            number: 8,
            title: 'Furnishing Preference',
            error: _errorFor(
              SearchQuestion.furnishing,
              'Choose a furnishing preference.',
            ),
            child: _Radios<FurnishingChoice>(
              values: FurnishingChoice.values,
              selected: _draft.furnishing,
              label: (value) => value.label,
              onChanged: (value) => _answer(
                SearchQuestion.furnishing,
                _draft.copyWith(furnishing: value),
              ),
            ),
          ),
          _Card(
            number: 9,
            title: 'Bathroom Preference',
            error: _errorFor(
              SearchQuestion.bathroom,
              'Choose a bathroom preference.',
            ),
            child: _Radios<BathroomChoice>(
              values: BathroomChoice.values,
              selected: _draft.bathroom,
              label: (value) => value.label,
              onChanged: (value) => _answer(
                SearchQuestion.bathroom,
                _draft.copyWith(bathroom: value),
              ),
            ),
          ),
          _Card(
            number: 10,
            title: 'Essential Amenities',
            child: _Checks(
              options: searchAmenities,
              selected: _draft.amenities,
              noneLabel: 'No Preference',
              onChanged: (next) => _edit(_draft.copyWith(amenities: next)),
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
            error: _errorFor(
              SearchQuestion.suitableFor,
              'Choose who the home is for.',
            ),
            child: _Radios<SuitableFor>(
              values: SuitableFor.values,
              selected: _draft.suitableFor,
              label: (value) => value.label,
              onChanged: (value) => _answer(
                SearchQuestion.suitableFor,
                _draft.copyWith(suitableFor: value),
              ),
            ),
          ),
        ];
      default:
        return [_confirmCard()];
    }
  }

  Widget _confirmCard() {
    String yesNo(bool value) => value ? 'Yes' : 'No';
    final place = _place.text.trim().isNotEmpty
        ? _place.text.trim()
        : (_draft.useOffice && _hasOffice ? 'My saved office' : '—');
    final rows = <(int, String, String)>[
      (0, 'Occupancy', _draft.occupancy.label),
      (0, 'Property type', _draft.propertyKind.label),
      (
        0,
        'Budget',
        '${formatInr(_draft.budgetMinInr)} – ${formatInr(_draft.budgetMaxInr)}',
      ),
      (1, 'Location', place),
      (1, 'Distance', '${_draft.distanceKm} km'),
      (1, 'Possession', _draft.possession.label),
      (2, 'Flatmate gender', _draft.gender.label),
      (2, 'Food', _draft.food.label),
      (3, 'Furnishing', _draft.furnishing.label),
      (3, 'Bathroom', _draft.bathroom.label),
      (
        3,
        'Amenities',
        _draft.amenities.isEmpty
            ? 'No Preference'
            : _draft.amenities.join(', '),
      ),
      (
        3,
        'Rules',
        _draft.rules.isEmpty ? 'No Preference' : _draft.rules.join(', '),
      ),
      (3, 'Suitable for', _draft.suitableFor.label),
      (3, 'Office commute shown', yesNo(_draft.useOffice)),
    ];
    return _Card(
      number: 5,
      title: 'Confirm your requirements',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (step, label, value) in rows)
            InkWell(
              key: Key('search-confirm-$label'),
              onTap: () => _open(step),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        label,
                        style: const TextStyle(color: HomiziColors.muted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: HomiziColors.ink,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: HomiziColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the saved office changes, since it can satisfy step 2.
    ref.watch(officeRepositoryProvider);
    final unlocked = _unlocked;
    final last = _step == searchConfirmStep;
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
                  final locked = index > unlocked;
                  final done = !locked && index < unlocked && !selected;
                  return Semantics(
                    button: true,
                    enabled: !locked,
                    selected: selected,
                    label: locked ? 'Locked' : null,
                    child: InkWell(
                      key: Key('search-step-$index'),
                      onTap: locked ? null : () => _open(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 148,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected
                              ? HomiziColors.accentWash
                              : (locked
                                    ? HomiziColors.soft
                                    : HomiziColors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? HomiziColors.accent
                                : HomiziColors.line,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${index + 1}. ${_steps[index]}',
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? HomiziColors.ink
                                      : (locked
                                            ? HomiziColors.muted.withValues(
                                                alpha: 0.6,
                                              )
                                            : HomiziColors.inkSoft),
                                ),
                              ),
                            ),
                            if (locked)
                              Icon(
                                Icons.lock_outline,
                                key: Key('search-step-lock-$index'),
                                size: 14,
                                color: HomiziColors.muted,
                              )
                            else if (done)
                              Icon(
                                Icons.check_circle,
                                key: Key('search-step-done-$index'),
                                size: 14,
                                color: HomiziColors.success,
                              ),
                          ],
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
              key: Key('search-step-body-$_step'),
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text(
                  _step == 0
                      ? 'Set your preferences to find the right home for you.'
                      : 'Step ${_step + 1} of ${_steps.length}: ${_steps[_step]}',
                  style: const TextStyle(color: HomiziColors.inkSoft),
                ),
                const SizedBox(height: 12),
                ..._stepCards(),
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
                  if (last)
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
                    )
                  else
                    FilledButton(
                      key: const Key('search-continue'),
                      onPressed: _continue,
                      child: Text(
                        _step == searchConfirmStep - 1
                            ? 'Continue to Confirm'
                            : 'Continue to ${_steps[_step + 1]}',
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
    final matches = ref.watch(listingMatchesProvider);
    // Rows show, and sort by, the shared scorer's match: the same percent
    // as the listing each row opens.
    final homes = rankedByMatch(ref.watch(rankedHomesProvider), matches);
    final maps = ref.watch(locationServiceProvider).mapsEnabled;
    final demo = ref.watch(forceDemoModeProvider);
    final guest =
        !demo && ref.watch(sessionProvider.select((s) => s.userId)) == null;
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
                      if (guest || demo) ...[
                        const SizedBox(height: 4),
                        Text(
                          demo
                              ? 'Test account: these are sample homes, not live listings.'
                              : 'These are sample homes. Sign in to see live listings and send interest.',
                          key: const Key('search-guest-note'),
                          style: const TextStyle(color: HomiziColors.muted),
                        ),
                      ],
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
                                if (_percent(matches, home) case final pct?)
                                  Text(
                                    '$pct% match',
                                    key: Key(
                                      'search-home-match-${home.listing.id}',
                                    ),
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
    this.error,
  });

  final int number;
  final String title;
  final Widget child;

  /// Shown under the title in red when a required answer is missing.
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error == null ? HomiziColors.line : HomiziColors.error,
        ),
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
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              key: Key('search-card-error-$number'),
              style: const TextStyle(color: HomiziColors.error, fontSize: 12),
            ),
          ],
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

/// The row shows the same match as the listing it opens.
int? _percent(Map<String, ListingMatch> matches, RankedHome home) {
  final match = matches[home.listing.id] ?? home.match;
  return match.showBadge ? match.score : null;
}
