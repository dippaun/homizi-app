import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';

/// Role homes. These screens do not show a back control.
bool homiziPathIsRootHome(String path) {
  return path == RoutePaths.home ||
      path == RoutePaths.hostHome ||
      path == RoutePaths.brokerHome ||
      path == RoutePaths.splash;
}

/// One app-bar back control. Pops when it can, otherwise opens the role home.
///
/// Inactive shell branches and pages covered by a later route build nothing,
/// so a screen shows this control only while it is the visible page.
class HomiziBackButton extends StatelessWidget {
  const HomiziBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  static void leave(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
        return;
      }
      final path = router.routeInformationProvider.value.uri.path;
      if (!homiziPathIsRootHome(path)) {
        router.go(RoutePaths.home);
      }
      return;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  bool _visible(BuildContext context) {
    if (!TickerMode.valuesOf(context).enabled) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible(context)) {
      return const SizedBox.shrink();
    }
    return BackButton(onPressed: onPressed ?? () => leave(context));
  }
}
