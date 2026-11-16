import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/ui/kit/kit_field.dart';
import 'package:homizi/ui/kit/real_life_icons.dart';

const homiziMonthLabels = <String>[
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

const _fullMonths = <String>[
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

/// `1 Dec 2026`. The day has no leading zero.
String formatHomiziDay(DateTime day) {
  return '${day.day} ${homiziMonthLabels[day.month - 1]} ${day.year}';
}

/// `DD/MM/YYYY`, the date-of-birth display.
String formatProfileDob(DateTime day) {
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  return '$dd/$mm/${day.year}';
}

/// ISO `YYYY-MM-DD` for a stored possession or move-in day.
String? homiziDayIso(String raw) {
  final day = parseHomiziDay(raw);
  if (day == null) {
    return null;
  }
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

DateTime? parseHomiziDay(String raw) {
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
  final named = RegExp(r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$').firstMatch(text);
  if (named != null) {
    final month = _monthIndex(named.group(2)!);
    if (month == null) {
      return null;
    }
    return _valid(
      int.parse(named.group(3)!),
      month,
      int.parse(named.group(1)!),
    );
  }
  final slash = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(text);
  if (slash != null) {
    return _valid(
      int.parse(slash.group(3)!),
      int.parse(slash.group(2)!),
      int.parse(slash.group(1)!),
    );
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

int? _monthIndex(String name) {
  final lower = name.toLowerCase();
  for (var index = 0; index < 12; index++) {
    final short = homiziMonthLabels[index].toLowerCase();
    if (lower == short || lower == _fullMonths[index]) {
      return index + 1;
    }
  }
  return null;
}

/// Calendar in the Homizi theme. The header stays white with ink type.
/// The selected day uses the pale orange wash, never white on yellow.
Future<DateTime?> pickHomiziDate(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final now = DateTime.now();
  final first = firstDate ?? DateTime(now.year - 80);
  final last = lastDate ?? DateTime(now.year + 6);
  var seed = initial ?? DateTime(now.year - 26, now.month, now.day);
  if (seed.isBefore(first)) {
    seed = first;
  }
  if (seed.isAfter(last)) {
    seed = last;
  }
  final theme = Theme.of(context);
  return showDatePicker(
    context: context,
    initialDate: seed,
    firstDate: first,
    lastDate: last,
    builder: (context, child) {
      return Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: HomiziColors.logoOrange,
            onPrimary: HomiziColors.ink,
            surface: HomiziColors.white,
            onSurface: HomiziColors.ink,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: HomiziColors.white,
            headerBackgroundColor: HomiziColors.white,
            headerForegroundColor: HomiziColors.ink,
            surfaceTintColor: HomiziColors.clear,
            dayForegroundColor: const WidgetStatePropertyAll(HomiziColors.ink),
            yearForegroundColor: const WidgetStatePropertyAll(HomiziColors.ink),
            weekdayStyle: const TextStyle(color: HomiziColors.inkSoft),
            todayForegroundColor: const WidgetStatePropertyAll(
              HomiziColors.ink,
            ),
            todayBorder: const BorderSide(color: HomiziColors.logoOrange),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return HomiziColors.accentWash;
              }
              return null;
            }),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: HomiziColors.white,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

/// Read-only date. A calendar icon opens [pickHomiziDate]. The field shows
/// `1 Dec 2026` and does not take typed text.
class HomiziDateField extends StatelessWidget {
  const HomiziDateField({
    required this.controller,
    required this.label,
    this.fieldKey,
    this.hint,
    this.firstDate,
    this.lastDate,
    this.initialWhenEmpty,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final String? hint;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Calendar starting day when the field is empty. Not written until OK.
  final DateTime? initialWhenEmpty;
  final ValueChanged<String>? onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await pickHomiziDate(
      context,
      initial: parseHomiziDay(controller.text) ?? initialWhenEmpty,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) {
      return;
    }
    final text = formatHomiziDay(picked);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    onChanged?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(homiziText(context, label), style: kitFieldLabelStyle),
          const SizedBox(height: 6),
          TextField(
            key: fieldKey,
            controller: controller,
            readOnly: true,
            enableInteractiveSelection: false,
            showCursor: false,
            onTap: () => _open(context),
            style: const TextStyle(color: HomiziColors.ink, fontSize: 16),
            decoration: kitInputDecoration(
              hint: hint == null ? '1 Dec 2026' : homiziText(context, hint!),
              prefixIcon: const Icon(
                RealLifeIcons.calendar,
                color: HomiziColors.logoOrange,
              ),
              suffixIcon: IconButton(
                tooltip: homiziText(context, 'Choose a date'),
                onPressed: () => _open(context),
                icon: const Icon(
                  Icons.calendar_month_outlined,
                  color: HomiziColors.logoOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
