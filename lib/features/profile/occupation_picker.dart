import 'package:flutter/material.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Occupation as icon tiles. The older "Working professional" value selects
/// Salaried until the person picks again.
class OccupationPicker extends StatelessWidget {
  const OccupationPicker({
    required this.selected,
    required this.onSelected,
    this.error,
    super.key,
  });

  final String? selected;
  final ValueChanged<String> onSelected;
  final String? error;

  static IconData iconFor(String tile) {
    return switch (tile) {
      'Student' => RealLifeIcons.school,
      'Salaried' => RealLifeIcons.work,
      'Business' => RealLifeIcons.briefcase,
      'Freelancer' => RealLifeIcons.freelancer,
      _ => RealLifeIcons.more,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stored = selected;
    return KitChoiceField<String>(
      key: const Key('profile-occupation-tiles'),
      label: 'Occupation',
      icon: RealLifeIcons.work,
      error: error,
      selected: profileOccupationTiles.contains(stored)
          ? stored
          : (profileOccupationSelected('Salaried', stored)
                ? 'Salaried'
                : stored),
      options: [
        for (final tile in profileOccupationTiles)
          KitOption(
            value: tile,
            label: tile,
            icon: iconFor(tile),
            key: Key('occupation-$tile'),
          ),
      ],
      onChanged: onSelected,
    );
  }
}
