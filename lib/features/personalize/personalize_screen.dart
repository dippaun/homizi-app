import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/city_locality_field.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/roles/role_flow.dart';
import 'package:homizi/features/roles/role_onboarding_widgets.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Short seeker preferences. Role, language, and appearance live elsewhere.
class PersonalizeScreen extends ConsumerStatefulWidget {
  const PersonalizeScreen({super.key});

  @override
  ConsumerState<PersonalizeScreen> createState() => _PersonalizeScreenState();
}

class _PersonalizeScreenState extends ConsumerState<PersonalizeScreen> {
  final _city = TextEditingController();
  var _locating = false;
  var _accepted = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final city = ref.read(personalizationProvider).city;
    if (city.isNotEmpty) {
      _city.text = city;
      _accepted = city;
    }
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    var message = 'Location permission was not granted. Type your city.';
    try {
      final service = ref.read(locationServiceProvider);
      final fix = await service.currentPosition();
      if (!mounted) {
        return;
      }
      if (fix != null && !service.mapsEnabled) {
        message =
            'Location permission was granted. HOMIZI has no maps key, so it cannot name the city. Type it below. The coordinates were not saved.';
      } else if (fix != null) {
        final place = await service.reverseGeocode(fix);
        if (!mounted) {
          return;
        }
        final name = (place?.city ?? '').trim();
        if (name.isNotEmpty) {
          _acceptCity(name);
          message = 'Location set from maps. You can edit the city.';
        } else {
          message =
              'Location was shared, but maps did not name the city. Type it below. The coordinates were not saved.';
        }
      }
    } on Object {
      message = 'Location could not be read. Type your city.';
    } finally {
      if (mounted) {
        ref.read(personalizationProvider.notifier).setLocationNote(message);
        setState(() => _locating = false);
      }
    }
  }

  void _acceptCity(String name) {
    final city = name.trim();
    if (city.length < 2) {
      return;
    }
    _accepted = city;
    if (_city.text != city) {
      _city.value = TextEditingValue(
        text: city,
        selection: TextSelection.collapsed(offset: city.length),
      );
    }
    ref.read(personalizationProvider.notifier).setCity(city);
    setState(() => _error = null);
  }

  String? _knownCity(String typed) {
    final needle = typed.trim().toLowerCase();
    for (final city in personalCities) {
      if (city.toLowerCase() == needle) {
        return city;
      }
    }
    return null;
  }

  void _onCityTyped(String value) {
    final known = _knownCity(value);
    if (known != null) {
      _accepted = known;
      ref.read(personalizationProvider.notifier).setCity(known);
      setState(() => _error = null);
      return;
    }
    if (value.trim() != _accepted) {
      _accepted = '';
      ref.read(personalizationProvider.notifier).setCity('');
    }
  }

  void _save() {
    final notifier = ref.read(personalizationProvider.notifier);
    final known = _knownCity(_city.text);
    if (known != null) {
      _accepted = known;
      notifier.setCity(known);
    }
    if (_accepted.trim().length < 2 ||
        ref.read(personalizationProvider).city.trim().length < 2) {
      setState(() => _error = 'Choose a city from the suggestions.');
      return;
    }
    if (ref.read(personalizationProvider).roleWire != 'tenant') {
      notifier.setRole('tenant');
    }
    setState(() => _error = null);
    unawaited(notifier.save());
    unawaited(context.push(readyLocation('tenant')));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(personalizationProvider);
    return RoleFlowScaffold(
      screenKey: const Key('personalize-screen'),
      title: 'Personalize',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const RoleFlowIntro(
            'Tell HOMIZI what you are looking for. Language and appearance stay in Settings.',
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Preferred city'),
          const SizedBox(height: 8),
          PlaceAutocompleteField(
            controller: _city,
            fieldKey: const Key('personalize-city'),
            hintText: homiziText(context, 'Search a city'),
            labelText: homiziText(context, 'City'),
            stackedLabel: true,
            prefixIcon: const Icon(Icons.location_city_outlined),
            includedPrimaryTypes: const ['locality'],
            nearbyLocalities: catalogCitySuggestions(),
            helperText: homiziText(
              context,
              'Choose a city from the suggestions.',
            ),
            onChanged: _onCityTyped,
            onSelected: (place) {
              final name = pickedCityName(place);
              if (name.isEmpty) {
                return;
              }
              _acceptCity(name);
            },
          ),
          const SizedBox(height: 12),
          OptionGrid(
            children: [
              for (final city in personalCities)
                OptionTile(
                  key: Key('personalize-city-$city'),
                  label: homiziText(context, city),
                  icon: _cityIcon(city),
                  selected: _accepted == city,
                  onTap: () => _acceptCity(city),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('personalize-locate'),
            onPressed: _locating ? null : () => unawaited(_locate()),
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined),
            label: Text(homiziText(context, 'Use my location')),
          ),
          if (prefs.locationNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              key: const Key('personalize-location-note'),
              homiziText(context, prefs.locationNote),
              style: const TextStyle(color: HomiziColors.inkSoft),
            ),
          ],
          const SizedBox(height: 20),
          const RoleFlowLabel('What are you looking for?'),
          const SizedBox(height: 8),
          OptionGrid(
            children: [
              for (final entry in tenantLookingFor.entries)
                OptionTile(
                  key: Key('personalize-looking-${entry.key}'),
                  label: homiziText(context, entry.value),
                  icon: _lookingIcon(entry.key),
                  selected: prefs.lookingFor == entry.key,
                  onTap: () => ref
                      .read(personalizationProvider.notifier)
                      .setLookingFor(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Indicative budget'),
          const SizedBox(height: 8),
          OptionGrid(
            children: [
              for (final band in personalBudgets)
                OptionTile(
                  key: Key('personalize-budget-${band.id}'),
                  label: homiziText(context, band.label),
                  icon: _budgetIcon(band.id),
                  selected:
                      prefs.budgetMin == band.min &&
                      prefs.budgetMax == band.max,
                  onTap: () => ref
                      .read(personalizationProvider.notifier)
                      .setBudget(band.min, band.max),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('When do you move?'),
          const SizedBox(height: 8),
          OptionGrid(
            children: [
              for (final entry in personalMoveIns.entries)
                OptionTile(
                  key: Key('personalize-move-${entry.key}'),
                  label: homiziText(context, entry.value),
                  icon: _moveIcon(entry.key),
                  selected: prefs.moveIn == entry.key,
                  onTap: () => ref
                      .read(personalizationProvider.notifier)
                      .setMoveIn(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Optional preferences'),
          const SizedBox(height: 8),
          OptionGrid(
            children: [
              for (final entry in personalPreferenceChoices.entries)
                OptionTile(
                  key: Key('personalize-pref-${entry.key}'),
                  label: homiziText(context, entry.value),
                  icon: _preferenceIcon(entry.key),
                  selected: prefs.preferences.contains(entry.key),
                  onTap: () => ref
                      .read(personalizationProvider.notifier)
                      .togglePreference(entry.key),
                ),
            ],
          ),
          RoleFlowError(
            message: _error,
            errorKey: const Key('personalize-error'),
          ),
          const SizedBox(height: 20),
          RoleFlowContinue(
            buttonKey: const Key('personalize-save'),
            label: 'Continue',
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

IconData _cityIcon(String city) => switch (city) {
  'Ahmedabad' => Icons.temple_hindu,
  'Mumbai' => Icons.sailing,
  'Delhi NCR' => Icons.account_balance,
  'Bengaluru' => Icons.park,
  'Chennai' => Icons.beach_access,
  'Hyderabad' => Icons.castle,
  'Jaipur' => Icons.palette,
  'Kochi' => Icons.water,
  'Kolkata' => Icons.directions_boat,
  'Pune' => Icons.landscape,
  _ => Icons.location_city,
};

IconData _lookingIcon(String id) => switch (id) {
  'home' => Icons.house,
  'room' => Icons.bed,
  'flatmate' => Icons.groups,
  _ => Icons.home_work_outlined,
};

IconData _budgetIcon(String id) => switch (id) {
  'unsure' => Icons.help_outline,
  'under15' => Icons.account_balance_wallet_outlined,
  '15to30' => Icons.currency_rupee,
  '30to50' => Icons.account_balance_wallet,
  'over50' => Icons.payments,
  _ => Icons.currency_rupee,
};

IconData _moveIcon(String id) => switch (id) {
  'now' => Icons.bolt,
  'month' => Icons.calendar_month,
  'quarter' => Icons.date_range,
  'flexible' => Icons.schedule,
  _ => Icons.calendar_today_outlined,
};

IconData _preferenceIcon(String id) => switch (id) {
  'furnished' => Icons.chair_outlined,
  'pets_ok' => Icons.pets,
  'non_smoker' => Icons.smoke_free,
  'wfh' => Icons.laptop_mac_outlined,
  'couple_friendly' => Icons.favorite_border,
  _ => Icons.interests,
};
