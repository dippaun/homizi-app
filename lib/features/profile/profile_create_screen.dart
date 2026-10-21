import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';

/// Placeholder until the profile-create flow lands.
/// Continues into the tenant setup that already exists.
class ProfileCreateScreen extends StatelessWidget {
  const ProfileCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('profile-create-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Create your profile')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, 'Get verified and find genuine matches'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: HomiziColors.inkSoft,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('profile-create-continue'),
              onPressed: () => context.push(RoutePaths.tenantSetup),
              child: Text(homiziText(context, 'Continue')),
            ),
          ],
        ),
      ),
    );
  }
}
