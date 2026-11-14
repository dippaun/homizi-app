import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/roles/role_flow.dart';
import 'package:homizi/features/roles/role_onboarding_widgets.dart';

/// Short seeker preferences. Role, language, and appearance live elsewhere.
class PersonalizeScreen extends ConsumerStatefulWidget {
  const PersonalizeScreen({super.key});

  @override
  ConsumerState<PersonalizeScreen> createState() => _PersonalizeScreenState();
}

class _PersonalizeScreenState extends ConsumerState<PersonalizeScreen> {
  final _city = TextEditingController();
  var _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final city = ref.read(personalizationProvider).city;
    if (city.isNotEmpty) {
      _city.text = city;
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
          _city.text = name;
          ref.read(personalizationProvider.notifier).setCity(name);
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

  void _save() {
    final notifier = ref.read(personalizationProvider.notifier);
    notifier.setCity(_city.text.trim());
    if (ref.read(personalizationProvider).city.trim().length < 2) {
      setState(() => _error = 'Choose a city, or type one.');
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
          TextField(
            key: const Key('personalize-city'),
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: homiziText(context, 'City'),
              filled: true,
              fillColor: HomiziColors.soft,
            ),
            onChanged: (value) => ref
                .read(personalizationProvider.notifier)
                .setCity(value.trim()),
          ),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: {for (final city in personalCities) city: city},
            selected: (id) => _city.text == id,
            onSelected: (city) {
              _city.text = city;
              ref.read(personalizationProvider.notifier).setCity(city);
              setState(() {});
            },
            keyFor: (id) => Key('personalize-city-$id'),
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
          RoleFlowChips(
            options: tenantLookingFor,
            selected: (id) => prefs.lookingFor == id,
            onSelected: (id) =>
                ref.read(personalizationProvider.notifier).setLookingFor(id),
            keyFor: (id) => Key('personalize-looking-$id'),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Indicative budget'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: {for (final band in personalBudgets) band.id: band.label},
            selected: (id) {
              final band = personalBudgets.firstWhere((item) => item.id == id);
              return prefs.budgetMin == band.min && prefs.budgetMax == band.max;
            },
            onSelected: (id) {
              final band = personalBudgets.firstWhere((item) => item.id == id);
              ref
                  .read(personalizationProvider.notifier)
                  .setBudget(band.min, band.max);
            },
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('When do you move?'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: personalMoveIns,
            selected: (id) => prefs.moveIn == id,
            onSelected: (id) =>
                ref.read(personalizationProvider.notifier).setMoveIn(id),
            keyFor: (id) => Key('personalize-move-$id'),
          ),
          const SizedBox(height: 20),
          const RoleFlowLabel('Optional preferences'),
          const SizedBox(height: 8),
          RoleFlowChips(
            options: personalPreferenceChoices,
            selected: (id) => prefs.preferences.contains(id),
            onSelected: (id) =>
                ref.read(personalizationProvider.notifier).togglePreference(id),
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
