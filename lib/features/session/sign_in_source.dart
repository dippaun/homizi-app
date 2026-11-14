import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

/// Whether header, bottom nav, and Profile treat the person as signed in.
///
/// This is [SessionState.hasAccount]. A Supabase auth session and the staging
/// demo session (`test5@homizi.in`, including the copy restored from the
/// device) both land on [SessionPhase.needsRole] or [SessionPhase.ready], so
/// [SessionState.hasAccount] already covers the demo. There is no second rule.
bool sessionIsSignedIn(SessionState session) => session.hasAccount;

final signedInProvider = Provider<bool>((ref) {
  return sessionIsSignedIn(ref.watch(sessionProvider));
});
