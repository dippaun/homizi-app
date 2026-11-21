import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/otp/otp_visuals.dart';

/// End of an email or mobile code flow.
class OtpConfirmation extends StatelessWidget {
  const OtpConfirmation({
    required this.title,
    required this.onContinue,
    super.key,
    this.detail,
    this.continueKey = const Key('otp-continue'),
  });

  final String title;
  final String? detail;
  final VoidCallback onContinue;
  final Key continueKey;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final note = detail;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewHeight = constraints.maxHeight;
        final minHeight = viewHeight.isFinite
            ? viewHeight - HomiziSpace.lg * 2
            : 0.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(HomiziSpace.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: OtpVerifiedBadge()),
                const SizedBox(height: HomiziSpace.lg),
                Text(
                  homiziText(context, title),
                  key: const Key('otp-confirmed'),
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: HomiziSpace.xs),
                  Text(
                    homiziText(context, note),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: HomiziColors.inkSoft,
                    ),
                  ),
                ],
                const SizedBox(height: HomiziSpace.xl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: otpBadgeGradient,
                    borderRadius: BorderRadius.circular(HomiziSpace.radius),
                  ),
                  child: FilledButton(
                    key: continueKey,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomiziColors.clear,
                      shadowColor: HomiziColors.clear,
                      foregroundColor: HomiziColors.ink,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(HomiziSpace.radius),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: onContinue,
                    child: Text(homiziText(context, 'Continue')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
