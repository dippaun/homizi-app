import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

/// Placeholder for the seekers board. The requirements screen fills this route.
class SeekersScreen extends StatelessWidget {
  const SeekersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('seekers-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: const ScreenTitle('Seekers'),
      ),
      body: HomiziFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Text(
              homiziText(context, 'See what seekers need'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              homiziText(
                context,
                'Budgets, localities, and move-in dates from people looking for a home will show here.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: HomiziColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
