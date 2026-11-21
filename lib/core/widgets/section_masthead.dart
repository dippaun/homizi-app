import 'package:flutter/material.dart';
import 'package:homizi/core/widgets/homizi_tab_header.dart';

/// Centred Homizi wordmark with the signed-in photo on the left.
///
/// [leading] is a back control when the screen was opened above a tab.
/// The logo sits in its own middle slot so the photo and the back control
/// cannot cover it.
class SectionMasthead extends StatelessWidget {
  const SectionMasthead({this.leading, super.key});

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return HomiziTabHeader(
      leading: leading,
      profileKey: const Key('section-profile'),
    );
  }
}
