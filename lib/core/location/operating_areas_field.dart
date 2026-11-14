import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

const operatingAreaSeparator = ' · ';

List<String> splitOperatingAreas(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return const [];
  }
  if (text.contains(operatingAreaSeparator)) {
    return [
      for (final part in text.split(operatingAreaSeparator))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }
  return [text];
}

String joinOperatingAreas(List<String> areas) {
  return [
    for (final area in areas)
      if (area.trim().isNotEmpty) area.trim(),
  ].join(operatingAreaSeparator);
}

/// Multi-select operating areas. Typing opens Places suggestions. A chosen
/// place becomes a chip. The typed line still counts when the person continues
/// without tapping a suggestion.
class OperatingAreasField extends StatefulWidget {
  const OperatingAreasField({
    required this.controller,
    required this.areas,
    required this.onChanged,
    this.biasPoint,
    super.key,
  });

  final TextEditingController controller;
  final List<String> areas;
  final ValueChanged<List<String>> onChanged;
  final GeoFix? biasPoint;

  @override
  State<OperatingAreasField> createState() => _OperatingAreasFieldState();
}

class _OperatingAreasFieldState extends State<OperatingAreasField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(OperatingAreasField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _add(String raw) {
    final label = raw.trim();
    if (label.length < 2 || widget.areas.contains(label)) {
      widget.controller.clear();
      return;
    }
    widget.onChanged([...widget.areas, label]);
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final typed = widget.controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlaceAutocompleteField(
          fieldKey: const Key('post-operating-area'),
          controller: widget.controller,
          textCapitalization: TextCapitalization.words,
          biasPoint: widget.biasPoint,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Operating areas'),
            hintText: homiziText(context, 'Koramangala, Bengaluru'),
            prefixIcon: const Icon(
              Icons.add_location_alt_outlined,
              color: HomiziColors.logoOrange,
            ),
            filled: true,
            fillColor: HomiziColors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: HomiziColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: HomiziColors.homiziPurple,
                width: 2,
              ),
            ),
          ),
          onSelected: (place) => _add(place.label),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('post-operating-add'),
            onPressed: typed.length < 2 ? null : () => _add(typed),
            icon: const Icon(
              Icons.add,
              color: HomiziColors.logoOrange,
              size: 18,
            ),
            label: Text(
              homiziText(context, 'Add area'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (widget.areas.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final area in widget.areas)
                InputChip(
                  key: Key('operating-area-${area.toLowerCase()}'),
                  label: Text(
                    area,
                    style: const TextStyle(color: HomiziColors.ink),
                  ),
                  backgroundColor: HomiziColors.homiziLavender,
                  deleteIconColor: HomiziColors.ink,
                  onDeleted: () => widget.onChanged([
                    for (final item in widget.areas)
                      if (item != area) item,
                  ]),
                ),
            ],
          ),
      ],
    );
  }
}
