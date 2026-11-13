import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

/// Keeps `/priorities` open from Profile until Agent F's screen is on this branch.
///
/// Profile does not score matches here and does not invent a match percent.
class PrioritiesHandoff extends StatelessWidget {
  const PrioritiesHandoff({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('priorities-handoff'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Set My Priorities')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            homiziText(
              context,
              'Your priority order is set on this page. Profile does not calculate a match percent.',
            ),
            key: const Key('priorities-handoff-copy'),
          ),
        ],
      ),
    );
  }
}
