import 'package:flutter/material.dart';
import 'package:homizi/core/widgets/homizi_tab_header.dart';

/// Centred Homizi wordmark.
///
/// [leading] is a back control when the screen was opened above a tab.
/// The side slots stay equal so the wordmark stays centred.
class SectionMasthead extends StatelessWidget {
  const SectionMasthead({this.leading, super.key});

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return HomiziTabHeader(leading: leading);
  }
}
