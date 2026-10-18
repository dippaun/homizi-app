enum SessionPhase { booting, signedOut, needsConsent, needsRole, ready }

/// One account may hold both roles. Primary role is still recorded.
/// Owner should confirm this at gate G-01.
enum AccountRole { tenant, host, both }

class SessionState {
  const SessionState({
    required this.phase,
    this.contact = '',
    this.role,
    this.homiziWire,
    this.policyVersion,
    this.userId,
  });

  const SessionState.booting() : this(phase: SessionPhase.booting);

  final SessionPhase phase;
  final String contact;
  final AccountRole? role;

  /// `profiles.primary_role` wire: roommate, tenant, host, or broker.
  final String? homiziWire;
  final String? policyVersion;

  /// Supabase auth user id. Null in demo mode.
  final String? userId;

  bool get hasConsent => policyVersion != null && policyVersion!.isNotEmpty;

  SessionState copyWith({
    SessionPhase? phase,
    String? contact,
    AccountRole? role,
    String? homiziWire,
    String? policyVersion,
    String? userId,
    bool clearRole = false,
    bool clearHomiziWire = false,
    bool clearUserId = false,
  }) {
    return SessionState(
      phase: phase ?? this.phase,
      contact: contact ?? this.contact,
      role: clearRole ? null : (role ?? this.role),
      homiziWire: clearHomiziWire ? null : (homiziWire ?? this.homiziWire),
      policyVersion: policyVersion ?? this.policyVersion,
      userId: clearUserId ? null : (userId ?? this.userId),
    );
  }
}

String accountRoleWire(AccountRole role) {
  return switch (role) {
    AccountRole.tenant => 'tenant',
    AccountRole.host => 'host',
    AccountRole.both => 'both',
  };
}

AccountRole? accountRoleFromWire(String? value) {
  return switch (value) {
    'tenant' => AccountRole.tenant,
    'host' => AccountRole.host,
    'both' => AccountRole.both,
    _ => null,
  };
}
