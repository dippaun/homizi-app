import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/features/roommates/roomie/roomie_catalog.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/roommates/roomie/roomie_widgets.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';

class RoomiePreferencesScreen extends ConsumerStatefulWidget {
  const RoomiePreferencesScreen({super.key});

  @override
  ConsumerState<RoomiePreferencesScreen> createState() =>
      _RoomiePreferencesScreenState();
}

class _RoomiePreferencesScreenState
    extends ConsumerState<RoomiePreferencesScreen> {
  final _occupation = TextEditingController();
  final _lifestyleNote = TextEditingController();
  var _budgetMin = 18000;
  var _budgetMax = 32000;
  var _city = 'Bengaluru';
  final _localities = <String>[];
  DateTime _moveIn = DateTime.utc(2026, 12);
  var _food = 'vegetarian';
  var _smoking = 'no';
  var _drinking = 'no';
  var _guests = 'rarely';
  var _cooking = 'cook_myself';
  var _gender = 'any';
  var _note = '';
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(roomieProvider).brief;
    if (saved == null) {
      return;
    }
    _budgetMin = saved.budgetLow;
    _budgetMax = saved.budgetHigh;
    _city = saved.city;
    _localities.addAll(saved.localities);
    _moveIn = saved.moveIn;
    _occupation.text = saved.occupation;
    _lifestyleNote.text = saved.lifestyleNote;
    _food = saved.food;
    _smoking = saved.smoking;
    _drinking = saved.drinking;
    _guests = saved.guests;
    _cooking = saved.cooking;
    _gender = saved.genderPreference;
  }

  @override
  void dispose() {
    _occupation.dispose();
    _lifestyleNote.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final initial = _moveIn.isBefore(first) ? first : _moveIn;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _moveIn = DateTime.utc(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    final job = _occupation.text.trim();
    if (_localities.isEmpty || job.isEmpty) {
      setState(() {
        _note = _localities.isEmpty
            ? 'Choose at least one locality.'
            : 'Add your occupation.';
      });
      return;
    }
    final brief = RoomieBrief(
      budgetMinInr: _budgetMin,
      budgetMaxInr: _budgetMax,
      city: _city,
      localities: List<String>.from(_localities),
      moveIn: _moveIn,
      occupation: job,
      food: _food,
      smoking: _smoking,
      drinking: _drinking,
      guests: _guests,
      cooking: _cooking,
      genderPreference: _gender,
      lifestyleNote: _lifestyleNote.text,
    );
    setState(() => _busy = true);
    ref.read(roomieProvider.notifier).save(brief);
    try {
      await ref
          .read(roommateProfileGatewayProvider)
          .save(
            brief.toRequirementDraft(),
            lifestyle: roomieLifestyleColumns(brief),
          );
    } on Object {
      // The brief is already on this device.
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    unawaited(context.push(RoutePaths.roomieSaved));
  }

  void _setCity(String city) {
    setState(() {
      _city = city;
      _localities.removeWhere((name) => !roomieLocalities(city).contains(name));
    });
  }

  @override
  Widget build(BuildContext context) {
    return RoomiePage(
      title: 'Your preferences',
      body: ListView(
        key: const Key('roomie-preferences-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            homiziText(
              context,
              'Tell us how you want to live. We use this to rank roomies. It stays on this device.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: HomiziColors.ink),
          ),
          HomiziRangeField(
            label: 'Budget range',
            min: InrRangeScale.min,
            max: InrRangeScale.max,
            step: InrRangeScale.step,
            start: _budgetMin,
            end: _budgetMax,
            formatValue: formatInr,
            minSemantics: 'Minimum budget',
            maxSemantics: 'Maximum budget',
            sliderKey: const Key('roomie-budget'),
            onChanged: (start, end) {
              setState(() {
                _budgetMin = start;
                _budgetMax = end;
              });
            },
          ),
          const RoomieSectionLabel('City'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final city in roomieCities)
                RoomieChip(
                  key: Key('roomie-city-$city'),
                  label: city,
                  selected: _city == city,
                  onSelected: () => _setCity(city),
                ),
            ],
          ),
          const RoomieSectionLabel('Preferred localities'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in roomieLocalities(_city))
                RoomieChip(
                  key: Key('roomie-locality-$name'),
                  label: name,
                  selected: _localities.contains(name),
                  onSelected: () {
                    setState(() {
                      if (_localities.contains(name)) {
                        _localities.remove(name);
                      } else {
                        _localities.add(name);
                      }
                    });
                  },
                ),
            ],
          ),
          const RoomieSectionLabel('Move-in date'),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('roomie-move-in'),
              onPressed: _pickDate,
              child: Text(
                homiziText(context, 'Move-in ${roomieDayLabel(_moveIn)}'),
              ),
            ),
          ),
          const RoomieSectionLabel('Occupation'),
          TextField(
            key: const Key('roomie-occupation'),
            controller: _occupation,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Occupation'),
              filled: true,
              fillColor: HomiziColors.white,
            ),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          const RoomieSectionLabel('Lifestyle & Preferences'),
          const RoomieSectionLabel('Smoking'),
          _choices(
            const ['yes', 'no', 'undisclosed'],
            _smoking,
            (value) => setState(() => _smoking = value),
            roomieYesNoLabel,
            'roomie-smoking',
          ),
          const RoomieSectionLabel('Drinking alcohol'),
          _choices(
            const ['yes', 'no', 'undisclosed'],
            _drinking,
            (value) => setState(() => _drinking = value),
            roomieYesNoLabel,
            'roomie-drinking',
          ),
          const RoomieSectionLabel('Food preference'),
          _choices(
            const ['vegetarian', 'non_vegetarian', 'both', 'undisclosed'],
            _food,
            (value) => setState(() => _food = value),
            roomieFoodLabel,
            'roomie-food',
          ),
          const RoomieSectionLabel('Guests'),
          _choices(
            const ['frequently', 'occasionally', 'rarely'],
            _guests,
            (value) => setState(() => _guests = value),
            roomieGuestsLabel,
            'roomie-guests',
          ),
          const RoomieSectionLabel('Cooking'),
          _choices(
            const ['cook_myself', 'shared', 'prefer_not'],
            _cooking,
            (value) => setState(() => _cooking = value),
            roomieCookingLabel,
            'roomie-cooking',
          ),
          const RoomieSectionLabel('Other lifestyle preferences'),
          TextField(
            key: const Key('roomie-lifestyle-note'),
            controller: _lifestyleNote,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Other lifestyle preferences'),
              filled: true,
              fillColor: HomiziColors.white,
            ),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          const RoomieSectionLabel('Gender preference'),
          _choices(
            const ['any', 'women', 'men', 'same'],
            _gender,
            (value) => setState(() => _gender = value),
            _genderLabel,
            'roomie-gender',
          ),
          if (_note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, _note),
              style: const TextStyle(color: HomiziColors.ink),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('roomie-save'),
            onPressed: _busy ? null : _save,
            child: Text(homiziText(context, 'Save preferences')),
          ),
        ],
      ),
    );
  }

  Widget _choices(
    List<String> values,
    String selected,
    ValueChanged<String> onSelected,
    String Function(String value) labelOf,
    String keyPrefix,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          RoomieChip(
            key: Key('$keyPrefix-$value'),
            label: labelOf(value),
            selected: selected == value,
            onSelected: () => onSelected(value),
          ),
      ],
    );
  }
}

String _genderLabel(String value) => switch (value) {
  'any' => 'No preference',
  'women' => 'Women',
  'men' => 'Men',
  'same' => 'Same gender',
  _ => value,
};
