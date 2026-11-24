import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/storage/user_scope.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/account/supabase_account_gateway.dart';
import 'package:homizi/features/auth/auth_provider_settings.dart';
import 'package:homizi/features/auth/client_test_login.dart';
import 'package:homizi/features/auth/demo_login.dart';
import 'package:homizi/features/auth/demo_login_store.dart';
import 'package:homizi/features/auth/magic_link.dart';
import 'package:homizi/features/auth/oauth_redirect.dart';
import 'package:homizi/features/auth/otp/indian_phone.dart';
import 'package:homizi/features/auth/otp/otp_attempt.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:homizi/features/auth/otp/phone_otp_channel.dart';
import 'package:homizi/features/auth/registration_gate.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/session/demo_session_store.dart';
import 'package:homizi/features/session/session_state.dart';

/// Dedicated staging mailbox for a `PHONE_TEST_NUMBERS` sign-in.
///
/// `staging_create_test_user` accepts this `qa+` address. It is not
/// `test5@homizi.in`, which stays an on-device demo with no Supabase session.
const stagingPhoneTestMailbox = 'qa+phone9999999999@homizi.in';

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Set by sign-out. The router sends the next page to Home, then clears it.
class SignOutHomeController extends Notifier<bool> {
  @override
  bool build() => false;

  void arm() => state = true;

  void clear() => state = false;
}

final signOutHomeProvider = NotifierProvider<SignOutHomeController, bool>(
  SignOutHomeController.new,
);

class SessionController extends Notifier<SessionState> {
  bool _codeSignIn = false;
  Future<void>? _demoEntry;

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
    if (!UserScope.claimed) {
      final stillBooting = state.phase == SessionPhase.booting;
      await UserScope.noteBoot(stillBooting ? restored?.userId : null);
    }
    if (state.phase != SessionPhase.booting) {
      return;
    }
    if (restored == null) {
      if (ref.read(appConfigProvider).demoSkipLogin) {
        await startDemoSession();
        return;
      }
      if (await _restorePersistedDemo()) {
        return;
      }
      state = state.copyWith(phase: SessionPhase.signedOut);
      return;
    }
    await ref.read(demoSessionStoreProvider).clear();
    state = _fromSnapshot(restored);
    if (state.phase == SessionPhase.needsConsent) {
      await acceptConsent();
    }
    await _continueGoogleNewcomer(restored);
    if (ref.read(appConfigProvider).demoSkipLogin &&
        state.phase != SessionPhase.ready) {
      await startDemoSession();
    }
  }

  /// A Google account with a profiles row and no role opens Home as a tenant.
  /// Email and phone sign-in keep the existing role step.
  Future<void> _continueGoogleNewcomer(AccountSnapshot snapshot) async {
    if (state.phase != SessionPhase.needsRole || !snapshot.googleSignIn) {
      return;
    }
    await selectPrimaryRole('tenant');
  }

  /// Google OAuth. Redirects to [homiziOAuthRedirect]. A missing provider
  /// returns [googleSignInUnavailable]. Null means Google opened.
  Future<String?> signInWithGoogle() async {
    final consentError = await _acceptTermsForSignIn();
    if (consentError != null) {
      return consentError;
    }
    try {
      final snapshot = await ref
          .read(accountGatewayProvider)
          .signInWithGoogle(
            policyVersion: state.policyVersion!,
            redirectTo: homiziOAuthRedirect,
          );
      if (snapshot == null) {
        return null;
      }
      state = _fromSnapshot(snapshot);
      await _continueGoogleNewcomer(snapshot);
    } on AccountFailure catch (error) {
      return error.message;
    }
    return null;
  }

  /// Silent demo sign-in. A usable staging password opens `qa+role@homizi.in`
  /// so Supabase RLS applies. Otherwise the on-device demo session is used.
  /// Login screens stay in the app when [AppConfig.demoSkipLogin] is off.
  Future<void> startDemoSession({String roleWire = 'tenant'}) async {
    final config = ref.read(appConfigProvider);
    state = state.copyWith(policyVersion: config.policyVersion);
    if (config.hasUsableStagingPassword) {
      final error = await _signInStagingQa(demoRoleEmail(roleWire));
      if (error == null && state.userId != null) {
        final wire = state.homiziWire;
        if (wire == null || wire.isEmpty) {
          await selectPrimaryRole(roleWire);
        }
        return;
      }
    }
    ref.read(forceDemoModeProvider.notifier).setEnabled(true);
    final snapshot = await ref
        .read(accountGatewayProvider)
        .signInDev(
          contact: AuthContact.email(demoRoleEmail(roleWire)),
          policyVersion: config.policyVersion,
        );
    state = _fromSnapshot(snapshot);
    await selectPrimaryRole(roleWire);
  }

  /// Same switch as "Use demo mode", then the on-device sign-in that follows it.
  ///
  /// Staging web calls this instead of showing the sign-in screen. A role is
  /// still unset, so the chooser opens. Later calls do nothing once a demo
  /// session exists.
  Future<void> enterForcedDemo() {
    ref.read(forceDemoModeProvider.notifier).setEnabled(true);
    if (state.phase == SessionPhase.needsRole ||
        state.phase == SessionPhase.ready) {
      _demoEntry = null;
      return Future<void>.value();
    }
    if (state.phase == SessionPhase.booting) {
      return Future<void>.value();
    }
    return _demoEntry ??= _enterForcedDemo();
  }

  Future<void> _enterForcedDemo() async {
    if (!state.hasConsent) {
      await acceptConsent();
    }
    if (state.phase != SessionPhase.signedOut) {
      return;
    }
    await signIn(contact: 'demo@homizi.in', code: AppConfig.devOtp);
  }

  /// Splash Search tiles call this so the session reaches [SessionPhase.ready]
  /// with a role matching the chosen path. [enterForcedDemo] alone leaves
  /// [SessionPhase.needsRole], which made the splash show "Could not open
  /// the demo." Prefers the on-device demo session so WebKit (iPhone Chrome)
  /// storage or staging network failures cannot block the four Search tiles.
  Future<void> openSplashDemo({required String roleWire}) async {
    final wire = isHomiziRoleWire(roleWire) ? roleWire : 'tenant';
    try {
      await finishBoot();
    } on Object {
      // Restore can throw when web storage is blocked. Continue into demo.
    }
    if (state.phase == SessionPhase.ready && state.homiziWire == wire) {
      return;
    }
    try {
      await _forceOnDeviceDemo(roleWire: wire);
    } on Object {
      // Last resort: startDemoSession still falls back to on-device when
      // staging password sign-in fails.
      await startDemoSession(roleWire: wire);
    }
    if (state.phase != SessionPhase.ready) {
      await startDemoSession(roleWire: wire);
    }
  }

  Future<void> _forceOnDeviceDemo({required String roleWire}) async {
    final config = ref.read(appConfigProvider);
    ref.read(forceDemoModeProvider.notifier).setEnabled(true);
    state = state.copyWith(policyVersion: config.policyVersion);
    if (!state.hasConsent) {
      await acceptConsent();
    }
    final snapshot = await ref
        .read(accountGatewayProvider)
        .signInDev(
          contact: AuthContact.email(demoRoleEmail(roleWire)),
          policyVersion: config.policyVersion,
        );
    state = _fromSnapshot(snapshot);
    await selectPrimaryRole(roleWire);
  }

  /// Records the draft policy the same way the old welcome checkbox did.
  ///
  /// Sign-in calls this before the account request so a missing checkbox
  /// cannot bounce the person back to the intro screen.
  Future<String?> _acceptTermsForSignIn() async {
    if (state.hasConsent) {
      return null;
    }
    return acceptConsent();
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
    final consentError = await _acceptTermsForSignIn();
    if (consentError != null) {
      return consentError;
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
    if (_codeSignIn) {
      return;
    }
    if (!_hostedEmail()) {
      return;
    }
    if (!state.hasConsent) {
      final error = await acceptConsent();
      if (error != null) {
        return;
      }
    }
    final config = ref.read(appConfigProvider);
    try {
      final snapshot = await ref
          .read(accountGatewayProvider)
          .adoptMagicLinkSession(
            policyVersion: state.policyVersion ?? config.policyVersion,
            recordConsent: state.hasConsent,
          );
      if (snapshot == null || _codeSignIn) {
        return;
      }
      if (snapshot.userId != null && snapshot.userId == state.userId) {
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
  /// `qa+…@homizi.in` mailbox, or `test<N>@homizi.in` for N from 1 to 9999,
  /// with that same code creates the user when missing, then signs in.
  /// [clientTestDemoEmail] with [clientTestDemoCode] is the exception: outside
  /// production it opens an on-device demo session and does not call Supabase.
  /// Production never takes any of these paths.
  Future<String?> signIn({
    required String contact,
    required String code,
  }) async {
    final config = ref.read(appConfigProvider);
    final parsed = parseAuthContact(contact);
    if (parsed == null) {
      return 'Enter a valid email or a 10-digit Indian mobile number.';
    }
    final consentError = await _acceptTermsForSignIn();
    if (consentError != null) {
      return consentError;
    }
    if (parsed.email != null &&
        config.environment != AppEnvironment.prod &&
        isClientTestDemoAccount(parsed.email!, code)) {
      return _signInClientTestDemo(parsed);
    }
    if (_hostedEmail()) {
      final trimmed = code.trim();
      if (parsed.usesSyntheticEmail) {
        return _signInHostedPhone(parsed.phoneE164!, trimmed);
      }
      if (config.environment == AppEnvironment.prod &&
          trimmed == AppConfig.devOtp) {
        return productionDevOtpMessage;
      }
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
    if (parsed.usesSyntheticEmail) {
      return phoneCodesUnavailableMessage;
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

  /// Keeps a profile-wizard email proof on the session.
  ///
  /// A signed-out person who confirms a code becomes signed in. An existing
  /// role and consent are kept when the snapshot does not carry them.
  void adoptVerifiedContact(AccountSnapshot snapshot) {
    final userId = snapshot.userId;
    final hasUser = userId != null && userId.isNotEmpty;
    final contact = snapshot.contact.trim();
    state = state.copyWith(
      userId: hasUser ? userId : null,
      contact: contact.isEmpty ? state.contact : contact,
      emailVerified: snapshot.emailVerified || state.emailVerified,
      phoneVerified: snapshot.phoneVerified || state.phoneVerified,
      phoneE164: snapshot.phoneE164.trim().isEmpty
          ? state.phoneE164
          : snapshot.phoneE164,
      policyVersion: snapshot.policyVersion ?? state.policyVersion,
      role: snapshot.role,
      homiziWire: snapshot.homiziWire,
    );
    if (!hasUser || state.phase != SessionPhase.signedOut) {
      return;
    }
    final consented = state.hasConsent;
    state = state.copyWith(
      phase: !consented
          ? SessionPhase.needsConsent
          : state.role == null
          ? SessionPhase.needsRole
          : SessionPhase.ready,
    );
  }

  /// Client-side test path. Only [clientTestDemoEmail] reaches this, and only
  /// outside production. The session stays on the device. Other emails still
  /// use hosted OTP or the staging password.
  Future<String?> _signInClientTestDemo(AuthContact contact) async {
    ref.read(forceDemoModeProvider.notifier).setEnabled(true);
    try {
      final snapshot = await ref
          .read(accountGatewayProvider)
          .signInDev(contact: contact, policyVersion: state.policyVersion!);
      state = _fromSnapshot(snapshot);
      await _rememberClientDemo();
    } on AccountFailure catch (error) {
      return error.message;
    }
    return null;
  }

  /// Testing login behind `DEMO_LOGIN`.
  ///
  /// [fresh] opens a new profile. Otherwise the last saved demo profile is
  /// opened. A hosted `qa+` mailbox is used when this build has a usable
  /// staging password. Otherwise the session stays on the device, the same
  /// way `test5@homizi.in` does. No code is sent.
  Future<String?> signInTestingDemo({
    required bool fresh,
    String enteredAs = '',
  }) async {
    final config = ref.read(appConfigProvider);
    if (!config.demoLogin) {
      return 'Demo login is off in this build. No session was started.';
    }
    final consentError = await _acceptTermsForSignIn();
    if (consentError != null) {
      return consentError;
    }
    final store = ref.read(demoLoginStoreProvider);
    final previous = fresh ? null : await store.read();
    if (!fresh && previous == null) {
      return 'No previous demo profile yet. Create a new one.';
    }
    final typed = enteredAs.trim().isEmpty
        ? previous?.enteredAs
        : enteredAs.trim();
    final record = fresh
        ? DemoLoginRecord(
            aliasEmail: newDemoAliasEmail(),
            userId: newDemoUserId(),
            enteredAs: typed,
          )
        : previous!.copyWith(enteredAs: typed);
    await store.write(record);
    ref.read(demoLoginActiveProvider.notifier).on();
    ref.read(demoEnteredContactProvider.notifier).set(record.enteredAs ?? '');
    if (fresh) {
      await ref.read(profileCreateStoreProvider).startFresh();
      ref.read(registrationBypassProvider.notifier).reset();
      ref.read(registrationHomePassProvider.notifier).consume();
    }
    if (config.hasUsableStagingPassword &&
        isStagingFreshTesterEmail(record.aliasEmail)) {
      final hosted = await _signInStagingQa(record.aliasEmail);
      if (hosted == null) {
        return null;
      }
    }
    return _openOnDeviceDemo(record, fresh: fresh);
  }

  Future<String?> _openOnDeviceDemo(
    DemoLoginRecord record, {
    required bool fresh,
  }) async {
    ref.read(forceDemoModeProvider.notifier).setEnabled(true);
    final gateway = ref.read(accountGatewayProvider);
    if (fresh && gateway is DemoAccountGateway) {
      gateway.resetForNewDemo();
    }
    final policy = state.policyVersion;
    if (policy == null || policy.isEmpty) {
      return 'Accept the terms and privacy notice before signing in.';
    }
    try {
      final snapshot = await gateway.signInDev(
        contact: AuthContact.email(record.aliasEmail),
        policyVersion: policy,
      );
      var next = _fromSnapshot(snapshot).copyWith(userId: record.userId);
      if (!fresh) {
        final name = record.displayName?.trim() ?? '';
        if (name.length >= 2) {
          await gateway.saveTenantProfile(TenantProfile(displayName: name));
        }
        final wire = record.homiziWire;
        if (wire != null && isHomiziRoleWire(wire)) {
          await gateway.setPrimaryRole(wire);
          next = next.copyWith(
            role: accountRoleForPrimaryWire(wire),
            homiziWire: wire,
            phase: SessionPhase.ready,
          );
        }
      }
      state = next;
    } on AccountFailure catch (error) {
      return error.message;
    }
    return null;
  }

  Future<void> _rememberDemoLogin() async {
    if (!ref.read(demoLoginActiveProvider)) {
      return;
    }
    final store = ref.read(demoLoginStoreProvider);
    final current = await store.read();
    if (current == null) {
      return;
    }
    String? name = current.displayName;
    try {
      final saved = await ref.read(accountGatewayProvider).loadTenantProfile();
      if (saved.displayName.trim().length >= 2) {
        name = saved.displayName.trim();
      }
    } on Object {
      // Keep the name already stored for this demo profile.
    }
    await store.write(
      current.copyWith(
        displayName: name,
        homiziWire: state.homiziWire ?? current.homiziWire,
        userId: state.userId ?? current.userId,
      ),
    );
  }

  /// SMS sign-in for a mobile that is already verified. Does not create a user.
  Future<String?> _signInHostedPhone(String phoneE164, String code) async {
    if (code.trim() == AppConfig.devOtp) {
      return phoneDevCodeRefusedMessage;
    }
    if (!isSixDigitCode(code)) {
      return 'Enter the 6-digit code from the message. No session was started.';
    }
    _codeSignIn = true;
    try {
      final snapshot = await ref
          .read(accountGatewayProvider)
          .verifyPhoneSignIn(
            phoneE164: phoneE164,
            code: code,
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

  /// Staging `PHONE_TEST_NUMBERS` code for [phone], or null.
  ///
  /// Production and dev always return null, so a real SMS path is unchanged.
  String? _stagingPhoneTestCode(String phone) {
    final config = ref.read(appConfigProvider);
    if (config.environment != AppEnvironment.staging) {
      return null;
    }
    return config.phoneTestCode(phone);
  }

  /// True only when this project will actually text a code.
  ///
  /// Email OTP being connected is not enough. Staging has email on and
  /// `external.phone` off. A phone send in that state returns 422
  /// `otp_disabled` ("Signups not allowed for otp") because the call uses
  /// `shouldCreateUser: false` and no SMS provider is configured.
  Future<bool> _phoneSmsEnabled() async {
    final config = ref.read(appConfigProvider);
    if (!config.usesHostedPhoneOtp || ref.read(forceDemoModeProvider)) {
      return false;
    }
    await ref.read(authProviderSettingsProvider.notifier).load();
    return ref.read(authProviderSettingsProvider).phone;
  }

  /// Asks Auth to send a code on [channel]. [link] attaches the number to the
  /// signed-in user. A sign-in sends to a number that is already verified and
  /// does not create a user. `000000` is not a phone code.
  Future<String?> requestPhoneCode(
    String raw, {
    required bool link,
    PhoneOtpChannel channel = PhoneOtpChannel.sms,
  }) async {
    final phone = indianMobileE164(raw);
    if (phone == null) {
      return indianMobileInvalidMessage;
    }
    if (link && state.userId == null) {
      return 'Sign in before verifying a mobile number.';
    }
    if (!link) {
      final consentError = await _acceptTermsForSignIn();
      if (consentError != null) {
        return consentError;
      }
    }
    // Staging test numbers never call Twilio, on Verify Contact or on sign-in.
    if (_stagingPhoneTestCode(phone) != null) {
      return null;
    }
    if (!await _phoneSmsEnabled()) {
      return link
          ? phoneCodesUnavailableMessage
          : phoneSignInUnavailableMessage;
    }
    final delivery = phoneDeliveryChannel(channel);
    try {
      final gateway = ref.read(accountGatewayProvider);
      if (link) {
        await gateway.requestPhoneChange(phoneE164: phone, channel: delivery);
      } else {
        await gateway.requestPhoneSignIn(phoneE164: phone, channel: delivery);
      }
    } on AccountFailure catch (error) {
      return error.message;
    }
    return null;
  }

  /// Checks the code from [requestPhoneCode].
  Future<String?> verifyPhoneCode({
    required String raw,
    required String code,
    required bool link,
  }) async {
    final phone = indianMobileE164(raw);
    if (phone == null) {
      return indianMobileInvalidMessage;
    }
    final config = ref.read(appConfigProvider);
    final expected = _stagingPhoneTestCode(phone);
    if (expected != null) {
      if (code.trim() != expected) {
        return incorrectOtpMessage;
      }
      if (link) {
        if (state.userId == null) {
          return 'Sign in before verifying a mobile number.';
        }
        try {
          await ref
              .read(accountGatewayProvider)
              .confirmStagingTestPhone(
                phoneE164: phone,
                policyVersion: state.policyVersion ?? config.policyVersion,
              );
        } on AccountFailure catch (error) {
          return error.message;
        }
        state = state.copyWith(phoneVerified: true, phoneE164: phone);
        return null;
      }
      return _signInStagingPhoneTest(phone);
    }
    if (code.trim() == AppConfig.devOtp) {
      return phoneDevCodeRefusedMessage;
    }
    if (!await _phoneSmsEnabled()) {
      return link
          ? phoneCodesUnavailableMessage
          : phoneSignInUnavailableMessage;
    }
    if (!isSixDigitCode(code)) {
      return 'Enter the 6-digit code from the message. No session was started.';
    }
    try {
      final gateway = ref.read(accountGatewayProvider);
      final snapshot = link
          ? await gateway.verifyPhoneChange(
              phoneE164: phone,
              code: code.trim(),
              policyVersion: state.policyVersion ?? config.policyVersion,
            )
          : await gateway.verifyPhoneSignIn(
              phoneE164: phone,
              code: code.trim(),
              policyVersion: state.policyVersion!,
            );
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
    return code == AppConfig.stagingTestCode &&
        isStagingFreshTesterEmail(email);
  }

  /// Staging sign-in for a `PHONE_TEST_NUMBERS` mobile.
  ///
  /// The typed code is the paired test code (123456 for +919999999999). No SMS
  /// is sent. A real session is opened for [stagingPhoneTestMailbox] through
  /// `staging_create_test_user` and the staging test password, the same path
  /// as a `qa+` mailbox. `test5@homizi.in` is not used: that pair stays an
  /// on-device demo and never calls Supabase Auth. Production never reaches
  /// this because [AppConfig.phoneTestCode] is empty outside staging.
  Future<String?> _signInStagingPhoneTest(String phoneE164) async {
    final config = ref.read(appConfigProvider);
    if (config.environment != AppEnvironment.staging ||
        !config.allowsStagingTestLogin) {
      return phoneSignInUnavailableMessage;
    }
    final password = config.stagingTestPassword;
    final consentError = await _acceptTermsForSignIn();
    if (consentError != null) {
      return consentError;
    }
    final policy = state.policyVersion;
    if (policy == null || policy.isEmpty) {
      return 'Accept the terms and privacy notice before signing in.';
    }
    if (password.isEmpty) {
      return 'The staging test login is not configured in this build. No session was started.';
    }
    _codeSignIn = true;
    try {
      final gateway = ref.read(accountGatewayProvider);
      await gateway.ensureStagingTestUser(email: stagingPhoneTestMailbox);
      final snapshot = await gateway.signInWithPasswordAccount(
        email: stagingPhoneTestMailbox,
        password: password,
        policyVersion: policy,
      );
      state = _fromSnapshot(snapshot);
      try {
        final linked = await gateway.confirmStagingTestPhone(
          phoneE164: phoneE164,
          policyVersion: policy,
        );
        state = _fromSnapshot(
          linked,
        ).copyWith(phoneVerified: true, phoneE164: phoneE164);
      } on AccountFailure {
        state = state.copyWith(phoneVerified: true, phoneE164: phoneE164);
      }
    } on AccountFailure catch (error) {
      return error.message;
    } finally {
      _codeSignIn = false;
    }
    return null;
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

  /// Creates the fresh mailbox when it is missing, then signs in with the
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
    final consentError = await _acceptTermsForSignIn();
    if (consentError != null) {
      return consentError;
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
    await _rememberClientDemo();
    await _rememberDemoLogin();
    return null;
  }

  /// Saves `profiles.primary_role` and the matching legacy account role.
  Future<String?> selectPrimaryRole(String wire) async {
    final accountRole = accountRoleForPrimaryWire(wire);
    if (accountRole == null) {
      return 'Choose a role.';
    }
    try {
      await ref.read(accountGatewayProvider).setPrimaryRole(wire);
    } on AccountFailure catch (error) {
      return error.message;
    }
    state = state.copyWith(
      role: accountRole,
      homiziWire: wire,
      phase: SessionPhase.ready,
    );
    await _rememberClientDemo();
    await _rememberDemoLogin();
    return null;
  }

  Future<void> signOut() async {
    ref.read(demoLoginActiveProvider.notifier).off();
    await ref.read(demoSessionStoreProvider).clear();
    final demo = ref.read(forceDemoModeProvider);
    await ref.read(accountGatewayProvider).signOut();
    if (demo) {
      ref.read(forceDemoModeProvider.notifier).setEnabled(false);
      if (ref.read(appConfigProvider).connectsToSupabase) {
        try {
          await ref.read(accountGatewayProvider).signOut();
        } on Object {
          // The hosted client is not running here. The demo record is gone.
        }
      }
    }
    ref.read(signOutHomeProvider.notifier).arm();
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
    // Demo mode is on-device. A hosted auth event must not send it back to
    // the sign-in screen.
    if (ref.read(forceDemoModeProvider)) {
      return;
    }
    ref.read(signOutHomeProvider.notifier).arm();
    state = SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: state.policyVersion,
    );
  }

  /// Clears the in-app session after [AccountGateway.deleteAccount] succeeds.
  void completeAccountDeletion() {
    if (ref.read(forceDemoModeProvider)) {
      ref.read(forceDemoModeProvider.notifier).setEnabled(false);
    }
    unawaited(ref.read(demoSessionStoreProvider).clear());
    ref.read(signOutHomeProvider.notifier).arm();
    state = SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: state.policyVersion,
    );
  }

  /// Brings back the staging demo session after a reload when Supabase has
  /// no auth session. Returns false when nothing was stored.
  Future<bool> _restorePersistedDemo() async {
    final saved = await ref.read(demoSessionStoreProvider).read();
    if (state.phase != SessionPhase.booting) {
      return false;
    }
    if (saved == null) {
      return false;
    }
    ref.read(forceDemoModeProvider.notifier).setEnabled(true);
    final policy =
        saved.policyVersion ?? ref.read(appConfigProvider).policyVersion;
    final wire = isHomiziRoleWire(saved.homiziWire) ? saved.homiziWire : null;
    final role =
        accountRoleFromWire(saved.roleWire) ??
        (wire == null ? null : accountRoleForPrimaryWire(wire));
    state = SessionState(
      phase: role == null ? SessionPhase.needsRole : SessionPhase.ready,
      contact: saved.contact,
      role: role,
      homiziWire: wire,
      policyVersion: policy,
    );
    if (wire != null) {
      try {
        await ref.read(accountGatewayProvider).setPrimaryRole(wire);
      } on AccountFailure {
        // The session already carries the role. A gateway miss can retry.
      }
    }
    return true;
  }

  Future<void> _rememberClientDemo() async {
    if (state.contact.trim().toLowerCase() != clientTestDemoEmail) {
      return;
    }
    await ref
        .read(demoSessionStoreProvider)
        .write(
          PersistedDemoSession(
            contact: state.contact.trim(),
            policyVersion: state.policyVersion,
            roleWire: state.role == null ? null : accountRoleWire(state.role!),
            homiziWire: state.homiziWire,
          ),
        );
  }
}

String demoRoleEmail(String roleWire) {
  final suffix = roleWire == 'roommate' ? 'flatmate' : roleWire;
  return 'qa+$suffix@homizi.in';
}

/// Reloads a screen that cached the previous account when the auth user changes.
void reloadWhenUserChanges(WidgetRef ref, void Function() reload) {
  ref.listen(sessionProvider.select((session) => session.userId), (
    previous,
    next,
  ) {
    if (previous != next) {
      reload();
    }
  });
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
    homiziWire: snapshot.homiziWire,
    policyVersion: snapshot.policyVersion,
    userId: snapshot.userId,
    emailVerified: snapshot.emailVerified,
    phoneVerified: snapshot.phoneVerified,
    phoneE164: snapshot.phoneE164,
  );
}
