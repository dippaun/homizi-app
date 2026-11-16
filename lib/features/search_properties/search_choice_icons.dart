import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Art for one search choice. Floor plans for home sizes, Material icons
/// for everything else. Colour follows the selected state.
Widget searchChoiceArt(String label, {required bool selected, String? group}) {
  final color = selected ? HomiziColors.logoOrange : HomiziColors.inkSoft;
  final plan = floorPlanKindFor(label);
  if (plan != null) {
    return FloorPlanIcon(kind: plan, color: color);
  }
  return Icon(iconForChoice(label, group: group), color: color, size: 28);
}

FloorPlanKind? floorPlanKindFor(String label) {
  return switch (label) {
    'Individual house' => FloorPlanKind.house,
    '1 RK' => FloorPlanKind.rk,
    '1 BHK' => FloorPlanKind.bhk1,
    '2 BHK' => FloorPlanKind.bhk2,
    '3 BHK' => FloorPlanKind.bhk3,
    _ => null,
  };
}

IconData searchSectionIcon(String title) {
  return switch (title) {
    'Occupancy Required' => RealLifeIcons.privateRoom,
    'Property Type' => RealLifeIcons.house,
    'Monthly Budget' => RealLifeIcons.wallet,
    'Preferred Location & Workplace' => RealLifeIcons.office,
    'Possession Required From' => RealLifeIcons.calendar,
    'Flatmate / Roommate Gender Preference' => RealLifeIcons.sharedRoom,
    'Lifestyle Preference' => RealLifeIcons.lifestyle,
    'Furnishing Preference' => RealLifeIcons.furnished,
    'Bathroom Preference' => RealLifeIcons.bathroom,
    'Essential Amenities' => RealLifeIcons.wifi,
    'Property Rules & Restrictions' => RealLifeIcons.shield,
    'Suitable For' => RealLifeIcons.person,
    'Confirm your requirements' => RealLifeIcons.summary,
    _ => RealLifeIcons.tune,
  };
}

IconData searchSummaryIcon(String label) {
  return switch (label) {
    'Occupancy' => RealLifeIcons.privateRoom,
    'Property type' => RealLifeIcons.house,
    'Budget' => RealLifeIcons.wallet,
    'Location' => RealLifeIcons.locality,
    'Distance' => RealLifeIcons.metro,
    'Possession' => RealLifeIcons.calendar,
    'Flatmate gender' => RealLifeIcons.sharedRoom,
    'Food' => RealLifeIcons.veg,
    'Furnishing' => RealLifeIcons.furnished,
    'Bathroom' => RealLifeIcons.bathroom,
    'Amenities' => RealLifeIcons.wifi,
    'Rules' => RealLifeIcons.shield,
    'Suitable for' => RealLifeIcons.person,
    'Office commute shown' => RealLifeIcons.office,
    _ => RealLifeIcons.tune,
  };
}

IconData searchDistanceIcon(int km) {
  return switch (km) {
    1 => RealLifeIcons.walk,
    3 => RealLifeIcons.bike,
    5 => RealLifeIcons.bus,
    10 => RealLifeIcons.metro,
    _ => RealLifeIcons.car,
  };
}

IconData iconForChoice(String label, {String? group}) {
  if (group != null) {
    return _lifestyleIcon(group, label);
  }
  return _choiceIcons[label] ?? RealLifeIcons.tune;
}

IconData _lifestyleIcon(String group, String label) {
  if (label == 'No Preference') {
    return RealLifeIcons.tune;
  }
  return switch (group) {
    'Smoking' =>
      label == 'No' ? RealLifeIcons.noSmoking : RealLifeIcons.smoking,
    'Drinking' => label == 'No' ? RealLifeIcons.noDrink : RealLifeIcons.drink,
    'Food' => switch (label) {
      'Veg' => RealLifeIcons.veg,
      'Non-Veg' => RealLifeIcons.nonVeg,
      _ => RealLifeIcons.cook,
    },
    'Cooking' => switch (label) {
      'Shared cooking' => RealLifeIcons.sharedRoom,
      _ => RealLifeIcons.cook,
    },
    'Cleaning' => switch (label) {
      'Shared cleaning' => RealLifeIcons.sharedRoom,
      _ => RealLifeIcons.cleaning,
    },
    _ => RealLifeIcons.tune,
  };
}

const _choiceIcons = <String, IconData>{
  'Fully vacant property (entire property)': RealLifeIcons.house,
  'Master room with separate WC': RealLifeIcons.masterRoom,
  'Separate room': RealLifeIcons.privateRoom,
  'Shared room': RealLifeIcons.sharedRoom,
  'Anything suitable to my budget': RealLifeIcons.wallet,
  'Immediately': RealLifeIcons.soon,
  'Within 7 days': RealLifeIcons.today,
  'Within 15 days': RealLifeIcons.fortnight,
  'Within 30 days': RealLifeIcons.calendar,
  'Select a specific date': RealLifeIcons.event,
  'Flexible': RealLifeIcons.flexible,
  'Male': RealLifeIcons.man,
  'Female': RealLifeIcons.woman,
  'Any (suitable to my budget)': RealLifeIcons.wallet,
  'LGBTQ+ friendly': RealLifeIcons.inclusive,
  'Furnished': RealLifeIcons.furnished,
  'Semi-furnished': RealLifeIcons.furnished,
  'Unfurnished': RealLifeIcons.unfurnished,
  'Attached bathroom': RealLifeIcons.bathroom,
  'Separate private bathroom': RealLifeIcons.bathroom,
  'Shared bathroom': RealLifeIcons.sharedBath,
  'No Preference': RealLifeIcons.tune,
  'Parking': RealLifeIcons.parking,
  'Lift': RealLifeIcons.lift,
  'Wi-Fi': RealLifeIcons.wifi,
  'AC': RealLifeIcons.ac,
  'Washing Machine': RealLifeIcons.laundry,
  'Refrigerator': RealLifeIcons.fridge,
  'Gym': RealLifeIcons.gym,
  'Power Backup': RealLifeIcons.powerBackup,
  'Security (24×7)': RealLifeIcons.security,
  'Cook': RealLifeIcons.cook,
  'Cleaning Maid': RealLifeIcons.cleaning,
  'Others': RealLifeIcons.more,
  'Pets allowed': RealLifeIcons.pets,
  'Non-vegetarian food allowed': RealLifeIcons.nonVeg,
  'Guests allowed': RealLifeIcons.guests,
  'Drinking allowed': RealLifeIcons.drink,
  'Smoking allowed': RealLifeIcons.smoking,
  'Single working professional': RealLifeIcons.work,
  'Student': RealLifeIcons.school,
  'Couple': RealLifeIcons.couple,
  'Family': RealLifeIcons.family,
  'Bachelor / Bachelorette': RealLifeIcons.person,
};
