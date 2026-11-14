import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

/// True when publishing is allowed to proceed.
///
/// A ready account, a demo session, and a session that has not finished boot
/// can publish on this device. Only an explicit sign-out is sent to sign-in.
/// Override this provider in tests.
final signedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).phase != SessionPhase.signedOut;
});
