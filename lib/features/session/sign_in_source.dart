import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

/// Whether header, bottom nav, and Profile treat the person as signed in.
///
/// Two inputs land in [sessionProvider], and this is the only flag the chrome
/// watches:
/// - the Supabase auth session, restored on boot and updated from
///   `auth.onAuthStateChange` (see `listenForMagicLinkSession`)
/// - the staging demo session for `test5@homizi.in` / `000000`, including the
///   copy kept in shared_preferences across reloads
///
/// [SessionPhase.needsRole] still counts: the demo login has a session before
/// a role is chosen. [SessionPhase.needsConsent] counts only after an account
/// exists. A cold boot with neither session stays signed out.
bool sessionIsSignedIn(SessionState session) {
  return switch (session.phase) {
    SessionPhase.ready || SessionPhase.needsRole => true,
    SessionPhase.needsConsent =>
      session.userId != null || session.contact.trim().isNotEmpty,
    SessionPhase.booting || SessionPhase.signedOut => false,
  };
}

final signedInProvider = Provider<bool>((ref) {
  return sessionIsSignedIn(ref.watch(sessionProvider));
});
