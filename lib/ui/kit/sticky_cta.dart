import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Sits in [Scaffold.bottomNavigationBar], above the shell nav and clear of
/// the scrolling content.
class StickyCta extends StatelessWidget {
  const StickyCta({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      elevation: 8,
      shadowColor: HomiziColors.shadowSoft,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: child,
        ),
      ),
    );
  }
}
