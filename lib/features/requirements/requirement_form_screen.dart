import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/roommates/flatmate_return.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/shell/min_touch.dart';

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
  final List<String> _furnishings = ['semi_furnished'];
  String _kind = 'tenant';
  int _lease = 11;
  final List<String> _rooms = ['2bhk'];
  final List<String> _parking = ['either'];
  final List<String> _floors = ['any'];
  var _lift = false;
  final List<String> _pets = ['no_pets'];
  final List<String> _foods = ['veg'];
  final List<String> _smoking = ['no'];
  final List<String> _drinking = ['no'];
  String _gender = 'any';
  String _occupancyPreference = 'just_me';
  final List<String> _professions = ['working'];
  final List<String> _guests = ['occasional'];
  final Set<String> _amenities = {};
  var _discoverable = true;
  final List<String> _sleeps = ['flexible'];
  int _cleanliness = 3;
  final List<String> _socials = ['balanced'];
  var _wfh = false;
  final List<String> _cooking = ['sometimes'];
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
    if (_kind == 'roommate') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(flatmateReturnProvider.notifier).clear();
      });
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
    _replace(_furnishings, loaded.furnishings);
    if (widget.seekerKind == null) {
      _kind = loaded.seekerKind;
    }
    _lease = loaded.leaseMonths;
    _replace(_rooms, loaded.roomTypes);
    _replace(_parking, loaded.parkingNeeds);
    _replace(_floors, loaded.preferredFloors);
    _lift = loaded.liftNeeded;
    _replace(_pets, loaded.pets);
    _replace(_foods, loaded.foodHabits);
    _replace(_smoking, loaded.smoking);
    _replace(_drinking, loaded.drinking);
    if (loaded.genderPreference.isNotEmpty) {
      _gender = loaded.genderPreference;
    }
    if (loaded.occupancyPreference.isNotEmpty) {
      _occupancyPreference = loaded.occupancyPreference;
    }
    _replace(_professions, loaded.professions);
    _work.text = loaded.workLocation;
    _commute.text = loaded.commute;
    _replace(_guests, loaded.guestsPolicies);
    _amenities
      ..clear()
      ..addAll(loaded.amenities);
    _about.text = loaded.aboutMe;
    _discoverable = loaded.discoverable;
    _replace(_sleeps, loaded.sleepSchedules);
    _cleanliness = loaded.cleanliness;
    _replace(_socials, loaded.socialStyles);
    _wfh = loaded.workFromHome;
    _replace(_cooking, loaded.cooking);
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

  void _replace(List<String> target, List<String> values) {
    target
      ..clear()
      ..addAll(values);
  }

  void _toggle(List<String> target, String value, List<String> options) {
    final next = toggleRequirementChoice(
      selected: target,
      value: value,
      options: options,
    );
    _replace(target, next);
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
      propertyType: _rooms.isEmpty
          ? 'apartment'
          : propertyTypeForRoom(_rooms.first),
      furnishings: List<String>.from(_furnishings),
      seekerKind: _kind,
      leaseMonths: _lease,
      roomTypes: List<String>.from(_rooms),
      parkingNeeds: List<String>.from(_parking),
      preferredFloors: List<String>.from(_floors),
      liftNeeded: _lift,
      pets: List<String>.from(_pets),
      foodHabits: List<String>.from(_foods),
      smoking: List<String>.from(_smoking),
      drinking: List<String>.from(_drinking),
      genderPreference: _gender,
      occupancyPreference: _occupancyPreference,
      professions: List<String>.from(_professions),
      workLocation: _work.text,
      commute: _commute.text,
      guestsPolicies: List<String>.from(_guests),
      amenities: _amenities.toList(),
      aboutMe: _about.text,
      discoverable: _discoverable,
      sleepSchedules: List<String>.from(_sleeps),
      cleanliness: _cleanliness,
      socialStyles: List<String>.from(_socials),
      workFromHome: _wfh,
      cooking: List<String>.from(_cooking),
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
    if (issues.isNotEmpty && !demoModeOn(ref)) {
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
    if (publish && !ref.read(ownVerificationProvider).isVerified) {
      await guardVerifiedAction(
        context,
        ref,
        action: () => _write(publish: true),
      );
      return;
    }
    setState(_absorbLocality);
    final draft = _draft();
    final errors = draft.errors(today: DateTime.now());
    final demo = demoModeOn(ref);
    if (errors.isNotEmpty && !(demo && publish)) {
      setState(() {
        _errors = errors;
        _note = null;
      });
      return;
    }
    if (errors.isNotEmpty) {
      if (!mounted) {
        return;
      }
      openDemoSuccess(
        context,
        title: 'Brief published',
        detail: 'The brief is saved for this demo.',
      );
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
      if (_kind == 'roommate') {
        try {
          await ref.read(roommateProfileGatewayProvider).save(result.draft);
        } on RoommateFailure catch (error) {
          if (!mounted) {
            return;
          }
          if (publish && demo) {
            openDemoSuccess(
              context,
              title: 'Brief published',
              detail: 'The brief is saved for this demo.',
            );
            return;
          }
          setState(() {
            _note = '${result.message} ${error.message}';
          });
          return;
        }
        if (!mounted) {
          return;
        }
        if (publish && demo) {
          openDemoSuccess(
            context,
            title: 'Brief published',
            detail: 'The brief is saved for this demo.',
          );
          return;
        }
        if (publish && GoRouter.maybeOf(context) != null) {
          context.go(RoutePaths.roommates);
        }
      }
      if (publish && demo) {
        openDemoSuccess(
          context,
          title: 'Brief published',
          detail: 'The brief is saved for this demo.',
        );
      }
    } on InventoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      if (demo && publish) {
        setState(() => _busy = false);
        openDemoSuccess(
          context,
          title: 'Brief published',
          detail: 'The brief is saved for this demo.',
        );
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
    final demo = ref.watch(appConfigProvider).demoSkipLogin;
    final ready = draft.errors(today: DateTime.now()).isEmpty || demo;
    final last = _step == steps.length - 1;
    final otherErrors = [
      for (final error in _errors)
        if (!_errorOnCurrentStep(error)) error,
    ];
    return MinTouchScope(
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: HomiziBackButton(
            key: _kind == 'roommate'
                ? const Key('flatmate-profile-back')
                : null,
            onPressed: () {
              if (_step > 0) {
                setState(() {
                  _errors = const [];
                  _step -= 1;
                });
                return;
              }
              ref.read(flatmateReturnProvider.notifier).clear();
              if (_kind == 'roommate') {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.roommates);
                }
                return;
              }
              HomiziBackButton.leave(context);
            },
          ),
          title: Text(
            homiziText(
              context,
              _kind == 'roommate' ? 'Roommate brief' : 'What you need',
            ),
          ),
          actions: [
            if (_kind == 'tenant')
              IconButton(
                key: const Key('tenant-brief-home'),
                tooltip: homiziText(context, 'Tenant home'),
                onPressed: () {
                  final router = GoRouter.maybeOf(context);
                  if (router == null) {
                    return;
                  }
                  router.go(RoutePaths.home);
                },
                icon: const Icon(Icons.home_outlined),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              homiziText(context, 'Step ${_step + 1} of ${steps.length}'),
              key: const Key('requirement-step-label'),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: homiziText(
                context,
                'Step ${_step + 1} of ${steps.length}',
              ),
              value:
                  '${(((_step + 1) / steps.length) * 100).round()} percent complete',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  key: const Key('requirement-progress'),
                  minHeight: 8,
                  value: (_step + 1) / steps.length,
                  color: HomiziColors.accent,
                  backgroundColor: HomiziColors.mist,
                ),
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
                if (_errors.isNotEmpty)
                  LiveLabel(
                    key: const Key('requirement-errors'),
                    message: _errors
                        .map((error) => homiziText(context, error))
                        .join(' '),
                  ),
                for (final error in otherErrors)
                  LiveNotice(
                    message: homiziText(context, error),
                    isError: true,
                  ),
                if (_note != null)
                  LiveNotice(
                    key: const Key('requirement-note'),
                    message: homiziText(context, _note!),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
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
                          homiziText(
                            context,
                            _busy ? 'Publishing…' : 'Publish',
                          ),
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
      ),
    );
  }

  bool _errorOnCurrentStep(String error) {
    final id = _steps[_step];
    if (error.startsWith('Choose a city') ||
        error.startsWith('Add at least one locality')) {
      return id == 'place';
    }
    if (error.toLowerCase().contains('budget')) {
      return id == 'budget';
    }
    if (error.startsWith('Move-in') || error.startsWith('Choose a lease')) {
      return id == 'timing';
    }
    return false;
  }

  String? _issue(bool Function(String error) test) {
    for (final error in _errors) {
      if (test(error)) {
        return error;
      }
    }
    return null;
  }

  String? _shownIssue(bool Function(String error) test) {
    final issue = _issue(test);
    if (issue == null || !_errorOnCurrentStep(issue)) {
      return null;
    }
    return homiziText(context, issue);
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
        onToggled: (value) =>
            setState(() => _toggle(_guests, value, requirementGuests)),
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
          decoration: InputDecoration(
            labelText: homiziText(context, 'City'),
            errorText: _shownIssue(
              (error) => error.startsWith('Choose a city'),
            ),
          ),
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
            errorText: _shownIssue(
              (error) => error.startsWith('Add at least one locality'),
            ),
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
                deleteButtonTooltipMessage: homiziText(context, 'Remove $name'),
                onDeleted: () => setState(() => _localities.remove(name)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _budget(BuildContext context) {
    final budgetError = _shownIssue(
      (error) => error.toLowerCase().contains('budget'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Monthly budget'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(homiziText(context, 'Rent you can pay, including a range.')),
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
        if (budgetError != null) ...[
          const SizedBox(height: 8),
          Text(
            budgetError,
            key: const Key('requirement-budget-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _timing(BuildContext context) {
    final moveLabel = _moveIn == null
        ? 'Choose a move-in date'
        : '${_moveIn!.year}-${_moveIn!.month.toString().padLeft(2, '0')}-${_moveIn!.day.toString().padLeft(2, '0')}';
    final moveError = _shownIssue((error) => error.startsWith('Move-in'));
    final leaseError = _shownIssue(
      (error) => error.startsWith('Choose a lease'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'When you move'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton(
                key: const Key('requirement-move-in'),
                onPressed: _pickDate,
                child: Text(homiziText(context, moveLabel)),
              ),
              if (moveError != null)
                Text(
                  moveError,
                  key: const Key('requirement-move-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(homiziText(context, 'Lease length')),
        const SizedBox(height: 8),
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final months in requirementLeaseMonths)
                    ChoiceChip(
                      key: Key('requirement-lease-$months'),
                      label: Text(homiziText(context, '$months months')),
                      selected: _lease == months,
                      showCheckmark: true,
                      onSelected: (_) => setState(() => _lease = months),
                    ),
                ],
              ),
              if (leaseError != null)
                Text(
                  leaseError,
                  key: const Key('requirement-lease-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
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
          selected: _rooms,
          onToggled: (value) =>
              setState(() => _toggle(_rooms, value, requirementRoomTypes)),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Furnishing')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementFurnishings,
          labelOf: requirementFurnishingLabel,
          selected: _furnishings,
          onToggled: (value) => setState(
            () => _toggle(_furnishings, value, requirementFurnishings),
          ),
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
          onToggled: (value) =>
              setState(() => _toggle(_parking, value, requirementParkingNeeds)),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Preferred floor')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementFloors,
          labelOf: requirementFloorLabel,
          selected: _floors,
          onToggled: (value) =>
              setState(() => _toggle(_floors, value, requirementFloors)),
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
          onToggled: (value) =>
              setState(() => _toggle(_pets, value, requirementPets)),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Food')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementFoodHabits,
          labelOf: requirementFoodLabel,
          selected: _foods,
          onToggled: (value) =>
              setState(() => _toggle(_foods, value, requirementFoodHabits)),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Smoking')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementHabits,
          labelOf: requirementHabitLabel,
          selected: _smoking,
          onToggled: (value) =>
              setState(() => _toggle(_smoking, value, requirementHabits)),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Drinking')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementHabits,
          labelOf: requirementHabitLabel,
          selected: _drinking,
          onToggled: (value) =>
              setState(() => _toggle(_drinking, value, requirementHabits)),
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
          prompt:
              'Gender preference for flatmates. This is not used in the match score.',
          options: requirementGenders,
          labelOf: requirementGenderLabel,
          selected: [_gender],
          multi: false,
          onToggled: (value) => setState(() => _gender = value),
        ),
        const SizedBox(height: 16),
        Text(homiziText(context, 'Occupancy')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementOccupancyPreferences,
          labelOf: requirementOccupancyPreferenceLabel,
          selected: [_occupancyPreference],
          multi: false,
          onToggled: (value) => setState(() => _occupancyPreference = value),
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
          selected: _professions,
          onToggled: (value) => setState(
            () => _toggle(_professions, value, requirementProfessions),
          ),
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
            homiziText(context, 'Let verified hosts and brokers contact me'),
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
          selected: _sleeps,
          onToggled: (value) =>
              setState(() => _toggle(_sleeps, value, requirementSleep)),
        ),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Cleanliness $_cleanliness of 5'),
          key: const Key('requirement-cleanliness'),
        ),
        Semantics(
          label: homiziText(context, 'Cleanliness $_cleanliness of 5'),
          child: Slider(
            value: _cleanliness.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$_cleanliness',
            onChanged: (value) => setState(() => _cleanliness = value.round()),
          ),
        ),
        Text(homiziText(context, 'Home style')),
        const SizedBox(height: 8),
        _chips(
          context,
          options: requirementSocial,
          labelOf: requirementSocialLabel,
          selected: _socials,
          onToggled: (value) =>
              setState(() => _toggle(_socials, value, requirementSocial)),
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
          onToggled: (value) =>
              setState(() => _toggle(_cooking, value, requirementCooking)),
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
            '${formatInr(draft.budgetMinInr ?? 0)} – ${formatInr(draft.budgetMaxInr ?? 0)} · ${joinRequirementLabels(draft.roomTypes, requirementRoomTypeLabel)} · ${joinRequirementLabels(draft.furnishings, requirementFurnishingLabel)}',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            '${joinRequirementLabels(draft.foodHabits, requirementFoodLabel)} · ${joinRequirementLabels(draft.professions, requirementProfessionLabel)} · ${draft.discoverable ? 'Hosts and brokers can see this brief' : 'Hidden from hosts and brokers'}',
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
    required List<String> selected,
    required ValueChanged<String> onToggled,
    bool multi = true,
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
          onToggled: onToggled,
          multi: multi,
        ),
      ],
    );
  }

  Widget _chips(
    BuildContext context, {
    required List<String> options,
    required String Function(String value) labelOf,
    required List<String> selected,
    required ValueChanged<String> onToggled,
    bool multi = true,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          multi
              ? FilterChip(
                  label: Text(homiziText(context, labelOf(option))),
                  selected: selected.contains(option),
                  showCheckmark: true,
                  onSelected: (_) => onToggled(option),
                )
              : ChoiceChip(
                  label: Text(homiziText(context, labelOf(option))),
                  selected: selected.contains(option),
                  showCheckmark: true,
                  onSelected: (_) => onToggled(option),
                ),
      ],
    );
  }
}
