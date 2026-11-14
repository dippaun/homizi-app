import 'package:flutter/material.dart';
import 'package:homizi/core/format/homizi_date.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Tappable date field. Opens [showHomiziDatePicker] and shows `01 Dec 2026`.
///
/// Past dates are refused unless [allowPast] is set (date of birth). Future
/// dates are refused when [allowFuture] is false.
class HomiziDateField extends StatefulWidget {
  const HomiziDateField({
    required this.controller,
    required this.label,
    this.fieldKey,
    this.allowPast = false,
    this.allowFuture = true,
    this.firstDate,
    this.lastDate,
    this.icon = Icons.event_outlined,
    this.helpText,
    this.onPicked,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final bool allowPast;
  final bool allowFuture;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final IconData icon;
  final String? helpText;
  final ValueChanged<DateTime>? onPicked;

  @override
  State<HomiziDateField> createState() => _HomiziDateFieldState();
}

class _HomiziDateFieldState extends State<HomiziDateField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(HomiziDateField oldWidget) {
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

  Future<void> _pick() async {
    final today = homiziToday();
    final first =
        widget.firstDate ??
        (widget.allowPast ? DateTime(today.year - 100) : today);
    var last =
        widget.lastDate ??
        (widget.allowFuture ? DateTime(today.year + 3, 12, 31) : today);
    if (last.isBefore(first)) {
      last = first;
    }
    final current = parseHomiziDate(widget.controller.text);
    final picked = await showHomiziDatePicker(
      context: context,
      initialDate: current ?? (widget.allowPast ? last : today),
      firstDate: first,
      lastDate: last,
      helpText: widget.helpText ?? widget.label,
    );
    if (picked == null || !mounted) {
      return;
    }
    widget.controller.text = formatHomiziDate(picked);
    widget.onPicked?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseHomiziDate(widget.controller.text);
    final empty = widget.controller.text.trim().isEmpty;
    final shown = parsed == null
        ? (empty
              ? homiziText(context, 'Choose a date')
              : widget.controller.text.trim())
        : formatHomiziDate(parsed);
    return InkWell(
      key: widget.fieldKey,
      onTap: _pick,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: homiziText(context, widget.label),
          prefixIcon: Icon(widget.icon, color: HomiziColors.logoOrange),
          filled: true,
          fillColor: HomiziColors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: HomiziColors.line),
          ),
        ),
        child: Text(
          shown,
          style: TextStyle(
            color: empty && parsed == null
                ? HomiziColors.muted
                : HomiziColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
