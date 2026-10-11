import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/session/session_state.dart';

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState.booting();

  void finishBoot() {
    if (state.phase == SessionPhase.booting) {
      state = state.copyWith(phase: SessionPhase.signedOut);
    }
  }

  void acceptConsent() {
    final version = ref.read(appConfigProvider).policyVersion;
    final nextPhase = state.phase == SessionPhase.needsConsent
        ? SessionPhase.signedOut
        : state.phase;
    state = state.copyWith(policyVersion: version, phase: nextPhase);
  }

  /// Returns an error message, or null when the mock session is accepted.
  /// Development OTP is [AppConfig.devOtp] and is rejected in prod.
  String? signIn({required String contact, required String code}) {
    final config = ref.read(appConfigProvider);
    final trimmed = contact.trim();
    if (!_validContact(trimmed)) {
      return 'Enter a valid email or a 10-digit Indian mobile number.';
    }
    if (!state.hasConsent) {
      state = state.copyWith(phase: SessionPhase.needsConsent);
      return 'Accept the terms and privacy notice before signing in.';
    }
    if (!config.allowsDevOtp) {
      return 'Sign-in is not connected to an authentication provider in this build.';
    }
    if (code.trim() != AppConfig.devOtp) {
      return 'That code is not valid. In development, use the code shown on this screen.';
    }
    state = state.copyWith(
      contact: trimmed,
      phase: state.role == null ? SessionPhase.needsRole : SessionPhase.ready,
    );
    return null;
  }

  void selectRole(AccountRole role) {
    state = state.copyWith(role: role, phase: SessionPhase.ready);
  }

  void signOut() {
    state = SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: state.policyVersion,
    );
  }
}

bool _validContact(String value) {
  final email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (email.hasMatch(value)) {
    return true;
  }
  final digits = value.replaceAll(RegExp(r'[\s-]'), '');
  final phone = RegExp(r'^(?:\+91|91|0)?[6-9][0-9]{9}$');
  return phone.hasMatch(digits);
}
