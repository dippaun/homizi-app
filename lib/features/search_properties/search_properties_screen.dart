import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/location.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/homizi_date_field.dart';
import 'package:homizi/core/widgets/saved_summary.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/explore_providers.dart';
import 'package:homizi/features/listings/domain/poster_kind.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/office/remember_office.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/profile/shared_answers.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/search_properties/best_matches_deck.dart';
import 'package:homizi/features/search_properties/search_choice_icons.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_persist.dart';
import 'package:homizi/features/search_properties/search_rank.dart';
import 'package:homizi/features/search_properties/search_steps.dart';
import 'package:homizi/features/search_properties/search_store.dart';
import 'package:homizi/ui/kit/kit.dart';

const _steps = searchStepTitles;

const _budgetPresets = <RangePreset>[
  RangePreset(label: '₹5k – ₹15k', start: 5000, end: 15000),
  RangePreset(label: '₹10k – ₹20k', start: 10000, end: 20000),
  RangePreset(label: '₹15k – ₹30k', start: 15000, end: 30000),
  RangePreset(label: '₹20k – ₹40k', start: 20000, end: 40000),
  RangePreset(label: '₹30k – ₹50k', start: 30000, end: 50000),
  RangePreset(label: '₹40k – ₹80k', start: 40000, end: 80000),
];

/// Search Properties at `/search/start`. The twelve sections from the spec.
class SearchPropertiesScreen extends ConsumerStatefulWidget {
  const SearchPropertiesScreen({super.key, this.initial, this.editing = false});

  /// A search already loaded by [SearchEntry]. Skips a second device read.
  final PropertySearch? initial;

  /// True only when the person tapped Edit. A saved search never opens here.
  final bool editing;

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
  var _holdWizard = false;
  var _expandLifestyle = false;

  /// Steps where Continue was pressed with questions missing. Their cards
  /// show what is still needed.
  final _checked = <int>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _draft = initial;
      _answered = {...SearchQuestion.all};
      _place.text = initial.placeQuery;
      return;
    }
    _holdWizard = !widget.editing;
    unawaited(_restore());
    unawaited(_warmOffice());
  }

  Future<void> _warmOffice() async {
    final repo = ref.read(officeRepositoryProvider);
    try {
      await repo.load();
    } on Object {
      return;
    }
    if (!mounted) {
      return;
    }
    final office = repo.primary;
    if (office == null || office.label.trim().isEmpty) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(useOffice: true);
    });
    ref.read(officeRevisionProvider.notifier).bump();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final saved = await ref.read(propertySearchStoreProvider).read();
    await ref.read(profileCreateStoreProvider).restoreDevice();
    final shared = searchWithSharedProfile(
      const PropertySearch(),
      ref.read(profileCreateStoreProvider).draft,
    );
    if (!mounted) {
      return;
    }
    if (saved != null && !widget.editing) {
      ref.read(shownPropertySearchProvider.notifier).replace(saved);
      ref.invalidate(savedPropertySearchProvider);
      final listings = ref.read(discoveryProvider).listings;
      ref
          .read(rankedHomesProvider.notifier)
          .replace(
            listings.isEmpty
                ? const <RankedHome>[]
                : rankHomes(listings: listings, search: saved),
          );
      if (!mounted) {
        return;
      }
      context.go(RoutePaths.searchMatches);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _holdWizard = false;
      if (saved != null) {
        _place.text = saved.placeQuery;
        _draft = searchWithSharedProfile(
          saved,
          ref.read(profileCreateStoreProvider).draft,
        );
        _answered = {...SearchQuestion.all};
      } else {
        _draft = shared;
        if (shared.placeQuery.trim().isNotEmpty) {
          _place.text = shared.placeQuery;
        }
      }
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

  Widget _lifestyleEditor() {
    return Column(
      children: [
        _savedOrEditor(
          label: 'Smoking',
          known: _draft.smoking != LifestyleChoice.noPreference,
          value: _draft.smoking.label,
          editor: _LifestyleRow(
            label: 'Smoking',
            values: LifestyleChoice.values,
            selected: _draft.smoking,
            text: (value) => value.label,
            onChanged: (value) => _editShared(_draft.copyWith(smoking: value)),
          ),
        ),
        _savedOrEditor(
          label: 'Drinking',
          known: _draft.drinking != LifestyleChoice.noPreference,
          value: _draft.drinking.label,
          editor: _LifestyleRow(
            label: 'Drinking',
            values: LifestyleChoice.values,
            selected: _draft.drinking,
            text: (value) => value.label,
            onChanged: (value) => _editShared(_draft.copyWith(drinking: value)),
          ),
        ),
        _savedOrEditor(
          label: 'Food',
          known: _draft.food != FoodChoice.noPreference,
          value: _draft.food.label,
          editor: _LifestyleRow(
            label: 'Food',
            values: FoodChoice.values,
            selected: _draft.food,
            text: (value) => value.label,
            onChanged: (value) => _editShared(_draft.copyWith(food: value)),
          ),
        ),
        _savedOrEditor(
          label: 'Cooking',
          known: _draft.cooking != CookingChoice.noPreference,
          value: _draft.cooking.label,
          editor: _LifestyleRow(
            label: 'Cooking',
            values: CookingChoice.values,
            selected: _draft.cooking,
            text: (value) => value.label,
            onChanged: (value) => _edit(_draft.copyWith(cooking: value)),
          ),
        ),
        _savedOrEditor(
          label: 'Cleaning',
          known: _draft.cleaning != CleaningChoice.noPreference,
          value: _draft.cleaning.label,
          editor: _LifestyleRow(
            label: 'Cleaning',
            values: CleaningChoice.values,
            selected: _draft.cleaning,
            text: (value) => value.label,
            onChanged: (value) => _edit(_draft.copyWith(cleaning: value)),
          ),
        ),
      ],
    );
  }

  Widget _savedOrEditor({
    required String label,
    required bool known,
    required String value,
    required Widget editor,
  }) {
    if (!known || _expandLifestyle) {
      return editor;
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('$label · $value'),
      trailing: const Icon(Icons.edit_outlined, color: HomiziColors.logoOrange),
      onTap: () => setState(() => _expandLifestyle = true),
    );
  }

  void _editShared(PropertySearch next) {
    _edit(next);
    final store = ref.read(profileCreateStoreProvider);
    final profile = store.draft.copyWith(
      smoking: profileChoiceForLifestyle(next.smoking),
      drinking: profileChoiceForLifestyle(next.drinking),
      food: profileChoiceForFood(next.food),
    );
    unawaited(() async {
      await store.save(profile);
      await publishSharedAnswers(ref, profile);
    }());
  }

  void _answer(String question, PropertySearch next) {
    setState(() {
      _draft = next;
      _answered = {..._answered, question};
    });
  }

  /// Defaults stay unselected on screen until the person picks one, so a
  /// filled radio always means an answer.
  T? _shown<T>(String question, T value) =>
      _answered.contains(question) ? value : null;

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
    final serverId = _draft.serverId;
    _place.clear();
    setState(() {
      _draft = const PropertySearch();
      _answered = <String>{};
      _checked.clear();
      _step = 0;
      _error = null;
    });
    ref.read(listingFilterProvider.notifier).reset();
    ref.read(shownPropertySearchProvider.notifier).replace(null);
    await ref.read(propertySearchStoreProvider).clear();
    final gateway = _exploreGateway();
    if (gateway != null && serverId != null && serverId.isNotEmpty) {
      try {
        await gateway.deleteSavedSearch(serverId);
      } on Object {
        // The device copy is already gone. The next open shows the wizard.
      }
    }
    ref.invalidate(savedPropertySearchProvider);
  }

  ExploreGateway? _exploreGateway() {
    try {
      return ref.read(exploreGatewayProvider);
    } on Object {
      return null;
    }
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
    final draft = await persistPropertySearch(
      store: ref.read(propertySearchStoreProvider),
      gateway: _exploreGateway(),
      draft: _draft.copyWith(placeQuery: _place.text.trim()),
    );
    ref.read(shownPropertySearchProvider.notifier).replace(draft);
    ref.invalidate(savedPropertySearchProvider);
    ref.read(listingFilterProvider.notifier).replace(draft.toListingFilters());
    final listings = ref.read(discoveryProvider).listings;
    ref
        .read(rankedHomesProvider.notifier)
        .replace(
          listings.isEmpty
              ? const <RankedHome>[]
              : rankHomes(listings: listings, search: draft),
        );
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
              selected: _shown(SearchQuestion.occupancy, _draft.occupancy),
              label: (value) => value.label,
              onChanged: (value) => _answer(
                SearchQuestion.occupancy,
                _draft.copyWith(occupancy: value),
              ),
            ),
          ),
          _Card(
            number: 2,
            title: 'Open to a shared space?',
            child: Wrap(
              spacing: 8,
              children: [
                for (final choice in const [true, false])
                  ChoiceChip(
                    key: Key(
                      choice
                          ? 'search-open-shared-yes'
                          : 'search-open-shared-no',
                    ),
                    label: Text(choice ? 'Yes, include shared rooms' : 'No'),
                    selected: _draft.openToShared == choice,
                    onSelected: (_) => setState(() {
                      _draft = _draft.copyWith(openToShared: choice);
                    }),
                  ),
              ],
            ),
          ),
          _Card(
            number: 3,
            title: 'Property Type',
            error: _errorFor(
              SearchQuestion.propertyKind,
              'Choose a property type.',
            ),
            child: _Radios<PropertyKindChoice>(
              values: PropertyKindChoice.values,
              selected: _shown(
                SearchQuestion.propertyKind,
                _draft.propertyKind,
              ),
              label: (value) => value.label,
              onChanged: (value) => _answer(
                SearchQuestion.propertyKind,
                _draft.copyWith(propertyKind: value),
              ),
            ),
          ),
          _Card(
            number: 4,
            title: 'Monthly Budget',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select your budget range',
                  style: TextStyle(color: HomiziColors.muted),
                ),
                const SizedBox(height: 8),
                RangeSliderField(
                  min: searchBudgetFloor,
                  max: searchBudgetCeiling,
                  step: 1000,
                  start: _draft.budgetMinInr,
                  end: _draft.budgetMaxInr,
                  format: formatInr,
                  presets: _budgetPresets,
                  sliderKey: const Key('search-budget-slider'),
                  valueKey: const Key('search-budget-value'),
                  onChanged: (start, end) => _edit(
                    _draft.copyWith(budgetMinInr: start, budgetMaxInr: end),
                  ),
                ),
                const SizedBox(height: 8),
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
                OptionGrid(
                  children: [
                    OptionTile(
                      key: const Key('search-office-toggle'),
                      label: 'My Office / Workplace',
                      icon: RealLifeIcons.office,
                      selected: _draft.useOffice,
                      onTap: () =>
                          _edit(_draft.copyWith(useOffice: !_draft.useOffice)),
                    ),
                    OptionTile(
                      key: const Key('search-area-toggle'),
                      label: 'Preferred Area / Locality',
                      icon: RealLifeIcons.locality,
                      selected: _draft.usePreferredArea,
                      onTap: () => _edit(
                        _draft.copyWith(
                          usePreferredArea: !_draft.usePreferredArea,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (ref.watch(officeRevisionProvider) >= 0 &&
                    ref.watch(officeRepositoryProvider).primary != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      key: const Key('search-saved-office'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.apartment_outlined,
                        color: HomiziColors.logoOrange,
                      ),
                      title: Text(
                        ref.watch(officeRepositoryProvider).primary!.label,
                      ),
                      subtitle: Text(
                        homiziText(
                          context,
                          'Office from your profile. Change it in Profile.',
                        ),
                      ),
                    ),
                  ),
                PlaceAutocompleteField(
                  fieldKey: const Key('search-area-field'),
                  controller: _place,
                  hintText: ref.watch(officeRepositoryProvider).primary == null
                      ? 'Enter office, company or area name'
                      : 'Preferred area, if you want one',
                  prefixIcon: const Icon(Icons.search),
                  biasPoint:
                      ref.watch(locationServiceProvider).lastKnownPoint == null
                      ? cityCentreFor(ref.watch(personalizationProvider).city)
                      : null,
                  onSelected: (place) {
                    if (_draft.useOffice &&
                        ref.read(officeRepositoryProvider).primary == null) {
                      unawaited(rememberWorkplace(ref, place));
                    }
                    _edit(
                      _draft.copyWith(
                        placeQuery: place.label,
                        placeLatitude: place.latitude,
                        placeLongitude: place.longitude,
                        clearPlacePoint: !place.hasCoordinates,
                        useOffice: _draft.useOffice,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _draft.hasPlacePoint
                      ? 'Homes are shown within ${_draft.distanceKm} km of this place.'
                      : 'Pick a suggestion. Typed text is not used as the place.',
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
                OptionGrid(
                  minTileWidth: 96,
                  maxColumns: 5,
                  children: [
                    for (final km in preferredDistanceKm)
                      OptionTile(
                        key: Key('search-distance-$km'),
                        label: '$km km',
                        icon: searchDistanceIcon(km),
                        selected: _draft.distanceKm == km,
                        onTap: () => _edit(_draft.copyWith(distanceKm: km)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Each home also shows metro, bus, hospitals and schools nearby.',
                  style: TextStyle(
                    color: HomiziColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                const _NearbyHints(),
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
              selected: _shown(SearchQuestion.possession, _draft.possession),
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
                  final picked = await pickHomiziDate(
                    context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initial:
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
                      : formatHomiziDay(_draft.possessionDate!),
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
              selected: _shown(SearchQuestion.gender, _draft.gender),
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
            child: _lifestyleEditor(),
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
              selected: _shown(SearchQuestion.furnishing, _draft.furnishing),
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
              selected: _shown(SearchQuestion.bathroom, _draft.bathroom),
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
            child: _draft.rules.isNotEmpty && !_expandLifestyle
                ? Wrap(
                    spacing: 8,
                    children: [
                      for (final rule in _draft.rules)
                        ActionChip(
                          label: Text(rule),
                          onPressed: () =>
                              setState(() => _expandLifestyle = true),
                        ),
                    ],
                  )
                : _Checks(
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
              selected: _shown(SearchQuestion.suitableFor, _draft.suitableFor),
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
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: HomiziColors.logoOrange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        searchSummaryIcon(label),
                        color: HomiziColors.logoOrange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: HomiziColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            value,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: HomiziColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      size: 18,
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
    if (_holdWizard) {
      return const Scaffold(
        key: Key('search-properties-screen'),
        backgroundColor: HomiziColors.white,
        body: PrefsSkeleton(),
      );
    }
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
            child: StepProgress(
              titles: _steps,
              index: _step,
              unlocked: unlocked,
              onSelected: _open,
              subtitle: _step == 0
                  ? 'Set your preferences to find the right home for you.'
                  : null,
              stepKey: (index) => Key('search-step-$index'),
              lockedKey: (index) => Key('search-step-lock-$index'),
            ),
          ),
          Expanded(
            child: PageBackground(
              variant: PageBackgroundVariant.soft,
              child: ListView(
                key: Key('search-step-body-$_step'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, _) =>
                        current ?? const SizedBox.shrink(),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Column(key: ValueKey(_step), children: _stepCards()),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: HomiziColors.line),
          Material(
            color: HomiziColors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                  Row(
                    children: [
                      if (_step > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('search-step-back'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HomiziColors.ink,
                              minimumSize: const Size.fromHeight(52),
                              side: const BorderSide(
                                color: HomiziColors.logoOrange,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => _open(_step - 1),
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w800,
                                color: HomiziColors.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 2,
                        child: last
                            ? FilledButton.icon(
                                key: const Key('search-find-matches'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: HomiziColors.accent,
                                  foregroundColor: HomiziColors.ink,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => unawaited(_find()),
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: HomiziColors.ink,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.travel_explore,
                                        color: HomiziColors.ink,
                                      ),
                                label: Text(
                                  _busy
                                      ? 'Finding homes'
                                      : 'Find My Best Matches',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontWeight: FontWeight.w800,
                                    color: HomiziColors.ink,
                                  ),
                                ),
                              )
                            : FilledButton(
                                key: const Key('search-continue'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: HomiziColors.accent,
                                  foregroundColor: HomiziColors.ink,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _continue,
                                child: Text(
                                  _step == searchConfirmStep - 1
                                      ? 'Continue to Confirm'
                                      : 'Continue to ${_steps[_step + 1]}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontWeight: FontWeight.w800,
                                    color: HomiziColors.ink,
                                  ),
                                ),
                              ),
                      ),
                    ],
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

/// Scores the ranked deck once per seeker or listing change. Dragging the
/// top card does not watch this, so [scoreMatch] stays out of the swipe frame.
final searchDeckHomesProvider = Provider<List<RankedHome>>((ref) {
  final homes = ref.watch(rankedHomesProvider);
  if (homes.isEmpty) {
    return const [];
  }
  final kinds = ref.watch(listingFilterProvider).posterKinds;
  final kept = [
    for (final home in homes)
      if (posterKindAllowed(listingPosterKind(home.listing), kinds)) home,
  ];
  if (kept.isEmpty) {
    return const [];
  }
  final score = ref.watch(listingScorerProvider);
  return rankedByMatch(kept, {
    for (final home in kept) home.listing.id: score(home.listing),
  });
});

class _SearchMatchesScreenState extends ConsumerState<SearchMatchesScreen> {
  var _preparing = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(rankedHomesProvider).isEmpty) {
      _preparing = true;
      unawaited(_prepare());
    }
  }

  /// Fills the swipe deck when Search opens a saved search directly.
  ///
  /// Uses the homes already in memory when the feed is warm. Otherwise one
  /// filtered search, not a full catalog reload, runs behind the skeleton.
  Future<void> _prepare() async {
    try {
      if (ref.read(rankedHomesProvider).isNotEmpty) {
        return;
      }
      final shown = ref.read(shownPropertySearchProvider);
      final search =
          shown ?? await ref.read(propertySearchStoreProvider).read();
      if (search == null || !mounted) {
        return;
      }
      if (shown == null) {
        ref.read(shownPropertySearchProvider.notifier).replace(search);
      }
      ref
          .read(listingFilterProvider.notifier)
          .replace(search.toListingFilters());
      var listings = ref.read(discoveryProvider).listings;
      if (listings.isEmpty) {
        try {
          listings = await ref
              .read(discoveryGatewayProvider)
              .searchListings(search.toListingFilters());
        } on Object {
          await ref.read(discoveryProvider.notifier).refresh();
          listings = ref.read(discoveryProvider).listings;
        }
      }
      if (!mounted) {
        return;
      }
      ref
          .read(rankedHomesProvider.notifier)
          .replace(rankHomes(listings: listings, search: search));
    } finally {
      if (mounted) {
        setState(() => _preparing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final homes = ref.watch(searchDeckHomesProvider);
    return BestMatchesDeck(homes: homes, loading: _preparing && homes.isEmpty);
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
    return FormSection(
      title: title,
      icon: searchSectionIcon(title),
      error: error,
      errorKey: Key('search-card-error-$number'),
      child: child,
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
  final T? selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return OptionGrid(
      children: [
        for (final value in values)
          OptionTile(
            key: Key('search-option-${label(value)}'),
            label: label(value),
            selected: selected == value,
            illustration: searchChoiceArt(
              label(value),
              selected: selected == value,
            ),
            onTap: () => onChanged(value),
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
    return OptionGrid(
      children: [
        for (final option in options)
          OptionTile(
            key: Key('search-check-$option'),
            label: option,
            selected: selected.contains(option),
            illustration: searchChoiceArt(
              option,
              selected: selected.contains(option),
            ),
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
        OptionTile(
          label: noneLabel,
          selected: none,
          illustration: searchChoiceArt(noneLabel, selected: none),
          onTap: () => onChanged({}),
        ),
      ],
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

  String _caption(T value) {
    if (text == null) {
      return '$value'.split('.').last;
    }
    return text!(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          OptionGrid(
            children: [
              for (final value in values)
                OptionTile(
                  label: _caption(value),
                  selected: selected == value,
                  illustration: searchChoiceArt(
                    _caption(value),
                    group: label,
                    selected: selected == value,
                  ),
                  onTap: () => onChanged(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NearbyHints extends StatelessWidget {
  const _NearbyHints();

  @override
  Widget build(BuildContext context) {
    const hints = <(IconData, String)>[
      (RealLifeIcons.metro, 'Metro'),
      (RealLifeIcons.bus, 'Bus'),
      (RealLifeIcons.hospital, 'Hospital'),
      (RealLifeIcons.school, 'School'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, name) in hints)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: HomiziColors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: HomiziColors.inkSoft),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
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
