import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/priorities/priorities_screen.dart';

List<RouteBase> priorityRoutes() {
  return [
    GoRoute(
      path: RoutePaths.priorities,
      builder: (context, state) => const PrioritiesScreen(),
    ),
    GoRoute(
      path: RoutePaths.prioritiesSaved,
      builder: (context, state) => const PrioritiesSavedScreen(),
    ),
  ];
}

class PrioritiesSavedScreen extends StatelessWidget {
  const PrioritiesSavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('priority-saved-shot'),
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: HomiziColors.white,
          foregroundColor: HomiziColors.ink,
          leading: HomiziBackButton(
            onPressed: () => context.go(RoutePaths.home),
          ),
          title: Text(homiziText(context, 'Done')),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.check_circle,
              color: HomiziColors.success,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              homiziText(context, 'Priorities saved'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                'Your order is saved on this device and matches use it now. It syncs to your account after the priorities table is applied on staging.',
              ),
              style: const TextStyle(color: HomiziColors.ink, fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('priority-saved-home'),
              onPressed: () => context.go(RoutePaths.home),
              child: Text(homiziText(context, 'Back to Home')),
            ),
          ],
        ),
      ),
    );
  }
}
