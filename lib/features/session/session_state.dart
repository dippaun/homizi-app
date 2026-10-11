enum SessionPhase { booting, signedOut, needsConsent, needsRole, ready }

/// One account may hold both roles. Primary role is still recorded.
/// Owner should confirm this at gate G-01.
enum AccountRole { tenant, host, both }

class SessionState {
  const SessionState({
    required this.phase,
    this.contact = '',
    this.role,
    this.policyVersion,
  });

  const SessionState.booting() : this(phase: SessionPhase.booting);

  final SessionPhase phase;
  final String contact;
  final AccountRole? role;
  final String? policyVersion;

  bool get hasConsent => policyVersion != null && policyVersion!.isNotEmpty;

  SessionState copyWith({
    SessionPhase? phase,
    String? contact,
    AccountRole? role,
    String? policyVersion,
    bool clearRole = false,
  }) {
    return SessionState(
      phase: phase ?? this.phase,
      contact: contact ?? this.contact,
      role: clearRole ? null : (role ?? this.role),
      policyVersion: policyVersion ?? this.policyVersion,
    );
  }
}
