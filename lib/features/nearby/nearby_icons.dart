import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

IconData nearbyKindIcon(String kind) {
  return switch (kind) {
    'metro' => Icons.subway,
    'train' => Icons.train,
    'bus' => Icons.directions_bus,
    'airport' => Icons.flight,
    'hospital' => Icons.local_hospital,
    'supermarket' => Icons.local_grocery_store,
    'mall' => Icons.shopping_bag,
    'movie' => Icons.movie,
    'gym' => Icons.fitness_center,
    _ => Icons.place,
  };
}

Color nearbyKindColor(String kind) {
  return switch (kind) {
    'metro' => HomiziColors.logoOrange,
    'train' => HomiziColors.ink,
    'bus' => HomiziColors.brandVermilion,
    'airport' => HomiziColors.brandDeepOrange,
    'hospital' => HomiziColors.brandDeepRed,
    'supermarket' => HomiziColors.success,
    'mall' => HomiziColors.brandRedOrange,
    'movie' => HomiziColors.inkSoft,
    'gym' => HomiziColors.brandDarkRed,
    _ => HomiziColors.logoOrange,
  };
}
