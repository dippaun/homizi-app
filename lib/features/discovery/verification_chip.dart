import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Green when the host or the listing is verified. Pending otherwise.
/// Pending uses dark amber text on a pale wash, never white on yellow.
class VerificationChip extends StatelessWidget {
  const VerificationChip({required this.verified, this.chipKey, super.key});

  final bool verified;
  final Key? chipKey;

  @override
  Widget build(BuildContext context) {
    final background = verified
        ? HomiziColors.success
        : HomiziColors.warningWash;
    final foreground = verified ? HomiziColors.onSuccess : HomiziColors.warning;
    return Container(
      key: chipKey ?? Key(verified ? 'verified-chip' : 'verification-pending'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (verified) ...[
            const Icon(Icons.verified, size: 14, color: HomiziColors.onSuccess),
            const SizedBox(width: 4),
          ],
          Text(
            homiziText(context, verified ? 'Verified' : 'Verification pending'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

bool listingShowsVerified({
  required bool hostVerified,
  required bool listingVerified,
  required bool identityVerified,
}) {
  return hostVerified || listingVerified || identityVerified;
}
