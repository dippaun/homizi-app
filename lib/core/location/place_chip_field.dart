import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Places autocomplete that adds each pick as a removable chip.
///
/// The text box keeps whatever is still being typed, so a form can save the
/// chips and the unfinished line together.
class PlaceChipField extends StatelessWidget {
  const PlaceChipField({
    required this.controller,
    required this.selected,
    required this.onSelectedPlaces,
    this.onPlace,
    this.fieldKey,
    this.labelText,
    this.hintText,
    this.biasPoint,
    super.key,
  });

  final TextEditingController controller;
  final List<String> selected;
  final ValueChanged<List<String>> onSelectedPlaces;
  final ValueChanged<PlaceSuggestion>? onPlace;
  final Key? fieldKey;
  final String? labelText;
  final String? hintText;
  final GeoFix? biasPoint;

  void _add(String label) {
    final name = label.trim();
    if (name.isEmpty || selected.contains(name)) {
      controller.clear();
      return;
    }
    onSelectedPlaces([...selected, name]);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in selected)
                InputChip(
                  key: Key('place-chip-$name'),
                  label: Text(name),
                  onDeleted: () => onSelectedPlaces([
                    for (final item in selected)
                      if (item != name) item,
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        PlaceAutocompleteField(
          controller: controller,
          fieldKey: fieldKey,
          labelText: labelText,
          hintText: hintText,
          biasPoint: biasPoint,
          commitLabel: false,
          prefixIcon: const Icon(
            Icons.location_city_outlined,
            color: HomiziColors.logoOrange,
          ),
          onSelected: (place) {
            onPlace?.call(place);
            _add(place.label);
          },
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            'Pick a suggestion to add an area. You can add more than one.',
          ),
          style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
