import 'package:flutter/material.dart';

/// Centres page content on a wide web window. Width stays on an 8pt grid.
class HomiziFrame extends StatelessWidget {
  const HomiziFrame({required this.child, super.key});

  static const maxWidth = 720.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
