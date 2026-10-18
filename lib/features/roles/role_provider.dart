import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

/// The role a person is using HOMIZI as right now.
///
/// Legacy `users.primary_role` values map here:
/// `tenant` stays tenant, `host` stays host, `both` becomes tenant, and a
/// host whose category is broker becomes broker. `unset` stays empty.
enum HomiziRole { roommate, tenant, host, broker }

/// Wire value stored on `profiles.primary_role`.
String homiziRoleWire(HomiziRole role) => role.name;

HomiziRole? homiziRoleFromWire(String? value) {
  return switch (value) {
    'roommate' => HomiziRole.roommate,
    'tenant' => HomiziRole.tenant,
    'host' => HomiziRole.host,
    'broker' => HomiziRole.broker,
    _ => null,
  };
}

/// Prefer [profilesPrimaryRole]. Otherwise map the legacy account role.
/// [hostCategory] `broker` turns a legacy host into [HomiziRole.broker].
HomiziRole? homiziRoleFromLegacy({
  String? profilesPrimaryRole,
  String? usersPrimaryRole,
  String? hostCategory,
}) {
  final stored = homiziRoleFromWire(profilesPrimaryRole);
  if (stored != null) {
    return stored;
  }
  return switch (usersPrimaryRole) {
    'roommate' => HomiziRole.roommate,
    'tenant' => HomiziRole.tenant,
    'broker' => HomiziRole.broker,
    'host' =>
      hostCategory == 'broker' ? HomiziRole.broker : HomiziRole.host,
    'both' => HomiziRole.tenant,
    _ => null,
  };
}

/// Legacy `users.primary_role` written beside the new profile column.
/// Roommate and tenant stay seekers. Host and broker stay listers.
String legacyUsersRoleWire(HomiziRole role) {
  return switch (role) {
    HomiziRole.roommate || HomiziRole.tenant => 'tenant',
    HomiziRole.host || HomiziRole.broker => 'host',
  };
}

AccountRole accountRoleForHomizi(HomiziRole role) {
  return switch (role) {
    HomiziRole.roommate || HomiziRole.tenant => AccountRole.tenant,
    HomiziRole.host || HomiziRole.broker => AccountRole.host,
  };
}

String homiziRoleLabel(HomiziRole role) {
  return switch (role) {
    HomiziRole.roommate => 'Roommate',
    HomiziRole.tenant => 'Rental',
    HomiziRole.host => 'Host',
    HomiziRole.broker => 'Broker',
  };
}

/// Current product role. Null until a person picks one, including a legacy
/// `unset` account.
final currentRoleProvider = Provider<HomiziRole?>((ref) {
  final session = ref.watch(sessionProvider);
  final stored = homiziRoleFromWire(session.homiziWire);
  if (stored != null) {
    return stored;
  }
  final legacy = session.role;
  if (legacy == null) {
    return null;
  }
  return homiziRoleFromLegacy(usersPrimaryRole: accountRoleWire(legacy));
});
