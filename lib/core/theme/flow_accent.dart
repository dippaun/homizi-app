import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Marks a subtree as the Post Property flow so shared listing widgets can
/// pick up lavender selection without changing the rest of the app.
class FlowAccentScope extends InheritedWidget {
  const FlowAccentScope({required super.child, super.key});

  static bool active(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FlowAccentScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(FlowAccentScope oldWidget) => false;
}

/// Leading icon for shared listing fields, only inside [FlowAccentScope].
Widget? flowFieldIcon(BuildContext context, IconData icon) {
  if (!FlowAccentScope.active(context)) {
    return null;
  }
  return Icon(icon, color: HomiziColors.logoOrange);
}
