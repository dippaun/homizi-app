import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/host/host_navigation.dart';

/// Two ways in for a host: read what seekers need, or post a home.
class HostOptionsScreen extends ConsumerWidget {
  const HostOptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Host'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Text(
            homiziText(context, 'How do you want to start?'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'See the briefs people have already written, or list a home you have.',
            ),
          ),
          const SizedBox(height: 24),
          _OptionCard(
            key: const Key('host-see-seekers'),
            icon: Icons.groups_outlined,
            title: 'See what seekers need',
            benefit: 'Browse tenant and roommate briefs with a match %.',
            onTap: () => _open(context, RoutePaths.hostSeekers),
          ),
          const SizedBox(height: 16),
          _OptionCard(
            key: const Key('host-post-property'),
            icon: Icons.home_work_outlined,
            title: 'Post your property',
            benefit: 'Open the listing wizard for a home you can rent out.',
            onTap: () => _open(context, '${RoutePaths.listingEditor}?fresh=1'),
          ),
          const SizedBox(height: 16),
          _OptionCard(
            key: const Key('host-create-profile'),
            icon: Icons.badge_outlined,
            title: 'Create profile',
            benefit: 'Save your host profile, then come back.',
            onTap: () =>
                openHostProfile(context, ref, returnTo: RoutePaths.hostOptions),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, String path) {
    if (GoRouter.maybeOf(context) != null) {
      context.go(path);
    }
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.benefit,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String benefit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: HomiziColors.accentWash,
                child: Icon(icon, color: HomiziColors.accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(homiziText(context, benefit)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
