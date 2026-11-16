import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/city_locality_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:homizi/ui/kit/kit.dart';

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

  void _save() {
    final min = int.tryParse(_min.text.replaceAll(RegExp('[^0-9]'), ''));
    final max = int.tryParse(_max.text.replaceAll(RegExp('[^0-9]'), ''));
    if (min == null || max == null || min <= 0 || max <= 0) {
      setState(() => _error = 'Enter a budget in rupees.');
      return;
    }
    final chosen = _localities.isEmpty ? _localities : [..._localities];
    ref
        .read(flowPrefsProvider.notifier)
        .update(
          ref
              .read(flowPrefsProvider)
              .copyWith(
                city: _city,
                localities: chosen,
                budgetMin: min,
                budgetMax: max,
                amenities: _amenities.toList(),
                furnishing: _furnishing,
                note: _note.text.trim(),
              ),
        );
    context.push(RoutePaths.matchSwipe);
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
      body: ContentBody(
        pageId: 'flow-requirements',
        maxWidth: 480,
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
            CityLocalityField(
              cityKey: const Key('flow-city'),
              localityKey: const Key('flow-locality'),
              addKey: const Key('flow-add-locality'),
              city: _city,
              localities: [
                for (final name in _localities) PickedPlace(label: name),
              ],
              onChanged: (selection) => setState(() {
                _city = selection.city;
                _localities = [
                  for (final place in selection.localities) place.label,
                ];
              }),
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
    );
  }
}

String _furnishingLabel(String value) => switch (value) {
  'furnished' => 'Furnished',
  'unfurnished' => 'Unfurnished',
  _ => 'Semi-furnished',
};
