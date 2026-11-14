import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/roles/role_onboarding_widgets.dart';
import 'package:homizi/features/session/session_controller.dart';

class RoleReadyScreen extends ConsumerWidget {
  const RoleReadyScreen({required this.role, super.key});

  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wire = switch (role) {
      'host' || 'broker' || 'roommate' || 'tenant' => role,
      _ =>
        ref.watch(sessionProvider).homiziWire ??
            ref.watch(personalizationProvider).roleWire ??
            'tenant',
    };
    final city = ref.watch(personalizationProvider).city.trim();
    final place = city.isEmpty ? 'your city' : city;
    final copy = switch (wire) {
      'host' =>
        'List a home in $place, then keep listings and tenant leads on your dashboard.',
      'broker' =>
        'Seeker briefs, your listings, and leads for $place are on your dashboard.',
      'roommate' =>
        'Flatmate matches around $place are ready in Find Your Roomie.',
      _ => 'Homes in $place are ready on your feed.',
    };
    final primary = switch (wire) {
      'host' => 'List your property',
      'broker' => 'Open dashboard',
      'roommate' => 'Find your roomie',
      _ => 'See homes',
    };
    return RoleFlowScaffold(
      screenKey: const Key('role-ready-screen'),
      title: "You're all set",
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        children: [
          const Icon(Icons.check_circle, color: HomiziColors.success, size: 56),
          const SizedBox(height: 16),
          const Text(
            "You're all set",
            key: Key('role-ready-title'),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          RoleFlowIntro(copy),
          const SizedBox(height: 28),
          RoleFlowContinue(
            buttonKey: const Key('role-ready-continue'),
            label: primary,
            onPressed: () => context.go(_primaryPath(wire)),
          ),
          if (wire == 'host') ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('role-ready-dashboard'),
              onPressed: () => context.go(RoutePaths.ownerDashboard),
              child: const Text(
                'My listings',
                style: TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _primaryPath(String wire) {
    return switch (wire) {
      'host' => RoutePaths.listStart,
      'broker' => RoutePaths.partnerHome,
      'roommate' => RoutePaths.roommate,
      _ => RoutePaths.home,
    };
  }
}
