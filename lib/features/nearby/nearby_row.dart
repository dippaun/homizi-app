import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/nearby/nearby_icons.dart';
import 'package:homizi/features/nearby/nearby_models.dart';

class NearbyCommuteTile extends StatelessWidget {
  const NearbyCommuteTile({required this.row, super.key});

  final NearbyCommuteRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('nearby-row-${row.kind}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(nearbyKindIcon(row.kind), color: nearbyKindColor(row.kind)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, row.label),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (row.name.trim().isNotEmpty)
                  Text(
                    row.name.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomiziColors.muted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (row.kmLabel.isNotEmpty)
            Text(
              row.kmLabel,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (row.minutesLabel.isNotEmpty) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 52,
              child: Text(
                row.minutesLabel,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: HomiziColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
