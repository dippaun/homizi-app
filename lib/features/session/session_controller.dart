import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/auth/magic_link.dart';
import 'package:homizi/features/session/session_state.dart';

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController extends Notifier<SessionState> {
  bool _codeSignIn = false;

  @override
  SessionState build() => const SessionState.booting();

  Future<void> finishBoot() async {
    if (state.phase != SessionPhase.booting) {
      return;
    }
    final restored = await ref
        .read(accountGatewayProvider)
        .restore(policyVersion: ref.read(appConfigProvider).policyVersion);
    if (state.phase != SessionPhase.booting) {
      return;
    }
    if (restored == null) {
      state = state.copyWith(phase: SessionPhase.signedOut);
      return;
    }
    state = _fromSnapshot(restored);
  }

  /// Records the draft policy. A signed-in Supabase user also stores it.
  Future<String?> acceptConsent() async {
    final version = ref.read(appConfigProvider).policyVersion;
    if (state.userId != null) {
      try {
        await ref
            .read(accountGatewayProvider)
            .recordConsent(policyVersion: version);
      } on AccountFailure catch (error) {
        return error.message;
      }
      state = state.copyWith(
        policyVersion: version,
        phase: state.role == null ? SessionPhase.needsRole : SessionPhase.ready,
      );
      return null;
    }
    final nextPhase = state.phase == SessionPhase.needsConsent
        ? SessionPhase.signedOut
        : state.phase;
    state = state.copyWith(policyVersion: version, phase: nextPhase);
    return null;
  }

  /// Asks staging to email a magic link. Phone numbers are refused.
  /// A 6-digit code can still be entered later if the email includes one.
  Future<String?> requestEmailCode(String contact) async {
    final config = ref.read(appConfigProvider);
    if (!config.usesHostedEmailOtp) {
      return 'A sign-in email is sent only for the staging project.';
    }
    final parsed = parseAuthContact(contact);
    if (parsed == null || parsed.usesSyntheticEmail) {
      return 'Phone SMS is not connected on staging. Enter an email address. No SMS was sent.';
    }
    if (!state.hasConsent) {
      state = state.copyWith(phase: SessionPhase.needsConsent);
      return 'Accept the terms and privacy notice before signing in.';
    }
    try {
      await ref
          .read(accountGatewayProvider)
          .requestEmailOtp(
            email: parsed.email!,
            emailRedirectTo: magicLinkRedirect,
          );
    } on AccountFailure catch (error) {
      return error.message;
    }
    return null;
  }

  /// Turns a magic-link auth session into the app session.
  ///
  /// supabase_flutter exchanges the redirect. This loads consent and the
  /// profile. A typed code uses [signIn] instead, so this returns when that
  /// path already owns the session.
  Future<void> adoptMagicLinkSession() async {
    if (_codeSignIn || state.userId != null) {
      return;
    }
    if (!ref.read(appConfigProvider).usesHostedEmailOtp) {
      return;
    }
    final config = ref.read(appConfigProvider);
    try {
      final snapshot = await ref
          .read(accountGatewayProvider)
          .adoptMagicLinkSession(
            policyVersion: state.policyVersion ?? config.policyVersion,
            recordConsent: state.hasConsent,
          );
      if (snapshot == null || _codeSignIn || state.userId != null) {
        return;
      }
      state = _fromSnapshot(snapshot);
    } on AccountFailure {
      // The code field stays available if the link did not finish.
    }
  }

  /// Returns an error message, or null when the session is accepted.
  /// Development OTP is [AppConfig.devOtp] and is rejected in prod.
  /// Staging with Supabase verifies a typed email code. The magic link uses
  /// [adoptMagicLinkSession]. Demo mode sends nothing.
  Future<String?> signIn({
    required String contact,
    required String code,
  }) async {
    final config = ref.read(appConfigProvider);
    final parsed = parseAuthContact(contact);
    if (parsed == null) {
      return 'Enter a valid email or a 10-digit Indian mobile number.';
    }
    if (!state.hasConsent) {
      state = state.copyWith(phase: SessionPhase.needsConsent);
      return 'Accept the terms and privacy notice before signing in.';
    }
    if (config.usesHostedEmailOtp) {
      if (parsed.usesSyntheticEmail) {
        return 'Phone SMS is not connected on staging. Enter an email address. No SMS was sent.';
      }
      _codeSignIn = true;
      try {
        final snapshot = await ref
            .read(accountGatewayProvider)
            .verifyEmailOtp(
              email: parsed.email!,
              code: code.trim(),
              policyVersion: state.policyVersion!,
            );
        state = _fromSnapshot(snapshot);
      } on AccountFailure catch (error) {
        return error.message;
      } finally {
        _codeSignIn = false;
      }
      return null;
    }
    if (!config.allowsDevOtp) {
      return 'The development code is refused in production. Sign-in is not connected to an OTP provider in this build.';
    }
    if (code.trim() != AppConfig.devOtp) {
      return 'That code is not valid. In development, use the code shown on this screen.';
    }
    try {
      final snapshot = await ref
          .read(accountGatewayProvider)
          .signInDev(contact: parsed, policyVersion: state.policyVersion!);
      state = _fromSnapshot(snapshot);
    } on AccountFailure catch (error) {
      return error.message;
    }
    return null;
  }

  Future<String?> selectRole(AccountRole role) async {
    try {
      await ref.read(accountGatewayProvider).setRole(role);
    } on AccountFailure catch (error) {
      return error.message;
    }
    state = state.copyWith(role: role, phase: SessionPhase.ready);
    return null;
  }

  Future<void> signOut() async {
    await ref.read(accountGatewayProvider).signOut();
    state = SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: state.policyVersion,
    );
  }

  /// Clears the in-app session after [AccountGateway.deleteAccount] succeeds.
  void completeAccountDeletion() {
    state = SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: state.policyVersion,
    );
  }
}

SessionState _fromSnapshot(AccountSnapshot snapshot) {
  final consented =
      snapshot.policyVersion != null && snapshot.policyVersion!.isNotEmpty;
  final phase = !consented
      ? SessionPhase.needsConsent
      : snapshot.role == null
      ? SessionPhase.needsRole
      : SessionPhase.ready;
  return SessionState(
    phase: phase,
    contact: snapshot.contact,
    role: snapshot.role,
    policyVersion: snapshot.policyVersion,
    userId: snapshot.userId,
  );
}
