import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/account_prompt.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/host/host_navigation.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/priorities/host_priority_providers.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/roles/role_switch_bar.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/session/signed_in.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';

/// The host / owner / broker journey: switch role, post a home, set the
/// preferred tenant profile, then read top matches and profiles.
class HostOptionsScreen extends ConsumerWidget {
  const HostOptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homes = ref.watch(hostPropertiesProvider);
    final live = {
      for (final home in ref.watch(demoListingMemoryProvider).homes.values)
        if (home.status == 'published') home.id,
    };
    // Only homes this user published count as "Property posted".
    final posted = [
      for (final home in homes)
        if (!isSampleHostHome(home) &&
            (home.justPublished || live.contains(home.id)))
          home,
    ];
    final samples = [
      for (final home in homes)
        if (isSampleHostHome(home)) home,
    ];
    final priorities = ref.watch(hostTenantPrioritiesProvider);
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Host journey')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          const RoleSwitchBar(key: Key('host-role-switch')),
          const SizedBox(height: 8),
          _JourneySteps(
            posted: posted.isNotEmpty,
            prioritiesSaved: priorities.saved,
            onStep: (step) => switch (step) {
              0 => _postProperty(context, ref),
              1 => _push(context, RoutePaths.hostPriorities),
              _ => _push(context, RoutePaths.hostTopMatches),
            },
          ),
          const SizedBox(height: 20),
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
            onTap: () => _postProperty(context, ref),
          ),
          const SizedBox(height: 16),
          _YourProperty(
            home: posted.isNotEmpty
                ? posted.first
                : samples.isEmpty
                ? null
                : samples.first,
            sample: posted.isEmpty,
            onPost: () => _postProperty(context, ref),
            onEdit: () => _push(context, RoutePaths.ownerDashboard),
          ),
          const SizedBox(height: 16),
          _OptionCard(
            key: const Key('host-set-priorities'),
            icon: Icons.format_list_numbered,
            title: 'Set your priorities',
            benefit: priorities.saved
                ? 'Saved: ${[for (final c in priorities.activeOrdered) hostCriterionTitle(c)].join(', ')}.'
                : 'Rank budget, move-in, working professional, food, gender & age.',
            onTap: () => _push(context, RoutePaths.hostPriorities),
          ),
          const SizedBox(height: 16),
          _OptionCard(
            key: const Key('host-top-matches'),
            icon: Icons.workspace_premium_outlined,
            title: 'Top match profiles',
            benefit: 'Seekers ranked by your priorities, with profile details.',
            onTap: () => _push(context, RoutePaths.hostTopMatches),
          ),
          const SizedBox(height: 16),
          _OptionCard(
            key: const Key('host-shared-home'),
            icon: Icons.people_alt_outlined,
            title: 'Share your home',
            benefit: 'Beds, flatmates and join requests for a shared home.',
            onTap: () => _push(context, SharedHomePaths.host),
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
          const SizedBox(height: 16),
          _OptionCard(
            key: const Key('host-become-a-host'),
            icon: Icons.home_work_outlined,
            title: 'Become a Host',
            benefit: 'Category, verification, and a trust record.',
            onTap: () {
              if (GoRouter.maybeOf(context) != null) {
                context.push(RoutePaths.listStart);
              }
            },
          ),
          const SizedBox(height: 20),
          const _WhyBetter(),
        ],
      ),
    );
  }

  void _postProperty(BuildContext context, WidgetRef ref) {
    if (!ref.read(signedInProvider)) {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        unawaited(router.push(signInReturn(RoutePaths.listStart)));
      }
      return;
    }
    _open(context, RoutePaths.listStart);
  }

  void _push(BuildContext context, String path) {
    if (GoRouter.maybeOf(context) != null) {
      unawaited(context.push(path));
    }
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
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

class _JourneySteps extends StatelessWidget {
  const _JourneySteps({
    required this.posted,
    required this.prioritiesSaved,
    required this.onStep,
  });

  final bool posted;
  final bool prioritiesSaved;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Post property', Icons.home_work_outlined, posted),
      ('Set priorities', Icons.format_list_numbered, prioritiesSaved),
      ('Top matches', Icons.groups_outlined, false),
      ('Profile & connect', Icons.badge_outlined, false),
    ];
    return Container(
      key: const Key('host-journey-steps'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: InkWell(
                key: Key('host-journey-step-${i + 1}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onStep(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: steps[i].$3
                            ? HomiziColors.success
                            : HomiziColors.logoOrange,
                        child: steps[i].$3
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: HomiziColors.onSuccess,
                              )
                            : Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: HomiziColors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        homiziText(context, steps[i].$1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _YourProperty extends StatelessWidget {
  const _YourProperty({
    required this.home,
    required this.sample,
    required this.onPost,
    required this.onEdit,
  });

  final HostProperty? home;

  /// A labelled sample, not a home this user posted.
  final bool sample;
  final VoidCallback onPost;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final home = this.home;
    return Container(
      key: const Key('host-your-property'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiziColors.line),
      ),
      child: home == null
          ? Row(
              children: [
                const Icon(Icons.add_home_outlined, color: HomiziColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    homiziText(
                      context,
                      'No property posted yet. Post one to rank seekers against it.',
                    ),
                    style: const TextStyle(color: HomiziColors.inkSoft),
                  ),
                ),
                TextButton(
                  key: const Key('host-your-property-post'),
                  onPressed: onPost,
                  child: Text(homiziText(context, 'Post')),
                ),
              ],
            )
          : Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    home.photoAsset,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 64,
                      height: 64,
                      child: Icon(Icons.home_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, home.label),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        homiziText(
                          context,
                          [
                            home.locality,
                            home.city,
                          ].where((v) => v.trim().isNotEmpty).join(', '),
                        ),
                        style: const TextStyle(
                          color: HomiziColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${formatInr(home.rentInr)}/${homiziText(context, 'month')}',
                        style: const TextStyle(
                          color: HomiziColors.brandDeepRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sample)
                        Container(
                          key: const Key('host-property-sample'),
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: HomiziColors.warningWash,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            homiziText(
                              context,
                              'Sample home · post yours to replace it',
                            ),
                            style: const TextStyle(
                              color: HomiziColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: HomiziColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              homiziText(context, 'Property posted'),
                              key: const Key('host-property-posted'),
                              style: const TextStyle(
                                color: HomiziColors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                OutlinedButton(
                  key: Key(
                    sample ? 'host-your-property-post' : 'host-edit-property',
                  ),
                  onPressed: sample ? onPost : onEdit,
                  child: Text(homiziText(context, sample ? 'Post' : 'Edit')),
                ),
              ],
            ),
    );
  }
}

class _WhyBetter extends StatelessWidget {
  const _WhyBetter();

  @override
  Widget build(BuildContext context) {
    const points = [
      (Icons.tune, 'Your priorities decide the match %'),
      (Icons.verified_outlined, 'Verified profiles first'),
      (Icons.lock_outline, 'Numbers stay private until shared'),
      (Icons.bolt_outlined, 'Faster, better-fit tenants'),
    ];
    return Container(
      key: const Key('host-why-better'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiziColors.successWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, "Why it's better"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(point.$1, size: 18, color: HomiziColors.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(homiziText(context, point.$2))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
