import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/supabase_account_gateway.dart';
import 'package:homizi/features/auth/magic_link.dart';
import 'package:homizi/features/session/session_state.dart';

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController extends Notifier<SessionState> {
  bool _codeSignIn = false;

  bool _hostedEmail() {
    if (ref.read(forceDemoModeProvider)) {
      return false;
    }
    return ref.read(appConfigProvider).usesHostedEmailOtp;
  }

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

  /// Asks staging to email a 6-digit code. Phone numbers are refused.
  /// The request does not set a redirect. A link in the email is only a
  /// fallback, adopted by [adoptMagicLinkSession].
  Future<String?> requestEmailCode(String contact) async {
    if (!_hostedEmail()) {
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
          .requestEmailOtp(email: parsed.email!);
    } on AccountFailure catch (error) {
      return error.message;
    }
    return null;
  }

  /// Turns a magic-link auth session into the app session.
  ///
  /// This is the fallback when the email contains a link. supabase_flutter
  /// exchanges the redirect. A typed code uses [signIn] instead, so this
  /// returns when that path already owns the session.
  Future<void> adoptMagicLinkSession() async {
    if (_codeSignIn || state.userId != null) {
      return;
    }
    if (!_hostedEmail()) {
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
  /// Staging with Supabase verifies a typed 6-digit email code. A link in
  /// the email uses [adoptMagicLinkSession]. Demo mode sends nothing.
  /// The throwaway mailbox [AppConfig.stagingTestEmail] with
  /// [AppConfig.stagingTestCode] uses the staging test password. A
  /// `qa+…@homizi.in` mailbox with that same code creates the user when
  /// missing, then signs in. Production never takes either path.
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
    if (_hostedEmail()) {
      if (parsed.usesSyntheticEmail) {
        return 'Phone SMS is not connected on staging. Enter an email address. No SMS was sent.';
      }
      final trimmed = code.trim();
      if (_stagingTestLogin(parsed.email!, trimmed)) {
        return _signInStagingTest();
      }
      if (_stagingQaLogin(parsed.email!, trimmed)) {
        return _signInStagingQa(parsed.email!);
      }
      if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
        return 'Enter the 6-digit code from the email. No session was started.';
      }
      _codeSignIn = true;
      try {
        final snapshot = await ref
            .read(accountGatewayProvider)
            .verifyEmailOtp(
              email: parsed.email!,
              code: trimmed,
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

  /// Production ignores this even when the define is present.
  bool _stagingTestLogin(String email, String code) {
    final config = ref.read(appConfigProvider);
    if (config.environment != AppEnvironment.staging ||
        !config.allowsStagingTestLogin) {
      return false;
    }
    return email.trim().toLowerCase() == AppConfig.stagingTestEmail &&
        code == AppConfig.stagingTestCode;
  }

  /// A fresh staging mailbox. Production is false because the test password
  /// is cleared outside staging, and the code must be [AppConfig.stagingTestCode].
  bool _stagingQaLogin(String email, String code) {
    final config = ref.read(appConfigProvider);
    if (config.environment != AppEnvironment.staging ||
        !config.allowsStagingTestLogin) {
      return false;
    }
    return code == AppConfig.stagingTestCode && isStagingQaEmail(email);
  }

  /// Signs in the throwaway staging mailbox with [AppConfig.stagingTestPassword].
  /// The gateway then calls `ensure_own_account`.
  Future<String?> _signInStagingTest() async {
    final password = ref.read(appConfigProvider).stagingTestPassword;
    if (password.isEmpty) {
      return 'The staging test login is not configured in this build. No session was started.';
    }
    _codeSignIn = true;
    try {
      final snapshot = await ref
          .read(accountGatewayProvider)
          .signInWithPasswordAccount(
            email: AppConfig.stagingTestEmail,
            password: password,
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

  /// Creates the qa mailbox when it is missing, then signs in with the
  /// throwaway staging password. The role stays unset, so the role picker opens.
  Future<String?> _signInStagingQa(String email) async {
    final password = ref.read(appConfigProvider).stagingTestPassword;
    if (password.isEmpty) {
      return 'The staging test login is not configured in this build. No session was started.';
    }
    final mailbox = email.trim().toLowerCase();
    _codeSignIn = true;
    try {
      final gateway = ref.read(accountGatewayProvider);
      await gateway.ensureStagingTestUser(email: mailbox);
      final snapshot = await gateway.signInWithPasswordAccount(
        email: mailbox,
        password: password,
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

  /// Staging email and password. The password is not logged or stored here.
  Future<String?> signInWithStagingPassword({
    required String contact,
    required String password,
    required bool createAccount,
  }) async {
    final config = ref.read(appConfigProvider);
    if (!_hostedEmail() || !config.allowsStagingPassword) {
      return 'Password sign-in is only for staging with the flag on.';
    }
    final parsed = parseAuthContact(contact);
    if (parsed == null || parsed.usesSyntheticEmail) {
      return 'Phone SMS is not connected on staging. Enter an email address. No SMS was sent.';
    }
    if (!state.hasConsent) {
      state = state.copyWith(phase: SessionPhase.needsConsent);
      return 'Accept the terms and privacy notice before signing in.';
    }
    if (password.length < 8) {
      return 'Choose a password of at least 8 characters. It is not logged.';
    }
    if (password == devFixturePassword) {
      return 'That password is reserved for local development. Choose another. No account was changed.';
    }
    try {
      final gateway = ref.read(accountGatewayProvider);
      final snapshot = createAccount
          ? await gateway.signUpWithPassword(
              email: parsed.email!,
              password: password,
              policyVersion: state.policyVersion!,
              emailRedirectTo: passwordSignupRedirect(isWeb: kIsWeb),
            )
          : await gateway.signInWithPasswordAccount(
              email: parsed.email!,
              password: password,
              policyVersion: state.policyVersion!,
            );
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
    state = state.copyWith(
      role: role,
      homiziWire: switch (role) {
        AccountRole.tenant => 'tenant',
        AccountRole.host => state.homiziWire == 'broker' ? 'broker' : 'host',
        AccountRole.both => 'tenant',
      },
      phase: SessionPhase.ready,
    );
    return null;
  }

  Future<void> signOut() async {
    await ref.read(accountGatewayProvider).signOut();
    state = SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: state.policyVersion,
    );
  }

  /// The auth client dropped the session (expiry with no refresh, or sign-out).
  /// Does not read or log a token.
  void noteRemoteSignOut() {
    if (state.phase == SessionPhase.booting) {
      return;
    }
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
