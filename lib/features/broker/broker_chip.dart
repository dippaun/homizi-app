import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Marks a broker-listed home or a broker profile. Near-black on a pale wash.
class BrokerChip extends StatelessWidget {
  const BrokerChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Chip(
      key: const Key('broker-chip'),
      avatar: const Icon(Icons.badge_outlined, size: 18, color: HomiziColors.ink),
      label: Text(homiziText(context, 'Broker')),
      backgroundColor: HomiziColors.accentWash,
      side: const BorderSide(color: HomiziColors.accent),
      labelStyle: const TextStyle(color: HomiziColors.ink),
      visualDensity: VisualDensity.compact,
    );
  }
}
