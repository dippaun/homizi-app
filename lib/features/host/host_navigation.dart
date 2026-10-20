import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/host/host_intent.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

/// Opens the host profile. Signed-out people sign in first, then return here.
void openHostProfile(
  BuildContext context,
  WidgetRef ref, {
  String returnTo = RoutePaths.home,
}) {
  ref
      .read(hostIntentProvider.notifier)
      .remember(RoutePaths.hostProfile, afterProfile: returnTo);
  final phase = ref.read(sessionProvider).phase;
  if (phase != SessionPhase.ready) {
    final login = Uri(
      path: RoutePaths.login,
      queryParameters: const {'next': RoutePaths.hostProfile},
    ).toString();
    context.go(login);
    return;
  }
  ref.read(hostIntentProvider.notifier).consumeAuth();
  context.push(RoutePaths.hostProfile);
}

void leaveHostProfile(BuildContext context, WidgetRef ref) {
  final back = ref.read(hostIntentProvider).afterProfile;
  ref.read(hostIntentProvider.notifier).clearReturn();
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
    return;
  }
  if (back != null && back.isNotEmpty) {
    router.go(back);
    return;
  }
  if (router.canPop()) {
    router.pop();
    return;
  }
  router.go(RoutePaths.home);
}
