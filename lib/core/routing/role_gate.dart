import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/roles/role_provider.dart';

/// Shows [child] when the current role is allowed. Otherwise an empty state
/// with one Back and a clear next step, so desk routes are not a dead end.
class RoleGate extends ConsumerWidget {
  const RoleGate({
    required this.allowed,
    required this.child,
    required this.title,
    required this.message,
    super.key,
  });

  final Set<HomiziRole> allowed;
  final Widget child;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    if (role != null && allowed.contains(role)) {
      return child;
    }
    return Scaffold(
      key: const Key('role-gate-blocked'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(title),
      ),
      body: HomiziFrame(
        child: EmptyState(
          title: title,
          message: message,
          actionLabel: 'Choose a role',
          onAction: () => context.go(RoutePaths.role),
        ),
      ),
    );
  }
}
