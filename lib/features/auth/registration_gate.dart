import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

/// Set after this account finishes the registration page, until the user changes.
class RegistrationBypass extends Notifier<bool> {
  @override
  bool build() => false;

  void markDone() => state = true;

  void reset() => state = false;
}

final registrationBypassProvider = NotifierProvider<RegistrationBypass, bool>(
  RegistrationBypass.new,
);

/// One explicit Home tap from the sign-in celebration.
///
/// The registration gate would otherwise send `/` back to role select.
/// Cleared once Home is on screen.
class RegistrationHomePass extends Notifier<bool> {
  @override
  bool build() => false;

  void allow() => state = true;

  void consume() => state = false;
}

final registrationHomePassProvider =
    NotifierProvider<RegistrationHomePass, bool>(RegistrationHomePass.new);

/// True when a signed-in account still needs name, role, and the success page.
///
/// A missing profile row or a blank name / role is incomplete. A network
/// failure does not trap an existing account on the page.
final registrationGateProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(registrationBypassProvider)) {
    return false;
  }
  final session = ref.watch(sessionProvider);
  final uid = session.userId;
  if (uid == null || uid.isEmpty || !session.hasAccount) {
    return false;
  }
  try {
    final profile = await ref.read(accountGatewayProvider).loadTenantProfile();
    return !registrationIsComplete(
      displayName: profile.displayName,
      roleWire: session.homiziWire,
    );
  } on AccountFailure catch (error) {
    final message = error.message.toLowerCase();
    if (message.contains('profile row is missing') ||
        message.contains('no row')) {
      return true;
    }
    return false;
  } on Object {
    return false;
  }
});

bool registrationIsComplete({
  required String displayName,
  required String? roleWire,
}) {
  return displayName.trim().length >= 2 && isHomiziRoleWire(roleWire);
}

/// Where the router should send someone who still needs registration.
///
/// A bypass, or a gate that is still loading, is not a reason to open the
/// role picker. The previous `true` stays on screen while the provider
/// reloads, and treating that stale value as current sent a finished
/// profile back to the role page.
String? forcedRegistrationPath({
  required bool bypass,
  required bool gateLoading,
  required bool? gateValue,
  required String path,
}) {
  if (bypass || gateLoading || gateValue != true) {
    return null;
  }
  if (path == RoutePaths.registerFinish ||
      path == RoutePaths.profileCreate ||
      path == RoutePaths.postRoom ||
      RoutePaths.publicLegal.contains(path)) {
    return null;
  }
  return RoutePaths.registerFinish;
}
