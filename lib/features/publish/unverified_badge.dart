import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Small status chip. It does not block publishing.
class UnverifiedBadge extends StatelessWidget {
  const UnverifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HomiziColors.warningWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        homiziText(context, 'Unverified'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: HomiziColors.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
