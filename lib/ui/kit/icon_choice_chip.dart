import 'package:flutter/material.dart';
import 'package:homizi/core/theme/flow_accent.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/ui/kit/real_life_icons.dart';

/// Icon chip that stays a [FilterChip] or [ChoiceChip]. Multi-select uses
/// [FilterChip]. Single-select uses [ChoiceChip].
class IconChoiceChip extends StatelessWidget {
  const IconChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.multi = true,
    this.showCheckmark = true,
    this.icon,
    super.key,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final bool multi;
  final bool showCheckmark;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final post = FlowAccentScope.active(context);
    final color = post ? HomiziColors.homiziPurple : HomiziColors.logoOrange;
    final wash = post
        ? HomiziColors.homiziLavender
        : HomiziColors.logoOrange.withValues(alpha: 0.10);
    final avatar = Icon(
      icon ?? iconForChoice(_labelText(label)),
      size: 18,
      color: color,
    );
    const labelStyle = TextStyle(color: HomiziColors.ink);
    final side = BorderSide(
      color: selected ? color : HomiziColors.line,
      width: selected ? 1.5 : 1,
    );
    if (multi) {
      return FilterChip(
        avatar: avatar,
        label: label,
        selected: selected,
        showCheckmark: showCheckmark,
        selectedColor: wash,
        checkmarkColor: HomiziColors.ink,
        backgroundColor: HomiziColors.white,
        labelStyle: labelStyle,
        side: side,
        onSelected: onSelected,
      );
    }
    return ChoiceChip(
      avatar: avatar,
      label: label,
      selected: selected,
      showCheckmark: showCheckmark,
      selectedColor: wash,
      checkmarkColor: HomiziColors.ink,
      backgroundColor: HomiziColors.white,
      labelStyle: labelStyle,
      side: side,
      onSelected: onSelected,
    );
  }
}

/// Maps a visible choice label onto [RealLifeIcons].
///
/// [group] is the question, such as Smoking or Food, so Yes / No / Occasional
/// each get their own symbol. The sliders glyph is never returned.
IconData iconForChoice(String raw, {String? group}) {
  final grouped = _iconForGroup(group, raw);
  if (grouped != null) {
    return grouped;
  }
  final text = raw.toLowerCase().trim();
  if (text.isEmpty) {
    return RealLifeIcons.more;
  }
  if (text.contains('prefer not') || text.contains('undisclosed')) {
    return RealLifeIcons.preferNot;
  }
  if (text.contains('non-veg') ||
      text.contains('non veg') ||
      text.contains('nonveg') ||
      text.contains('drumstick')) {
    return RealLifeIcons.nonVeg;
  }
  if (text.contains('egg')) {
    return RealLifeIcons.egg;
  }
  if (text.contains('veg')) {
    return RealLifeIcons.veg;
  }
  if (text.contains('no smok') || text.contains('smoke free')) {
    return RealLifeIcons.noSmoking;
  }
  if (text.contains('smok')) {
    return text == 'no' ? RealLifeIcons.noSmoking : RealLifeIcons.smoking;
  }
  if (text.contains('no drink') ||
      text.contains('no alcohol') ||
      text.contains('teetotal')) {
    return RealLifeIcons.noDrink;
  }
  if (text.contains('wine')) {
    return RealLifeIcons.wine;
  }
  if (text.contains('drink') || text.contains('alcohol')) {
    return RealLifeIcons.drink;
  }
  if (text.contains('occasional')) {
    return RealLifeIcons.occasional;
  }
  if (text == 'yes') {
    return RealLifeIcons.yes;
  }
  if (text == 'no' || text.startsWith('no ')) {
    return RealLifeIcons.no;
  }
  if (text.contains('master') || text.contains('bath') || text.contains('wc')) {
    return RealLifeIcons.bathroom;
  }
  if (text.contains('shared')) {
    return RealLifeIcons.sharedRoom;
  }
  if (text.contains('private') || text.contains('separate room')) {
    return RealLifeIcons.privateRoom;
  }
  if (text.contains('ahmedabad')) {
    return Icons.temple_hindu;
  }
  if (text.contains('mumbai')) {
    return Icons.sailing;
  }
  if (text.contains('delhi')) {
    return Icons.account_balance;
  }
  if (text.contains('bengaluru') || text.contains('bangalore')) {
    return Icons.park;
  }
  if (text.contains('chennai')) {
    return Icons.beach_access;
  }
  if (text.contains('hyderabad')) {
    return Icons.castle;
  }
  if (text.contains('jaipur')) {
    return Icons.palette;
  }
  if (text.contains('kochi')) {
    return Icons.water;
  }
  if (text.contains('kolkata')) {
    return Icons.directions_boat;
  }
  if (text.contains('pune')) {
    return Icons.landscape;
  }
  if (text.contains('flatmate') || text.contains('roommate')) {
    return RealLifeIcons.sharedRoom;
  }
  if (text.contains('whole home') || text.contains('entire home')) {
    return RealLifeIcons.house;
  }
  if (text.contains('house') ||
      text.contains('entire') ||
      text.contains('vacant')) {
    return RealLifeIcons.house;
  }
  if (text.contains('bhk') || text.contains('flat') || text.contains('rk')) {
    return RealLifeIcons.house;
  }
  if (text.contains('unfurnished')) {
    return RealLifeIcons.unfurnished;
  }
  if (text.contains('furnish')) {
    return RealLifeIcons.furnished;
  }
  if (text.contains('park') || text.contains('wheel')) {
    return RealLifeIcons.parking;
  }
  if (text.contains('lift') || text.contains('elevator')) {
    return RealLifeIcons.lift;
  }
  if (text.contains('gym')) {
    return RealLifeIcons.gym;
  }
  if (text.contains('wifi') || text.contains('wi-fi')) {
    return RealLifeIcons.wifi;
  }
  if (text.contains('power') || text.contains('backup')) {
    return RealLifeIcons.powerBackup;
  }
  if (text.contains('pet')) {
    return RealLifeIcons.pets;
  }
  if (text.contains('metro')) {
    return RealLifeIcons.metro;
  }
  if (text.contains('bus') || text.contains('transit')) {
    return RealLifeIcons.bus;
  }
  if (text.contains('walk')) {
    return RealLifeIcons.walk;
  }
  if (text.contains('bike') || text.contains('cycle')) {
    return RealLifeIcons.bike;
  }
  if (text.contains('car')) {
    return RealLifeIcons.car;
  }
  if (text.contains('school') || text.contains('student')) {
    return RealLifeIcons.school;
  }
  if (text.contains('hospital')) {
    return RealLifeIcons.hospital;
  }
  if (text.contains('office') || text.contains('work')) {
    return RealLifeIcons.work;
  }
  if (text.contains('cook')) {
    return RealLifeIcons.cook;
  }
  if (text.contains('clean')) {
    return RealLifeIcons.cleaning;
  }
  if (text.contains('guest')) {
    return RealLifeIcons.guests;
  }
  if (text.contains('family')) {
    return RealLifeIcons.family;
  }
  if (text.contains('couple')) {
    return RealLifeIcons.couple;
  }
  if (text.contains('move') ||
      text.contains('month') ||
      text.contains('lease') ||
      text.contains('date')) {
    return RealLifeIcons.calendar;
  }
  if (text.contains('budget') ||
      text.contains('rent') ||
      text.contains('₹') ||
      text.contains('rs')) {
    return RealLifeIcons.wallet;
  }
  if (text.contains('women') || text.contains('female')) {
    return RealLifeIcons.woman;
  }
  if (text.contains('men') || text.contains('male') || text == 'man') {
    return RealLifeIcons.man;
  }
  if (text.contains('language') ||
      text.contains('hindi') ||
      text.contains('english')) {
    return RealLifeIcons.language;
  }
  if (RegExp(r'^\d+$').hasMatch(text)) {
    final count = int.tryParse(text) ?? 0;
    if (count <= 1) {
      return RealLifeIcons.person;
    }
    if (count == 2) {
      return RealLifeIcons.couple;
    }
    return RealLifeIcons.sharedRoom;
  }
  if (text.contains('flex')) {
    return RealLifeIcons.flexible;
  }
  if (text.contains('immediate') || text.contains('now')) {
    return RealLifeIcons.soon;
  }
  if (text.contains('lgbt') || text.contains('inclusive')) {
    return RealLifeIcons.inclusive;
  }
  if (text.contains('security') || text.contains('guard')) {
    return RealLifeIcons.security;
  }
  if (text.contains('laundry') || text.contains('wash')) {
    return RealLifeIcons.laundry;
  }
  if (text.contains('fridge') || text.contains('refriger')) {
    return RealLifeIcons.fridge;
  }
  if (text.contains('ac') || text.contains('air')) {
    return RealLifeIcons.ac;
  }
  return RealLifeIcons.summary;
}

IconData? _iconForGroup(String? group, String raw) {
  if (group == null || group.trim().isEmpty) {
    return null;
  }
  final topic = group.toLowerCase();
  final text = raw.toLowerCase().trim();
  final preferNot = text.contains('prefer not') || text.contains('undisclosed');
  final no = text == 'no' || text.startsWith('no ') || text.contains('never');
  final yes = text == 'yes' || text.contains('regular');
  final occasional =
      text.contains('occasional') ||
      text.contains('sometimes') ||
      text == 'rare';
  if (topic.contains('smok')) {
    if (preferNot) {
      return RealLifeIcons.preferNot;
    }
    if (no) {
      return RealLifeIcons.noSmoking;
    }
    if (occasional) {
      return RealLifeIcons.occasionalSmoke;
    }
    if (yes) {
      return RealLifeIcons.smoking;
    }
  }
  if (topic.contains('drink') || topic.contains('alcohol')) {
    if (preferNot) {
      return RealLifeIcons.preferNot;
    }
    if (no) {
      return RealLifeIcons.noDrink;
    }
    if (occasional) {
      return RealLifeIcons.wine;
    }
    if (yes) {
      return RealLifeIcons.drink;
    }
  }
  if (topic.contains('food') || topic.contains('diet')) {
    if (preferNot) {
      return RealLifeIcons.preferNot;
    }
    if (text.contains('non')) {
      return RealLifeIcons.nonVeg;
    }
    if (text.contains('egg')) {
      return RealLifeIcons.egg;
    }
    if (text.contains('veg')) {
      return RealLifeIcons.veg;
    }
    if (text.contains('both') || text.contains('any')) {
      return RealLifeIcons.cook;
    }
  }
  if (topic.contains('cook')) {
    if (text.contains('shared')) {
      return RealLifeIcons.sharedRoom;
    }
    if (text.contains('hire') || text.contains('not')) {
      return RealLifeIcons.preferNot;
    }
    return RealLifeIcons.cook;
  }
  if (topic.contains('clean')) {
    if (text.contains('shared')) {
      return RealLifeIcons.sharedRoom;
    }
    if (text.contains('hire') || text.contains('help')) {
      return RealLifeIcons.cleaning;
    }
    return RealLifeIcons.cleaning;
  }
  if (topic.contains('pet')) {
    if (no || text.contains('not allowed')) {
      return RealLifeIcons.no;
    }
    if (preferNot) {
      return RealLifeIcons.preferNot;
    }
    return RealLifeIcons.pets;
  }
  if (topic.contains('guest')) {
    if (text.contains('rare')) {
      return RealLifeIcons.preferNot;
    }
    if (text.contains('frequent')) {
      return RealLifeIcons.guests;
    }
    return RealLifeIcons.guests;
  }
  return null;
}

String _labelText(Widget label) {
  if (label is Text) {
    final data = label.data;
    if (data != null) {
      return data;
    }
  }
  return '';
}
