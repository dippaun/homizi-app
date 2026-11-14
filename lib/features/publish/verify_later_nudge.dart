import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/profile_create/profile_create_screen.dart';

/// Soft reminder after a brief or home is already live.
class VerifyLaterNudge extends StatelessWidget {
  const VerifyLaterNudge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('verify-profile-nudge'),
      decoration: BoxDecoration(
        color: HomiziColors.successWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, 'Verify your profile to get more responses'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: HomiziColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  key: const Key('publish-verify-later'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(
                    homiziText(context, 'Later'),
                    style: const TextStyle(color: HomiziColors.success),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('publish-verify-now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomiziColors.success,
                    foregroundColor: HomiziColors.onSuccess,
                  ),
                  onPressed: () {
                    final router = GoRouter.maybeOf(context);
                    if (router != null) {
                      router.push(RoutePaths.profileCreate);
                      return;
                    }
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const ProfileCreateScreen(),
                      ),
                    );
                  },
                  child: Text(homiziText(context, 'Verify now')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
