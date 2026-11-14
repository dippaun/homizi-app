import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/publish/unverified_badge.dart';
import 'package:homizi/features/publish/verify_later_nudge.dart';

/// End of a roommate or seeker brief. One back control.
class BriefLiveScreen extends StatelessWidget {
  const BriefLiveScreen({
    required this.place,
    required this.onServer,
    required this.verified,
    super.key,
  });

  final String place;
  final bool onServer;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('brief-live'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Published')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomiziColors.successWash,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: Icon(
                      Icons.check_circle,
                      size: 48,
                      color: HomiziColors.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                homiziText(context, 'Your brief is live'),
                key: const Key('brief-live-title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (place.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  homiziText(context, place),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: HomiziColors.inkSoft,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                homiziText(
                  context,
                  onServer
                      ? 'Hosts and roommates can see this brief.'
                      : 'It shows in My activity on this device.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: HomiziColors.muted,
                ),
              ),
              if (!verified) ...[
                const SizedBox(height: 16),
                const Center(child: UnverifiedBadge()),
                const SizedBox(height: 16),
                const VerifyLaterNudge(),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('brief-live-done'),
                onPressed: () {
                  if (GoRouter.maybeOf(context) != null) {
                    leaveDemoSuccess(context);
                    return;
                  }
                  Navigator.of(context).pop();
                },
                child: Text(homiziText(context, 'Done')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
