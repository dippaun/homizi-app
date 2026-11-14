import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

const homiziShortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const homiziLongMonths = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `01 Dec 2026`. The day is always two digits.
String formatHomiziDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${homiziShortMonths[date.month - 1]} ${date.year}';
}

/// ISO `2026-12-01`, `01 Dec 2026`, `1 Dec 2026`, or `1 December 2026`.
DateTime? parseHomiziDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return null;
  }
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (iso != null) {
    return _valid(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  final words = RegExp(r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$').firstMatch(text);
  if (words == null) {
    return null;
  }
  final month = _monthIndex(words.group(2)!);
  if (month == null) {
    return null;
  }
  return _valid(int.parse(words.group(3)!), month, int.parse(words.group(1)!));
}

int? _monthIndex(String name) {
  final lower = name.toLowerCase();
  for (var index = 0; index < 12; index++) {
    if (homiziShortMonths[index].toLowerCase() == lower ||
        homiziLongMonths[index].toLowerCase() == lower) {
      return index + 1;
    }
  }
  return null;
}

DateTime? _valid(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

DateTime homiziToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Material date picker in Homizi colours.
///
/// The selected day uses ink on orange. White is not used on orange or yellow.
Future<DateTime?> showHomiziDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = 'Select date',
}) {
  var initial = DateTime(initialDate.year, initialDate.month, initialDate.day);
  final first = DateTime(firstDate.year, firstDate.month, firstDate.day);
  final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
  if (initial.isBefore(first)) {
    initial = first;
  } else if (initial.isAfter(last)) {
    initial = last;
  }
  final theme = Theme.of(context);
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: helpText,
    builder: (context, child) {
      return Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: HomiziColors.logoOrange,
            onPrimary: HomiziColors.ink,
            surface: HomiziColors.white,
            onSurface: HomiziColors.ink,
            secondary: HomiziColors.homiziPurple,
            onSecondary: HomiziColors.ink,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: HomiziColors.white,
            headerBackgroundColor: HomiziColors.homiziLavender,
            headerForegroundColor: HomiziColors.ink,
            dayForegroundColor: WidgetStateProperty.resolveWith(
              (_) => HomiziColors.ink,
            ),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return HomiziColors.logoOrange;
              }
              return null;
            }),
            todayForegroundColor: const WidgetStatePropertyAll(
              HomiziColors.ink,
            ),
            todayBackgroundColor: const WidgetStatePropertyAll(
              HomiziColors.accentWash,
            ),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: HomiziColors.ink,
            ),
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: HomiziColors.inkSoft,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: HomiziColors.ink),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}
