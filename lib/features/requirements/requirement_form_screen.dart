import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';

const _knownCities = exploreCities;

class RequirementFormScreen extends ConsumerStatefulWidget {
  const RequirementFormScreen({super.key});

  @override
  ConsumerState<RequirementFormScreen> createState() =>
      _RequirementFormScreenState();
}

class _RequirementFormScreenState extends ConsumerState<RequirementFormScreen> {
  final _locality = TextEditingController();
  int _budgetMin = InrRangeScale.presetMin;
  int _budgetMax = InrRangeScale.presetMax;
  String? _id;
  String _city = 'Bengaluru';
  DateTime? _moveIn;
  int _occupancy = 1;
  String _propertyType = 'apartment';
  String _furnishing = 'semi_furnished';
  final Set<String> _lifestyle = {};
  List<String> _errors = const [];
  String? _note;
  var _loading = true;
  var _busy = false;
  var _step = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _locality.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final loaded = await ref
          .read(inventoryGatewayProvider)
          .loadLatestRequirement();
      if (!mounted) {
        return;
      }
      if (loaded != null) {
        _id = loaded.id;
        _city = loaded.city.isEmpty ? _city : loaded.city;
        _locality.text = loaded.locality;
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
        _propertyType = loaded.propertyType;
        _furnishing = loaded.furnishing;
        _lifestyle
          ..clear()
          ..addAll(loaded.lifestyle);
      }
    } on InventoryFailure catch (error) {
      _note = error.message;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  RequirementDraft _draft() {
    return RequirementDraft(
      id: _id,
      budgetMinInr: _budgetMin,
      budgetMaxInr: _budgetMax,
      city: _city,
      locality: _locality.text,
      moveInDate: _moveIn,
      occupancy: _occupancy,
      propertyType: _propertyType,
      furnishing: _furnishing,
      lifestyle: _lifestyle.toList(),
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
      _step = (_step + 1).clamp(0, 3);
    });
  }

  List<String> _stepIssues(RequirementDraft draft) {
    final all = draft.errors(today: DateTime.now());
    return switch (_step) {
      0 => [
        for (final issue in all)
          if (issue.startsWith('Choose a city') ||
              issue.startsWith('Add at least one locality'))
            issue,
      ],
      1 => [
        for (final issue in all)
          if (issue.contains('budget')) issue,
      ],
      2 => [
        for (final issue in all)
          if (issue.startsWith('Occupancy') ||
              issue.startsWith('Move-in') ||
              issue.startsWith('Choose a property') ||
              issue.startsWith('Choose a furnishing') ||
              issue.startsWith('Choose lifestyle'))
            issue,
      ],
      _ => all,
    };
  }

  Future<void> _write({required bool publish}) async {
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
        body: Center(
          child: CircularProgressIndicator(key: Key('requirement-loading')),
        ),
      );
    }
    final moveLabel = _moveIn == null
        ? 'Choose a move-in date'
        : '${_moveIn!.year}-${_moveIn!.month.toString().padLeft(2, '0')}-${_moveIn!.day.toString().padLeft(2, '0')}';
    final cities = [
      ..._knownCities,
      if (!_knownCities.contains(_city) && _city.isNotEmpty) _city,
    ];
    final draft = _draft();
    final ready = draft.errors(today: DateTime.now()).isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(homiziText(context, 'What you need'))),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (step) => setState(() => _step = step),
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        steps: [
          Step(
            title: Text(homiziText(context, 'Place')),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    homiziText(
                      context,
                      'City and locality only. A street address is not collected.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _city,
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'City'),
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
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          Step(
            title: Text(homiziText(context, 'Budget')),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.indexed,
            content: HomiziRangeField(
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
          ),
          Step(
            title: Text(homiziText(context, 'Household')),
            isActive: _step >= 2,
            state: _step > 2 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(
                    context,
                    'Occupancy is a headcount. Gender, religion, caste, and age are not asked.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(homiziText(context, 'Occupancy')),
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
                OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(homiziText(context, moveLabel)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('requirement-property-type'),
                  initialValue: _propertyType,
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'Property type'),
                  ),
                  items: [
                    for (final type in requirementPropertyTypes)
                      DropdownMenuItem(
                        value: type,
                        child: Text(
                          homiziText(
                            context,
                            requirementPropertyTypeLabel(type),
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _propertyType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(homiziText(context, 'Lifestyle')),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in requirementLifestyles)
                      FilterChip(
                        key: Key('requirement-lifestyle-$item'),
                        label: Text(
                          homiziText(context, requirementLifestyleLabel(item)),
                        ),
                        selected: _lifestyle.contains(item),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _lifestyle.add(item);
                          } else {
                            _lifestyle.remove(item);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Step(
            title: Text(homiziText(context, 'Review')),
            isActive: _step >= 3,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(
                    context,
                    '${draft.city}, ${draft.locality.isEmpty ? 'locality not set' : draft.locality}',
                  ),
                ),
                Text(
                  homiziText(
                    context,
                    '${formatInr(draft.budgetMinInr ?? 0)} – ${formatInr(draft.budgetMaxInr ?? 0)} · $_occupancy people · ${requirementPropertyTypeLabel(draft.propertyType)} · ${requirementFurnishingLabel(draft.furnishing)}',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  homiziText(
                    context,
                    'Saving does not publish. Publish keeps the requirement on this device until a server accepts it.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Material(
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_step < 3)
                    FilledButton(
                      key: const Key('requirement-continue'),
                      onPressed: _continue,
                      child: Text(homiziText(context, 'Continue')),
                    ),
                  if (_step == 3) ...[
                    FilledButton(
                      key: const Key('requirement-save'),
                      onPressed: _busy
                          ? null
                          : () => unawaited(_write(publish: false)),
                      child: Text(homiziText(context, 'Save draft')),
                    ),
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
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step -= 1),
                      child: Text(homiziText(context, 'Back')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
