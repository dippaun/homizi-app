import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roles/role_provider.dart';

const _knownCities = exploreCities;

/// Multi-step brief for a tenant or a roommate.
/// Progress, back, and next stay on screen. Save keeps the draft for later.
class RequirementFormScreen extends ConsumerStatefulWidget {
  const RequirementFormScreen({this.seekerKind, super.key});

  /// `tenant` or `roommate`. Null follows the saved brief, then the role.
  final String? seekerKind;

  @override
  ConsumerState<RequirementFormScreen> createState() =>
      _RequirementFormScreenState();
}

class _RequirementFormScreenState extends ConsumerState<RequirementFormScreen> {
  final _locality = TextEditingController();
  final _work = TextEditingController();
  final _commute = TextEditingController();
  final _about = TextEditingController();
  final _flatmate = TextEditingController();
  final _localities = <String>[];
  int _budgetMin = InrRangeScale.presetMin;
  int _budgetMax = InrRangeScale.presetMax;
  String? _id;
  String _city = 'Bengaluru';
  DateTime? _moveIn;
  int _occupancy = 1;
  String _furnishing = 'semi_furnished';
  String _kind = 'tenant';
  int _lease = 11;
  String _room = '2bhk';
  String _parking = 'either';
  String _floor = 'any';
  var _lift = false;
  String _pets = 'no_pets';
  String _food = 'veg';
  String _smoking = 'no';
  String _drinking = 'no';
  String _gender = 'any';
  String _occupancyPreference = 'just_me';
  String _profession = 'working';
  String _guests = 'occasional';
  final Set<String> _amenities = {};
  var _discoverable = true;
  String _sleep = 'flexible';
  int _cleanliness = 3;
  String _social = 'balanced';
  var _wfh = false;
  String _cooking = 'sometimes';
  final Set<String> _languages = {'Hindi', 'English'};
  final Set<String> _hobbies = {};
  List<String> _errors = const [];
  String? _note;
  var _loading = true;
  var _busy = false;
  var _step = 0;

  @override
  void initState() {
    super.initState();
    if (widget.seekerKind == 'roommate' || widget.seekerKind == 'tenant') {
      _kind = widget.seekerKind!;
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _locality.dispose();
    _work.dispose();
    _commute.dispose();
    _about.dispose();
    _flatmate.dispose();
    super.dispose();
  }

  List<String> get _steps {
    return [
      'place',
      'budget',
      'timing',
      'home',
      'building',
      'living',
      'people',
      'work',
      'guests',
      'amenities',
      'about',
      'discover',
      if (_kind == 'roommate') 'lifestyle',
      'review',
    ];
  }

  Future<void> _load() async {
    if (widget.seekerKind == null) {
      final role = ref.read(currentRoleProvider);
      if (role == HomiziRole.roommate) {
        _kind = 'roommate';
      }
    }
    try {
      final loaded = await ref
          .read(inventoryGatewayProvider)
          .loadLatestRequirement();
      if (!mounted) {
        return;
      }
      if (loaded != null) {
        _apply(loaded);
      }
    } on InventoryFailure catch (error) {
      _note = error.message;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _apply(RequirementDraft loaded) {
    _id = loaded.id;
    _city = loaded.city.isEmpty ? _city : loaded.city;
    _localities
      ..clear()
      ..addAll(loaded.localityList);
    _locality.clear();
    final budget = clampOrdered(
      start: loaded.budgetMinInr,
      end: loaded.budgetMaxInr,
      min: InrRangeScale.min,
      max: InrRangeScale.max,
      fallbackStart: InrRangeScale.presetMin,
      fallbackEnd: InrRangeScale.presetMax,
    );
    _budgetMin = budget.start;
    _budgetMax = budget.end;
    _moveIn = loaded.moveInDate;
    _occupancy = loaded.occupancy;
    _furnishing = loaded.furnishing;
    if (widget.seekerKind == null) {
      _kind = loaded.seekerKind;
    }
    _lease = loaded.leaseMonths;
    if (loaded.roomType.isNotEmpty) {
      _room = loaded.roomType;
    }
    if (loaded.parkingNeed.isNotEmpty) {
      _parking = loaded.parkingNeed;
    }
    if (loaded.preferredFloor.isNotEmpty) {
      _floor = loaded.preferredFloor;
    }
    _lift = loaded.liftNeeded;
    if (loaded.pets.isNotEmpty) {
      _pets = loaded.pets;
    }
    if (loaded.foodHabit.isNotEmpty) {
      _food = loaded.foodHabit;
    }
    if (loaded.smoking.isNotEmpty) {
      _smoking = loaded.smoking;
    }
    if (loaded.drinking.isNotEmpty) {
      _drinking = loaded.drinking;
    }
    if (loaded.genderPreference.isNotEmpty) {
      _gender = loaded.genderPreference;
    }
    if (loaded.occupancyPreference.isNotEmpty) {
      _occupancyPreference = loaded.occupancyPreference;
    }
    if (loaded.profession.isNotEmpty) {
      _profession = loaded.profession;
    }
    _work.text = loaded.workLocation;
    _commute.text = loaded.commute;
    _guests = loaded.guestsPolicy.isEmpty ? _guests : loaded.guestsPolicy;
    _amenities
      ..clear()
      ..addAll(loaded.amenities);
    _about.text = loaded.aboutMe;
    _discoverable = loaded.discoverable;
    if (loaded.sleepSchedule.isNotEmpty) {
      _sleep = loaded.sleepSchedule;
    }
    _cleanliness = loaded.cleanliness;
    if (loaded.socialStyle.isNotEmpty) {
      _social = loaded.socialStyle;
    }
    _wfh = loaded.workFromHome;
    if (loaded.cooking.isNotEmpty) {
      _cooking = loaded.cooking;
    }
    if (loaded.languages.isNotEmpty) {
      _languages
        ..clear()
        ..addAll(loaded.languages);
    }
    _hobbies
      ..clear()
      ..addAll(loaded.hobbies);
    _flatmate.text = loaded.flatmateNote;
    final steps = _steps;
    _step = loaded.wizardStep.clamp(0, steps.length - 1);
  }

  void _absorbLocality() {
    final next = _locality.text.trim();
    if (next.isEmpty || _localities.contains(next)) {
      return;
    }
    _localities.add(next);
    _locality.clear();
  }

  RequirementDraft _draft() {
    return RequirementDraft(
      id: _id,
      budgetMinInr: _budgetMin,
      budgetMaxInr: _budgetMax,
      city: _city,
      locality: _localities.isEmpty ? '' : _localities.first,
      localities: List<String>.from(_localities),
      moveInDate: _moveIn,
      occupancy: _occupancy,
      propertyType: propertyTypeForRoom(_room),
      furnishing: _furnishing,
      seekerKind: _kind,
      leaseMonths: _lease,
      roomType: _room,
      parkingNeed: _parking,
      preferredFloor: _floor,
      liftNeeded: _lift,
      pets: _pets,
      foodHabit: _food,
      smoking: _smoking,
      drinking: _drinking,
      genderPreference: _gender,
      occupancyPreference: _occupancyPreference,
      profession: _profession,
      workLocation: _work.text,
      commute: _commute.text,
      guestsPolicy: _guests,
      amenities: _amenities.toList(),
      aboutMe: _about.text,
      discoverable: _discoverable,
      sleepSchedule: _sleep,
      cleanliness: _cleanliness,
      socialStyle: _social,
      workFromHome: _wfh,
      cooking: _cooking,
      languages: _languages.toList(),
      hobbies: _hobbies.toList(),
      flatmateNote: _flatmate.text,
      wizardStep: _step,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: _moveIn ?? now,
    );
    if (picked != null) {
      setState(() => _moveIn = picked);
    }
  }

  void _continue() {
    setState(_absorbLocality);
    final draft = _draft();
    final issues = _stepIssues(draft);
    if (issues.isNotEmpty) {
      setState(() {
        _errors = issues;
        _note = null;
      });
      return;
    }
    setState(() {
      _errors = const [];
      _step = (_step + 1).clamp(0, _steps.length - 1);
    });
  }

  List<String> _stepIssues(RequirementDraft draft) {
    final all = draft.errors(today: DateTime.now());
    final id = _steps[_step];
    return switch (id) {
      'place' => [
        for (final issue in all)
          if (issue.startsWith('Choose a city') ||
              issue.startsWith('Add at least one locality'))
            issue,
      ],
      'budget' => [
        for (final issue in all)
          if (issue.contains('budget')) issue,
      ],
      'timing' => [
        for (final issue in all)
          if (issue.startsWith('Move-in') || issue.startsWith('Choose a lease'))
            issue,
      ],
      _ => const [],
    };
  }

  Future<void> _write({required bool publish}) async {
    setState(_absorbLocality);
    final draft = _draft();
    final errors = draft.errors(today: DateTime.now());
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _note = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _errors = const [];
    });
    try {
      final gateway = ref.read(inventoryGatewayProvider);
      final result = publish
          ? await gateway.publishRequirement(draft)
          : await gateway.saveRequirement(draft);
      if (!mounted) {
        return;
      }
      setState(() {
        _id = result.draft.id;
        _note = result.message;
        _busy = false;
      });
    } on InventoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _note = error.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: HomiziColors.white,
        body: Center(
          child: CircularProgressIndicator(key: Key('requirement-loading')),
        ),
      );
    }
    final steps = _steps;
    final id = steps[_step];
    final draft = _draft();
    final ready = draft.errors(today: DateTime.now()).isEmpty;
    final last = _step == steps.length - 1;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        title: Text(
          homiziText(
            context,
            _kind == 'roommate' ? 'Roommate brief' : 'What you need',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            homiziText(context, 'Step ${_step + 1} of ${steps.length}'),
            key: const Key('requirement-step-label'),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              key: const Key('requirement-progress'),
              minHeight: 8,
              value: (_step + 1) / steps.length,
              color: HomiziColors.accent,
              backgroundColor: HomiziColors.mist,
            ),
          ),
          const SizedBox(height: 24),
          _body(context, id),
        ],
      ),
      bottomNavigationBar: Material(
        color: HomiziColors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final error in _errors)
                Text(
                  homiziText(context, error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_note != null)
                Text(
                  homiziText(context, _note!),
                  key: const Key('requirement-note'),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      key: const Key('requirement-back'),
                      onPressed: () => setState(() {
                        _errors = const [];
                        _step -= 1;
                      }),
                      child: Text(homiziText(context, 'Back')),
                    ),
                  const Spacer(),
                  if (!last)
                    FilledButton(
                      key: const Key('requirement-continue'),
                      onPressed: _continue,
                      child: Text(homiziText(context, 'Next')),
                    ),
                  if (last) ...[
                    FilledButton(
                      key: const Key('requirement-save'),
                      onPressed: _busy
                          ? null
                          : () => unawaited(_write(publish: false)),
                      child: Text(homiziText(context, 'Save draft')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('requirement-publish'),
                      onPressed: _busy || !ready
                          ? null
                          : () => unawaited(_write(publish: true)),
                      child: Text(
                        homiziText(context, _busy ? 'Publishing…' : 'Publish'),
                      ),
                    ),
                  ],
                ],
              ),
              if (!last)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('requirement-save-draft'),
                    onPressed: _busy
                        ? null
                        : () => unawaited(_write(publish: false)),
                    child: Text(homiziText(context, 'Save and resume later')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, String id) {
    return switch (id) {
      'place' => _place(context),
      'budget' => _budget(context),
      'timing' => _timing(context),
      'home' => _home(context),
      'building' => _building(context),
      'living' => _living(context),
      'people' => _people(context),
      'work' => _workStep(context),
      'guests' => _choice(
        context,
        title: 'Guests',
        prompt: 'How often can people stay over?',
        options: requirementGuests,
        labelOf: requirementGuestLabel,
        selected: _guests,
        onSelected: (value) => setState(() => _guests = value),
      ),
      'amenities' => _amenitiesStep(context),
      'about' => _aboutStep(context),
      'discover' => _discover(context),
      'lifestyle' => _lifestyle(context),
      _ => _review(context),
    };
  }

  Widget _place(BuildContext context) {
    final cities = [
      ..._knownCities,
      if (!_knownCities.contains(_city) && _city.isNotEmpty) _city,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'City and localities'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'Add every locality you would actually live in. A street address is not collected.',
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('requirement-city'),
          initialValue: _city,
          decoration: InputDecoration(labelText: homiziText(context, 'City')),
          items: [
            for (final city in cities)
              DropdownMenuItem(
                value: city,
                child: Text(homiziText(context, city)),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _city = value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('requirement-locality'),
          controller: _locality,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Locality'),
            hintText: homiziText(context, 'Koramangala'),
          ),
          onSubmitted: (_) => setState(_absorbLocality),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('requirement-add-locality'),
          onPressed: () => setState(_absorbLocality),
          child: Text(homiziText(context, 'Add locality')),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in _localities)
              InputChip(
                label: Text(homiziText(context, name)),
                onDeleted: () => setState(() => _localities.remove(name)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _budget(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Monthly budget'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Rent you can pay, including a range.'),
        ),
        const SizedBox(height: 16),
        HomiziRangeField(
          label: 'Budget',
          min: InrRangeScale.min,
          max: InrRangeScale.max,
          step: InrRangeScale.step,
          start: _budgetMin,
          end: _budgetMax,
          formatValue: formatInr,
          minSemantics: 'Minimum budget (₹)',
          maxSemantics: 'Maximum budget (₹)',
          sliderKey: const Key('requirement-budget-slider'),
          valueKey: const Key('requirement-budget-value'),
          onChanged: (start, end) => setState(() {
            _budgetMin = start;
            _budgetMax = end;
          }),
        ),
      ],
    );
  }

  Widget _timing(BuildContext context) {
    final moveLabel = _moveIn == null
        ? 'Choose a move-in date'
        : '${_moveIn!.year}-${_moveIn!.month.toString().padLeft(2, '0')}-${_moveIn!.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'When you move'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          key: const Key('requirement-move-in'),
          onPressed: _pickDate,
          child: Text(homiziText(context, moveLabel)),
        ),
        const SizedBox(height: 20),
        Text(homiziText(context, 'Lease length')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final months in requirementLeaseMonths)
              ChoiceChip(
                key: Key('requirement-lease-$months'),
                label: Text(homiziText(context, '$months months')),
                selected: _lease == months,
                onSelected: (_) => setState(() => _lease = months),
              ),
          ],
        ),
      ],
    );
  }

  Widget _home(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _choice(
          context,
          title: 'Home',
          prompt: 'Private room, shared room, 1 RK, or a BHK.',
          options: requirementRoomTypes,
          labelOf: requirementRoomTypeLabel,
          selected: _room,
          onSelected: (value) => setState(() => _room = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('requirement-furnishing'),
          initialValue: _furnishing,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Furnishing'),
          ),
          items: [
            for (final type in requirementFurnishings)
              DropdownMenuItem(
                value: type,
                child: Text(
                  homiziText(context, requirementFurnishingLabel(type)),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _furnishing = value);
            }
          },
        ),
      ],
    );
  }

  Widget _building(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _choice(
          context,
          title: 'Building',
          prompt: 'Parking you need.',
          options: requirementParkingNeeds,
          labelOf: requirementParkingLabel,
          selected: _parking,
          onSelected: (value) => setState(() => _parking = value),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Preferred floor')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final floor in requirementFloors)
              ChoiceChip(
                label: Text(homiziText(context, requirementFloorLabel(floor))),
                selected: _floor == floor,
                onSelected: (_) => setState(() => _floor = floor),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('requirement-lift'),
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'Lift required')),
          value: _lift,
          onChanged: (value) => setState(() => _lift = value),
        ),
      ],
    );
  }

  Widget _living(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _choice(
          context,
          title: 'How you live',
          prompt: 'Pets',
          options: requirementPets,
          labelOf: requirementPetLabel,
          selected: _pets,
          onSelected: (value) => setState(() => _pets = value),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Food')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementFoodHabits,
          labelOf: requirementFoodLabel,
          selected: _food,
          onSelected: (value) => setState(() => _food = value),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Smoking')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementHabits,
          labelOf: requirementHabitLabel,
          selected: _smoking,
          onSelected: (value) => setState(() => _smoking = value),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Drinking')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementHabits,
          labelOf: requirementHabitLabel,
          selected: _drinking,
          onSelected: (value) => setState(() => _drinking = value),
        ),
      ],
    );
  }

  Widget _people(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _choice(
          context,
          title: 'Who you live with',
          prompt: 'Gender preference for flatmates. This is not used in the match score.',
          options: requirementGenders,
          labelOf: requirementGenderLabel,
          selected: _gender,
          onSelected: (value) => setState(() => _gender = value),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Occupancy')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementOccupancyPreferences,
          labelOf: requirementOccupancyPreferenceLabel,
          selected: _occupancyPreference,
          onSelected: (value) => setState(() => _occupancyPreference = value),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'People in the home')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: homiziText(context, 'Fewer people'),
                onPressed: _occupancy > 1
                    ? () => setState(() => _occupancy -= 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text(homiziText(context, '$_occupancy')),
              IconButton(
                tooltip: homiziText(context, 'More people'),
                onPressed: _occupancy < 20
                    ? () => setState(() => _occupancy += 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _workStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _choice(
          context,
          title: 'Work and commute',
          prompt: 'Student or working.',
          options: requirementProfessions,
          labelOf: requirementProfessionLabel,
          selected: _profession,
          onSelected: (value) => setState(() => _profession = value),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('requirement-work'),
          controller: _work,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Work or college location'),
            hintText: homiziText(context, 'Indiranagar'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('requirement-commute'),
          controller: _commute,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Commute you can do'),
            hintText: homiziText(context, 'Metro, under 40 minutes'),
          ),
        ),
      ],
    );
  }

  Widget _amenitiesStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Amenities'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(homiziText(context, 'Pick what the home should have.')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in requirementAmenities)
              FilterChip(
                key: Key('requirement-amenity-$item'),
                label: Text(homiziText(context, requirementAmenityLabel(item))),
                selected: _amenities.contains(item),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _amenities.add(item);
                  } else {
                    _amenities.remove(item);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _aboutStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'About you'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'A short note hosts can read. Leave out your phone number and email.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('requirement-about'),
          controller: _about,
          minLines: 4,
          maxLines: 6,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: homiziText(context, 'About me'),
          ),
        ),
      ],
    );
  }

  Widget _discover(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Who can find you'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'Your phone stays hidden until you both match and you choose to share it.',
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const Key('requirement-discoverable'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            homiziText(
              context,
              'Let verified hosts and brokers contact me',
            ),
          ),
          value: _discoverable,
          onChanged: (value) => setState(() => _discoverable = value),
        ),
      ],
    );
  }

  Widget _lifestyle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Flatmate fit'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Sleep schedule')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementSleep,
          labelOf: requirementSleepLabel,
          selected: _sleep,
          onSelected: (value) => setState(() => _sleep = value),
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Cleanliness $_cleanliness of 5'),
          key: const Key('requirement-cleanliness'),
        ),
        Slider(
          value: _cleanliness.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$_cleanliness',
          onChanged: (value) => setState(() => _cleanliness = value.round()),
        ),
        Text(homiziText(context, 'Home style')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementSocial,
          labelOf: requirementSocialLabel,
          selected: _social,
          onSelected: (value) => setState(() => _social = value),
        ),
        SwitchListTile(
          key: const Key('requirement-wfh'),
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'I work from home')),
          value: _wfh,
          onChanged: (value) => setState(() => _wfh = value),
        ),
        Text(homiziText(context, 'Cooking')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementCooking,
          labelOf: requirementCookingLabel,
          selected: _cooking,
          onSelected: (value) => setState(() => _cooking = value),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Languages')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in requirementLanguages)
              FilterChip(
                label: Text(homiziText(context, item)),
                selected: _languages.contains(item),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _languages.add(item);
                  } else {
                    _languages.remove(item);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Hobbies')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in requirementHobbies)
              FilterChip(
                label: Text(homiziText(context, item)),
                selected: _hobbies.contains(item),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _hobbies.add(item);
                  } else {
                    _hobbies.remove(item);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('requirement-flatmate-note'),
          controller: _flatmate,
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: homiziText(
              context,
              "What I'm looking for in a flatmate",
            ),
          ),
        ),
      ],
    );
  }

  Widget _review(BuildContext context) {
    final draft = _draft();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Review'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          homiziText(
            context,
            '${draft.city} · ${draft.localityList.join(', ')}',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            '${formatInr(draft.budgetMinInr ?? 0)} – ${formatInr(draft.budgetMaxInr ?? 0)} · ${requirementRoomTypeLabel(draft.roomType)} · ${requirementFurnishingLabel(draft.furnishing)}',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            '${requirementFoodLabel(draft.foodHabit)} · ${requirementProfessionLabel(draft.profession)} · ${draft.discoverable ? 'Hosts and brokers can see this brief' : 'Hidden from hosts and brokers'}',
          ),
        ),
        if (draft.aboutMe.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(homiziText(context, draft.aboutMe.trim())),
        ],
        const SizedBox(height: 12),
        Text(
          homiziText(
            context,
            'Saving does not publish. Publish keeps the requirement on this device until a server accepts it.',
          ),
        ),
      ],
    );
  }

  Widget _choice(
    BuildContext context, {
    required String title,
    required String prompt,
    required List<String> options,
    required String Function(String value) labelOf,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, title),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(homiziText(context, prompt)),
        const SizedBox(height: 12),
        _chips(
          context,
          options: options,
          labelOf: labelOf,
          selected: selected,
          onSelected: onSelected,
        ),
      ],
    );
  }

  Widget _chips(
    BuildContext context, {
    required List<String> options,
    required String Function(String value) labelOf,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(homiziText(context, labelOf(option))),
            selected: selected == option,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}
