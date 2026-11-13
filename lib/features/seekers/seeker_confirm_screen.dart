import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

/// End of a seeker action. One back control.
class SeekerConfirmScreen extends StatelessWidget {
  const SeekerConfirmScreen({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('seeker-confirm'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
        elevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              const Icon(
                Icons.check_circle,
                size: 52,
                color: HomiziColors.success,
              ),
              const SizedBox(height: 16),
              Text(
                homiziText(context, title),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                homiziText(context, message),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: HomiziColors.inkSoft,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('seeker-confirm-next'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomiziColors.accent,
                    foregroundColor: HomiziColors.ink,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: onAction,
                  child: Text(homiziText(context, actionLabel!)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
