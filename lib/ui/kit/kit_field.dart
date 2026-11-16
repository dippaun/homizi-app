import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Label sits above the box so it cannot collide with the field above it.
const TextStyle kitFieldLabelStyle = TextStyle(
  fontFamily: 'PlusJakartaSans',
  fontWeight: FontWeight.w700,
  fontSize: 13,
  height: 1.3,
  color: HomiziColors.ink,
);

/// Rounded field chrome. The label is drawn by [KitTextField], not floated.
InputDecoration kitInputDecoration({
  String? hint,
  String? helper,
  String? error,
  Widget? prefixIcon,
  String? prefixText,
  Widget? suffixIcon,
}) {
  const radius = BorderRadius.all(Radius.circular(16));
  return InputDecoration(
    hintText: hint,
    helperText: helper,
    errorText: error,
    errorMaxLines: 4,
    prefixIcon: prefixIcon,
    prefixText: prefixText,
    suffixIcon: suffixIcon,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    filled: true,
    fillColor: HomiziColors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomiziColors.line),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomiziColors.line),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomiziColors.logoOrange, width: 2),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomiziColors.error),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: HomiziColors.error, width: 2),
    ),
  );
}

/// Text field with a label above, a leading icon, and a 16px orange focus.
class KitTextField extends StatelessWidget {
  const KitTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.icon,
    this.fieldKey,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.enabled = true,
    this.autofocus = false,
    this.prefixText,
    this.inputFormatters,
    this.maxLength,
    this.autocorrect = true,
    this.gap = 16,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? error;
  final IconData? icon;
  final Key? fieldKey;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool enabled;
  final bool autofocus;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool autocorrect;

  /// Space under the field before the next control.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final leading = icon;
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(homiziText(context, label), style: kitFieldLabelStyle),
          const SizedBox(height: 6),
          TextField(
            key: fieldKey,
            controller: controller,
            maxLines: maxLines,
            minLines: minLines,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            onChanged: onChanged,
            readOnly: readOnly,
            onTap: onTap,
            enabled: enabled,
            autofocus: autofocus,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            autocorrect: autocorrect,
            enableInteractiveSelection: !readOnly,
            showCursor: !readOnly,
            style: const TextStyle(color: HomiziColors.ink, fontSize: 16),
            cursorColor: HomiziColors.logoOrange,
            decoration: kitInputDecoration(
              hint: hint == null ? null : homiziText(context, hint!),
              helper: helper == null ? null : homiziText(context, helper!),
              error: error == null ? null : homiziText(context, error!),
              prefixText: prefixText,
              prefixIcon: leading == null
                  ? null
                  : Icon(leading, color: HomiziColors.logoOrange),
            ),
          ),
        ],
      ),
    );
  }
}
