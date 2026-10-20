import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/session/session_state.dart';

/// Set when someone asks to create a tenant profile before they are signed in.
/// Cleared once the profile screen is finished or skipped.
enum TenantIntent { profile }

class TenantIntentController extends Notifier<TenantIntent?> {
  @override
  TenantIntent? build() => null;

  void requestProfile() => state = TenantIntent.profile;

  void clear() => state = null;
}

final tenantIntentProvider =
    NotifierProvider<TenantIntentController, TenantIntent?>(
      TenantIntentController.new,
    );

/// Keeps a pending profile request on the setup screen after sign-in.
/// Auth screens and the shell home hand off. Every other route stays put.
String? tenantIntentRedirect({
  required String? base,
  required SessionPhase phase,
  required String path,
  required bool profilePending,
}) {
  if (!profilePending || phase != SessionPhase.ready) {
    return base;
  }
  if (path == RoutePaths.tenantSetup) {
    return null;
  }
  const handoff = {
    RoutePaths.splash,
    RoutePaths.welcome,
    RoutePaths.login,
    RoutePaths.role,
    RoutePaths.home,
  };
  if (base != null && handoff.contains(base)) {
    return RoutePaths.tenantSetup;
  }
  if (handoff.contains(path)) {
    return RoutePaths.tenantSetup;
  }
  return base;
}

/// Routes the "create profile before login" prompt to sign-in.
/// A second tap while already on sign-in does not navigate again.
void beginTenantProfileSignIn(BuildContext context, WidgetRef ref) {
  ref.read(tenantIntentProvider.notifier).requestProfile();
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    return;
  }
  if (router.routeInformationProvider.value.uri.path == RoutePaths.login) {
    return;
  }
  router.go(RoutePaths.login);
}

class TenantSignInPrompt extends ConsumerWidget {
  const TenantSignInPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      key: const Key('create-profile-before-login'),
      onPressed: () => beginTenantProfileSignIn(context, ref),
      child: Text(
        homiziText(context, 'Sign in to create your tenant profile.'),
      ),
    );
  }
}
