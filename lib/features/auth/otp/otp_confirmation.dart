import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

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
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomiziColors.successWash,
                    borderRadius: BorderRadius.circular(HomiziSpace.cardRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(HomiziSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: HomiziColors.success,
                          size: 56,
                        ),
                        const SizedBox(height: HomiziSpace.md),
                        Text(
                          homiziText(context, title),
                          key: const Key('otp-confirmed'),
                          style: text.headlineSmall?.copyWith(
                            color: HomiziColors.ink,
                          ),
                        ),
                        if (note != null && note.isNotEmpty) ...[
                          const SizedBox(height: HomiziSpace.xs),
                          Text(
                            homiziText(context, note),
                            style: text.bodyMedium?.copyWith(
                              color: HomiziColors.inkSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: HomiziSpace.xl),
                FilledButton(
                  key: continueKey,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomiziColors.logoOrange,
                    foregroundColor: HomiziColors.ink,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: onContinue,
                  child: Text(homiziText(context, 'Continue')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
