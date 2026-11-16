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
IconData iconForChoice(String raw) {
  final text = raw.toLowerCase();
  if (text.contains('non-veg') ||
      text.contains('non veg') ||
      text.contains('nonveg')) {
    return RealLifeIcons.nonVeg;
  }
  if (text.contains('veg')) {
    return RealLifeIcons.veg;
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
  if (text.contains('house') ||
      text.contains('entire') ||
      text.contains('vacant')) {
    return RealLifeIcons.house;
  }
  if (text.contains('bhk') || text.contains('flat') || text.contains('rk')) {
    return RealLifeIcons.house;
  }
  if (text.contains('furnish')) {
    return RealLifeIcons.furnished;
  }
  if (text.contains('park') || text.contains('car') || text.contains('wheel')) {
    return RealLifeIcons.parking;
  }
  if (text.contains('lift')) {
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
  if (text.contains('smok')) {
    return RealLifeIcons.smoking;
  }
  if (text.contains('drink')) {
    return RealLifeIcons.drink;
  }
  if (text.contains('metro')) {
    return RealLifeIcons.metro;
  }
  if (text.contains('bus')) {
    return RealLifeIcons.bus;
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
  if (text.contains('move') ||
      text.contains('month') ||
      text.contains('lease')) {
    return RealLifeIcons.calendar;
  }
  if (text.contains('budget') || text.contains('rent')) {
    return RealLifeIcons.wallet;
  }
  if (text.contains('women') || text.contains('female')) {
    return RealLifeIcons.woman;
  }
  if (text.contains('men') || text.contains('male')) {
    return RealLifeIcons.man;
  }
  if (text.contains('couple')) {
    return RealLifeIcons.couple;
  }
  return RealLifeIcons.tune;
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
