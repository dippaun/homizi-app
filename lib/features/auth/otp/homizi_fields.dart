import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

const _radius = BorderRadius.all(Radius.circular(16));
const _side = BorderSide(color: HomiziColors.line);

/// White field with a visible line, matching the email sign-in page.
InputDecoration homiziFieldDecoration({
  String? labelText,
  String? hintText,
  String? helperText,
  String? errorText,
  Widget? prefixIcon,
  BoxConstraints? prefixIconConstraints,
  int errorMaxLines = 3,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: prefixIcon,
    prefixIconConstraints: prefixIconConstraints,
    errorMaxLines: errorMaxLines,
    filled: true,
    fillColor: HomiziColors.white,
    border: const OutlineInputBorder(borderRadius: _radius, borderSide: _side),
    enabledBorder: const OutlineInputBorder(
      borderRadius: _radius,
      borderSide: _side,
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: _radius,
      borderSide: BorderSide(color: HomiziColors.logoOrange, width: 1.5),
    ),
  );
}

/// Orange action. Disabled ink sits on the pale wash, never white on orange.
ButtonStyle homiziPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: HomiziColors.logoOrange,
    foregroundColor: HomiziColors.ink,
    disabledBackgroundColor: HomiziColors.accentWash,
    disabledForegroundColor: HomiziColors.ink,
    minimumSize: const Size.fromHeight(48),
  );
}
