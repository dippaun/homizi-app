import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';

/// Budget, location, amenities, and preferences. Always editable.
class FlowRequirementsScreen extends ConsumerStatefulWidget {
  const FlowRequirementsScreen({super.key});

  @override
  ConsumerState<FlowRequirementsScreen> createState() =>
      _FlowRequirementsScreenState();
}

class _FlowRequirementsScreenState
    extends ConsumerState<FlowRequirementsScreen> {
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final TextEditingController _note;
  late String _city;
  late List<String> _localities;
  late Set<String> _amenities;
  late String _furnishing;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(flowPrefsProvider);
    _min = TextEditingController(text: '${prefs.budgetMin}');
    _max = TextEditingController(text: '${prefs.budgetMax}');
    _note = TextEditingController(text: prefs.note);
    _city = prefs.city;
    _localities = [...prefs.localities];
    _amenities = {...prefs.amenities};
    _furnishing = prefs.furnishing;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _note.dispose();
    super.dispose();
  }

  List<String> get _places {
    final names = [
      for (final place in localitySeed)
        if (place.city == _city) place.name,
    ];
    if (names.isEmpty) {
      return const ['Andheri East', 'Bandra West'];
    }
    if (names.length > 8) {
      return names.sublist(0, 8);
    }
    return names;
  }

  void _save() {
    final min = int.tryParse(_min.text.replaceAll(RegExp('[^0-9]'), ''));
    final max = int.tryParse(_max.text.replaceAll(RegExp('[^0-9]'), ''));
    if (min == null || max == null || min <= 0 || max <= 0) {
      setState(() => _error = 'Enter a budget in rupees.');
      return;
    }
    final places = _localities.where(_places.contains).toList();
    final chosen = places.isEmpty ? [_places.first] : places;
    ref.read(flowPrefsProvider.notifier).update(
      ref.read(flowPrefsProvider).copyWith(
        city: _city,
        localities: chosen,
        budgetMin: min,
        budgetMax: max,
        amenities: _amenities.toList(),
        furnishing: _furnishing,
        note: _note.text.trim(),
      ),
    );
    context.push('${RoutePaths.flowSwipe}?deck=property');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('flow-requirements-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Requirements')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                homiziText(
                  context,
                  'Budget, location, amenities, and preferences. Edit these any time from the deck.',
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  height: 1.35,
                  color: HomiziColors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                homiziText(context, 'Location'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('flow-city'),
                initialValue: exploreCities.contains(_city)
                    ? _city
                    : exploreCities.first,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'City'),
                ),
                items: [
                  for (final city in exploreCities)
                    DropdownMenuItem(value: city, child: Text(city)),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _city = value;
                    _localities = [];
                  });
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final place in _places)
                    FilterChip(
                      key: Key(
                        'flow-locality-${place.toLowerCase().replaceAll(' ', '-')}',
                      ),
                      label: Text(place),
                      selected: _localities.contains(place),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _localities.add(place);
                          } else {
                            _localities.remove(place);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                homiziText(context, 'Budget'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('flow-budget-min'),
                      controller: _min,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: homiziText(context, 'Minimum ₹'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('flow-budget-max'),
                      controller: _max,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: homiziText(context, 'Maximum ₹'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                homiziText(context, 'Amenities'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in requirementAmenities)
                    FilterChip(
                      key: Key('flow-amenity-$item'),
                      label: Text(
                        homiziText(context, requirementAmenityLabel(item)),
                      ),
                      selected: _amenities.contains(item),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _amenities.add(item);
                          } else {
                            _amenities.remove(item);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                homiziText(context, 'Preferences'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in const [
                    'furnished',
                    'semi_furnished',
                    'unfurnished',
                  ])
                    ChoiceChip(
                      key: Key('flow-furnishing-$item'),
                      label: Text(homiziText(context, _furnishingLabel(item))),
                      selected: _furnishing == item,
                      onSelected: (_) => setState(() => _furnishing = item),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('flow-preference-note'),
                controller: _note,
                maxLines: 3,
                maxLength: 160,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'Other preferences'),
                  hintText: homiziText(
                    context,
                    'Working professional, no smoking, near a metro',
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  homiziText(context, _error!),
                  style: const TextStyle(color: HomiziColors.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('flow-requirements-continue'),
                onPressed: _save,
                child: Text(homiziText(context, 'See matches')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _furnishingLabel(String value) => switch (value) {
  'furnished' => 'Furnished',
  'unfurnished' => 'Unfurnished',
  _ => 'Semi-furnished',
};
