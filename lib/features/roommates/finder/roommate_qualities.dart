import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';

/// Strongest quality first. A right-to-left row paints that icon on the right.
List<(IconData, String)> roommateQualitySymbols(FinderPerson person) {
  final traits = person.traits;
  final symbols = <(IconData, String)>[];
  if ((traits.cleanliness ?? 0) >= 4) {
    symbols.add((Icons.cleaning_services_outlined, 'Clean'));
  }
  if (traits.smoking == 'never') {
    symbols.add((Icons.smoke_free, 'Non-smoker'));
  }
  if (traits.food == 'veg') {
    symbols.add((Icons.eco_outlined, 'Vegetarian'));
  } else if (traits.food == 'non_veg') {
    symbols.add((Icons.restaurant_outlined, 'Non-veg'));
  }
  final pets = traits.pets ?? '';
  if (pets == 'ok' || pets == 'has') {
    symbols.add((Icons.pets, 'Pets'));
  }
  if (traits.wfh == 'home') {
    symbols.add((Icons.laptop_mac, 'Works from home'));
  }
  if (traits.sleep == 'early') {
    symbols.add((Icons.wb_sunny_outlined, 'Early sleeper'));
  }
  if (person.drinking == 'no') {
    symbols.add((Icons.no_drinks, 'Does not drink'));
  }
  if ((traits.guests ?? '') == 'rare') {
    symbols.add((Icons.group_off_outlined, 'Few guests'));
  }
  return symbols;
}

/// Icon symbols for a roommate row, strongest on the right.
class RoommateQualityIcons extends StatelessWidget {
  const RoommateQualityIcons({required this.person, this.size = 16, super.key});

  final FinderPerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final symbols = roommateQualitySymbols(person).take(4).toList();
    if (symbols.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        for (final symbol in symbols)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Tooltip(
              message: homiziText(context, symbol.$2),
              child: Icon(
                symbol.$1,
                size: size,
                color: HomiziColors.logoOrange,
              ),
            ),
          ),
      ],
    );
  }
}
