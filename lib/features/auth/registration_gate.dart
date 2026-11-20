import 'package:flutter_riverpod/flutter_riverpod.dart';
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
