import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/host/host_intent.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/tenant/tenant_intent.dart';

/// Old role homes and long wizards. Choosing a role must not open these.
const legacyRolePaths = <String>{
  RoutePaths.tenantHome,
  RoutePaths.requirement,
  RoutePaths.hostHome,
  RoutePaths.hostOnboard,
  RoutePaths.flowHost,
  RoutePaths.flowBroker,
  RoutePaths.brokerHome,
};

String setupPathFor(String wire) {
  return switch (wire) {
    'host' => RoutePaths.ownerSetup,
    'broker' => RoutePaths.partnerSetup,
    'roommate' => RoutePaths.sharerSetup,
    _ => RoutePaths.personalize,
  };
}

String homePathFor(String wire) {
  return switch (wire) {
    'host' => RoutePaths.ownerDashboard,
    'broker' => RoutePaths.partnerHome,
    'roommate' => RoutePaths.roommate,
    _ => RoutePaths.home,
  };
}

String? redirectPersonalizeForRole(String? wire) {
  if (wire == null || wire.isEmpty || wire == 'tenant') {
    return null;
  }
  return setupPathFor(wire);
}

/// Writes the role on the profile provider and, when a session exists, on it.
Future<String?> persistChosenRole(WidgetRef ref, String wire) async {
  ref.read(personalizationProvider.notifier).setRole(wire);
  final phase = ref.read(sessionProvider).phase;
  if (phase == SessionPhase.needsRole || phase == SessionPhase.ready) {
    return ref.read(sessionProvider.notifier).selectPrimaryRole(wire);
  }
  return null;
}

/// Opens the short setup for [wire]. A pending host profile still resumes.
void openRoleSetup(BuildContext context, WidgetRef ref, String wire) {
  if (wire == 'tenant' &&
      ref.read(tenantIntentProvider) == TenantIntent.profile) {
    context.go(RoutePaths.tenantSetup);
    return;
  }
  if (wire == 'host') {
    final pending = ref.read(hostIntentProvider).afterAuth;
    ref.read(hostIntentProvider.notifier).consumeAuth();
    if (pending != null &&
        !legacyRolePaths.contains(pending.split('?').first)) {
      context.go(pending);
      return;
    }
  }
  context.push(setupPathFor(wire));
}

String readyLocation(String wire) {
  return Uri(
    path: RoutePaths.roleReady,
    queryParameters: {'role': wire},
  ).toString();
}

HomiziRole? roleFromWire(String? wire) => homiziRoleFromWire(wire);
