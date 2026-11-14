import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/routing/sign_in_gate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/auth_failure.dart';
import 'package:homizi/features/auth/auth_contact_mode.dart';
import 'package:homizi/features/auth/auth_provider_settings.dart';
import 'package:homizi/features/auth/client_test_login.dart';
import 'package:homizi/features/auth/login_confirm.dart';
import 'package:homizi/features/auth/otp/captcha_token.dart';
import 'package:homizi/features/auth/otp/hcaptcha_field.dart';
import 'package:homizi/features/auth/otp/homizi_fields.dart';
import 'package:homizi/features/auth/otp/otp_attempt.dart';
import 'package:homizi/features/auth/otp/otp_code_field.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:homizi/features/broker/broker_auth.dart';
import 'package:homizi/features/host/host_intent.dart';
import 'package:homizi/features/roommates/flatmate_return.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/features/tenant/tenant_intent.dart';

enum _AuthPanel { closed, login, signup }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.previewCooldown = 0,
    this.previewCode = '',
    this.previewContact = '',
    this.googleTimeout = const Duration(seconds: 15),
  });

  /// Shows the resend clock and the six code boxes without sending a message.
  final int previewCooldown;
  final String previewCode;
  final String previewContact;

  /// How long "Opening Google…" stays before the retry sentence.
  final Duration googleTimeout;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _contact = TextEditingController();
  final _name = TextEditingController();
  final _scroll = ScrollController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  late final LoginConfirmHold _confirmHold;
  final _resend = ResendCountdown();
  final _attempts = OtpAttemptGate();
  var _panel = _AuthPanel.login;
  var _codeSent = false;
  var _stagingOpen = false;
  String? _error;
  _LoginField? _errorField;
  var _busy = false;
  var _confirmed = false;
  var _welcomeSignup = false;
  String _confirmedContact = '';
  var _testAccountConfirm = false;
  String? _signupRole;
  String? _intentNote;
  String? _googleNote;
  Timer? _timer;
  Timer? _googleTimer;

  @override
  void initState() {
    super.initState();
    _confirmHold = ref.read(loginConfirmHoldProvider.notifier);
    _contact.addListener(_refreshContactMode);
    if (widget.previewCooldown > 0) {
      _resend.remaining = widget.previewCooldown;
      _codeSent = true;
    }
    if (widget.previewCode.isNotEmpty) {
      _code.text = widget.previewCode;
    }
    if (widget.previewContact.isNotEmpty) {
      _contact.text = widget.previewContact;
    }
    if (widget.previewCooldown > 0 ||
        widget.previewCode.isNotEmpty ||
        widget.previewContact.isNotEmpty) {
      _panel = _AuthPanel.login;
    }
    final host = ref.read(hostIntentProvider).afterAuth;
    final tenant = ref.read(tenantIntentProvider) == TenantIntent.profile;
    final flatmate = ref.read(flatmateReturnProvider);
    if (host != null || tenant || (flatmate != null && flatmate.isNotEmpty)) {
      _panel = _AuthPanel.login;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final query = GoRouter.maybeOf(context)?.state.uri.queryParameters;
      final next = query?['next'];
      final safe = hostResumePath(next);
      if (safe != null && ref.read(hostIntentProvider).afterAuth != safe) {
        ref
            .read(hostIntentProvider.notifier)
            .remember(safe, afterProfile: RoutePaths.home);
      }
      final panel = query?['panel'];
      if (panel == 'signup') {
        setState(() => _panel = _AuthPanel.signup);
      } else if ((panel == 'login' || (next != null && next.isNotEmpty)) &&
          _panel == _AuthPanel.closed) {
        setState(() => _panel = _AuthPanel.login);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _googleTimer?.cancel();
    _scroll.dispose();
    _contact.removeListener(_refreshContactMode);
    _contact.dispose();
    _name.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _releaseHold() {
    try {
      _confirmHold.release();
    } on Exception catch (error) {
      if (!error.toString().contains('after it has been disposed')) {
        rethrow;
      }
    }
  }

  /// Leaves the confirmation for the screen that asked the person to sign in.
  void _continueHome() {
    _releaseHold();
    if (!mounted) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router == null || !sessionIsSignedIn(ref.read(sessionProvider))) {
      return;
    }
    final target =
        signInResumeTarget(router.state.uri.queryParameters['redirect']) ??
        signInResumeTarget(ref.read(signInReturnPathProvider));
    if (target == null) {
      return;
    }
    ref.read(signInReturnPathProvider.notifier).clear();
    router.go(target);
  }

  void _refreshContactMode() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onBack() {
    if (_confirmed) {
      _releaseHold();
      HomiziBackButton.leave(context);
      return;
    }
    if (_codeSent) {
      setState(() {
        _codeSent = false;
        _code.clear();
        _showError(null, _LoginField.contact);
      });
      return;
    }
    if (_panel == _AuthPanel.signup) {
      setState(() {
        _panel = _AuthPanel.login;
        _showError(null, _LoginField.contact);
      });
      return;
    }
    _releaseHold();
    HomiziBackButton.leave(context);
  }

  void _open(_AuthPanel panel) {
    setState(() {
      _panel = panel;
      _showError(null, _LoginField.contact);
      _googleNote = null;
    });
  }

  void _startCooldown() {
    _timer?.cancel();
    _attempts.reset();
    _codeSent = true;
    setState(_resend.start);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resend.tick();
        if (_resend.canResend) {
          timer.cancel();
        }
      });
    });
  }

  void _snack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(homiziText(context, friendlyAuthCopy(message)))),
    );
  }

  bool _isStagingTestMailbox(AppConfig config, String email) {
    if (config.environment != AppEnvironment.staging ||
        !config.allowsStagingTestLogin) {
      return false;
    }
    final normalized = email.trim().toLowerCase();
    return normalized == AppConfig.stagingTestEmail ||
        isStagingFreshTesterEmail(normalized);
  }

  Future<void> _requestCode() async {
    final reading = readAuthContact(_contact.text);
    if (reading.isPhone) {
      await _requestPhone(reading);
      return;
    }
    final email = reading.email?.trim() ?? '';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(
        () => _showError(
          'Enter a valid email or a 10-digit Indian mobile number.',
          _LoginField.contact,
        ),
      );
      return;
    }
    final config = ref.read(appConfigProvider);
    final hosted =
        config.usesHostedEmailOtp && !ref.read(forceDemoModeProvider);
    if (config.captchaEnabled && ref.read(captchaTokenProvider).isEmpty) {
      setState(() => _showError(captchaRequiredMessage, _LoginField.contact));
      return;
    }
    if (hosted && _isStagingTestMailbox(config, email)) {
      // Test mailboxes sign in with the staging test code, not an email.
      // Sending one here hits the Auth email rate limit and hid the code box.
      setState(() => _showError(null, _LoginField.contact));
      _startCooldown();
      _snack('Test account. Enter the test code. No email was sent.');
      return;
    }
    if (hosted) {
      setState(() {
        _busy = true;
        _showError(null, _LoginField.contact);
      });
      final error = await ref
          .read(sessionProvider.notifier)
          .requestEmailCode(_contact.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _showError(error, _LoginField.contact);
      });
      if (error == null) {
        _startCooldown();
        _snack('Code sent.');
      } else {
        _snack(error);
      }
      return;
    }
    if (!config.allowsDevOtp) {
      setState(() {
        _showError(
          'OTP delivery is not configured for production builds. No code was sent.',
          _LoginField.contact,
        );
      });
      return;
    }
    setState(() => _showError(null, _LoginField.contact));
    _startCooldown();
  }

  Future<void> _requestPhone(AuthContactReading reading) async {
    final phone = reading.phoneE164;
    if (phone == null) {
      setState(
        () => _showError(indianMobileInvalidMessage, _LoginField.contact),
      );
      return;
    }
    final config = ref.read(appConfigProvider);
    final hosted =
        config.usesHostedPhoneOtp && !ref.read(forceDemoModeProvider);
    setState(() {
      _busy = true;
      _showError(null, _LoginField.contact);
    });
    final error = await ref
        .read(sessionProvider.notifier)
        .requestPhoneCode(phone, link: false);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _showError(error, _LoginField.contact);
    });
    if (error == null) {
      _startCooldown();
      _snack(
        hosted
            ? 'Code sent.'
            : 'Enter the 6-digit code. No text message was sent.',
      );
    } else {
      _snack(error);
    }
  }

  Future<void> _passwordAuth(bool createAccount) async {
    setState(() {
      _busy = true;
      _confirmed = false;
      _welcomeSignup = false;
      _showError(null, _LoginField.password);
    });
    _confirmHold.hold();
    final error = await ref
        .read(sessionProvider.notifier)
        .signInWithStagingPassword(
          contact: _contact.text,
          password: _password.text,
          createAccount: createAccount,
        );
    if (!mounted) {
      return;
    }
    _applySignInResult(error, _LoginField.password);
  }

  Future<void> _createProfile() async {
    ref
        .read(hostIntentProvider.notifier)
        .remember(RoutePaths.hostProfile, afterProfile: RoutePaths.home);
    ref.read(flatmateReturnProvider.notifier).setPath(flatmateProfileNext);
    if (_contact.text.trim().isEmpty || _code.text.trim().isEmpty) {
      setState(() {
        _intentNote =
            'Sign in with your email and the 6-digit code. Your host profile opens next.';
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            homiziText(context, 'Sign in, then your flatmate profile opens.'),
          ),
        ),
      );
      return;
    }
    await _verify();
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _welcomeSignup = false;
      _googleNote = null;
      _showError(null, _LoginField.contact);
    });
    final error = await ref.read(sessionProvider.notifier).signInWithGoogle();
    if (!mounted) {
      return;
    }
    if (error != null) {
      _googleTimer?.cancel();
      setState(() {
        _busy = false;
        _googleNote = friendlyAuthCopy(error);
      });
      return;
    }
    final phase = ref.read(sessionProvider).phase;
    if (phase == SessionPhase.ready || phase == SessionPhase.needsRole) {
      setState(() {
        _busy = false;
        _confirmed = true;
        _welcomeSignup = false;
        _confirmedContact = ref.read(sessionProvider).contact;
        _testAccountConfirm = false;
      });
      _confirmHold.hold();
      return;
    }
    setState(() {
      _busy = false;
      _googleNote = googleOpeningMessage;
    });
    _googleTimer?.cancel();
    _googleTimer = Timer(widget.googleTimeout, () {
      if (!mounted || _confirmed || _googleNote != googleOpeningMessage) {
        return;
      }
      setState(() => _googleNote = googleRetryMessage);
    });
  }

  Future<void> _verify() async {
    if (_attempts.blocked) {
      setState(() => _showError(retryCapMessage, _LoginField.code));
      _snack(retryCapMessage);
      return;
    }
    final signingUp = _panel == _AuthPanel.signup;
    setState(() {
      _busy = true;
      _confirmed = false;
      _welcomeSignup = false;
      _showError(null, _LoginField.code);
    });
    _confirmHold.hold();
    final reading = readAuthContact(_contact.text);
    final error = reading.isPhone
        ? await ref
              .read(sessionProvider.notifier)
              .verifyPhoneCode(
                raw: _contact.text,
                code: _code.text,
                link: false,
              )
        : await ref
              .read(sessionProvider.notifier)
              .signIn(contact: _contact.text, code: _code.text);
    if (!mounted) {
      return;
    }
    if (error == null && signingUp) {
      await _saveSignupProfile();
    }
    if (!mounted) {
      return;
    }
    _applySignInResult(error, _LoginField.code, signup: signingUp);
  }

  Future<void> _saveSignupProfile() async {
    final name = _name.text.trim();
    if (name.length >= 2) {
      try {
        final gateway = ref.read(accountGatewayProvider);
        final current = await gateway.loadTenantProfile();
        await gateway.saveTenantProfile(current.copyWith(displayName: name));
      } on AccountFailure {
        // The session is already open. The profile can take the name later.
      }
    }
    final role = _signupRole;
    if (role != null && isHomiziRoleWire(role)) {
      await ref.read(sessionProvider.notifier).selectPrimaryRole(role);
    }
  }

  void _applySignInResult(
    String? error,
    _LoginField field, {
    bool signup = false,
  }) {
    if (error != null) {
      final lower = error.toLowerCase();
      if (lower.contains('incorrect') || lower.contains('expired')) {
        _attempts.recordFailure();
      }
      final shown = _attempts.blocked ? retryCapMessage : error;
      _releaseHold();
      setState(() {
        _busy = false;
        _showError(shown, field);
      });
      _snack(shown);
      return;
    }
    setState(() {
      _busy = false;
      _confirmed = true;
      _welcomeSignup = signup;
      _confirmedContact = _contact.text.trim();
      _testAccountConfirm = isClientTestDemoAccount(_contact.text, _code.text);
    });
  }

  Future<void> _continueInDemo() async {
    setState(() {
      _busy = true;
      _confirmed = false;
      _welcomeSignup = false;
      _showError(null, _LoginField.code);
    });
    _confirmHold.hold();
    await ref.read(sessionProvider.notifier).enterForcedDemo();
    if (!mounted) {
      return;
    }
    final phase = ref.read(sessionProvider).phase;
    final signedIn =
        phase == SessionPhase.needsRole || phase == SessionPhase.ready;
    if (!signedIn) {
      _releaseHold();
      setState(() {
        _busy = false;
        _showError(
          'Demo mode did not start. Try again from this screen.',
          _LoginField.code,
        );
      });
      return;
    }
    setState(() {
      _busy = false;
      _confirmed = true;
      _welcomeSignup = false;
      _confirmedContact = ref.read(sessionProvider).contact;
      _testAccountConfirm = false;
    });
  }

  void _showError(String? error, _LoginField action) {
    final friendly = error == null ? null : friendlyAuthCopy(error);
    _error = friendly;
    _errorField = friendly == null ? null : _fieldFor(friendly, action);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final demo = ref.watch(forceDemoModeProvider);
    final hosted = config.usesHostedEmailOtp && !demo;
    final showPassword = hosted && config.allowsStagingPassword;
    final providers = ref.watch(authProviderSettingsProvider);
    final showGoogle = providers.google;
    final stagingTools = config.environment != AppEnvironment.prod;
    final onContact = _errorField == _LoginField.contact;
    final onCode = _errorField == _LoginField.code;
    final onPassword = _errorField == _LoginField.password && showPassword;
    final onName = _errorField == _LoginField.name;
    final tied = onContact || onCode || onPassword || onName;
    String? fieldError(_LoginField field) {
      if (_error == null) {
        return null;
      }
      final selected = switch (field) {
        _LoginField.contact => onContact,
        _LoginField.code => onCode,
        _LoginField.password => onPassword,
        _LoginField.name => onName,
      };
      if (!selected) {
        return null;
      }
      return homiziText(context, _error!);
    }

    final creating = _panel == _AuthPanel.signup;
    final reading = readAuthContact(_contact.text);
    return MinTouchScope(
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        body: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PeachSkyline(),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: HomiziBackButton(onPressed: _onBack),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (current, previous) =>
                            current ?? const SizedBox.shrink(),
                        child: _confirmed
                            ? KeyedSubtree(
                                key: const ValueKey('auth-confirmed'),
                                child: creating || _welcomeSignup
                                    ? _SignupSuccess(
                                        onHome: _continueHome,
                                        contact: _confirmedContact,
                                      )
                                    : _WelcomeSuccess(
                                        contact: _confirmedContact,
                                        testAccount: _testAccountConfirm,
                                        onHome: _continueHome,
                                      ),
                              )
                            : SingleChildScrollView(
                                key: ValueKey(
                                  _codeSent ? 'auth-otp' : 'auth-form',
                                ),
                                controller: _scroll,
                                padding: const EdgeInsets.only(bottom: 88),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _BrandLockup(
                                      onLongPress: stagingTools
                                          ? () => setState(
                                              () => _stagingOpen = true,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(height: 20),
                                    GestureDetector(
                                      key: creating
                                          ? null
                                          : const Key('auth-open-login'),
                                      onTap: () => _open(_AuthPanel.login),
                                      child: Text(
                                        homiziText(
                                          context,
                                          creating
                                              ? 'Create account'
                                              : 'Sign in',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: HomiziColors.ink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      homiziText(
                                        context,
                                        creating
                                            ? 'One field. We send a code to confirm it is you.'
                                            : 'Find the place which you deserve',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: HomiziColors.inkSoft,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 240,
                                      ),
                                      layoutBuilder: (current, previous) =>
                                          current ?? const SizedBox.shrink(),
                                      child: _codeSent
                                          ? _otpCard(
                                              reading: reading,
                                              hosted: hosted,
                                              fieldError: fieldError,
                                            )
                                          : _entryCard(
                                              reading: reading,
                                              config: config,
                                              fieldError: fieldError,
                                            ),
                                    ),
                                    if (_error != null &&
                                        !onPassword &&
                                        !tied) ...[
                                      const SizedBox(height: 12),
                                      LiveNotice(
                                        key: const Key('login-error'),
                                        message: homiziText(context, _error!),
                                        isError: true,
                                      ),
                                    ] else if (_error != null && !onPassword)
                                      LiveLabel(
                                        key: const Key('login-error'),
                                        message: homiziText(context, _error!),
                                      ),
                                    if (!_codeSent) ...[
                                      const SizedBox(height: 18),
                                      const _OrDivider(),
                                      const SizedBox(height: 14),
                                      _googleButton(showGoogle: showGoogle),
                                      if (_googleNote != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          key: const Key('google-sign-in-note'),
                                          homiziText(context, _googleNote!),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: HomiziColors.inkSoft,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      creating
                                          ? TextButton(
                                              key: const Key('auth-open-login'),
                                              onPressed: () =>
                                                  _open(_AuthPanel.login),
                                              child: Text(
                                                homiziText(
                                                  context,
                                                  'Already on HOMIZI? Sign in',
                                                ),
                                                style: const TextStyle(
                                                  color: HomiziColors.ink,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            )
                                          : TextButton(
                                              key: const Key(
                                                'auth-open-signup',
                                              ),
                                              onPressed: () =>
                                                  _open(_AuthPanel.signup),
                                              child: Text(
                                                homiziText(
                                                  context,
                                                  'New to HOMIZI? Create account',
                                                ),
                                                style: const TextStyle(
                                                  color: HomiziColors.ink,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                      const SizedBox(height: 4),
                                      const _LegalLine(),
                                    ],
                                    if (ref.watch(tenantIntentProvider) ==
                                        TenantIntent.profile) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        key: const Key(
                                          'tenant-profile-signin-prompt',
                                        ),
                                        homiziText(
                                          context,
                                          'Sign in to create your tenant profile.',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: HomiziColors.inkSoft,
                                        ),
                                      ),
                                    ],
                                    if (stagingTools) ...[
                                      const SizedBox(height: 8),
                                      Center(
                                        child: TextButton(
                                          key: const Key('staging-tools-link'),
                                          onPressed: () => setState(
                                            () => _stagingOpen = !_stagingOpen,
                                          ),
                                          child: Text(
                                            homiziText(
                                              context,
                                              config.environment ==
                                                      AppEnvironment.staging
                                                  ? 'Staging tools'
                                                  : 'Development tools',
                                            ),
                                            style: const TextStyle(
                                              color: HomiziColors.muted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_stagingOpen)
                                        _stagingPanel(
                                          config: config,
                                          demo: demo,
                                          showPassword: showPassword,
                                          fieldError: fieldError,
                                          passwordLive: onPassword
                                              ? _error
                                              : null,
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sendLabel(AuthContactReading reading) {
    return switch (reading.mode) {
      AuthContactMode.phone => 'Send OTP',
      AuthContactMode.email => 'Send code to email',
      AuthContactMode.unknown => 'Continue',
    };
  }

  Widget _entryCard({
    required AuthContactReading reading,
    required AppConfig config,
    required String? Function(_LoginField field) fieldError,
  }) {
    return _AuthCard(
      key: const ValueKey('auth-entry-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('contact-field'),
            controller: _contact,
            keyboardType: reading.isPhone
                ? TextInputType.phone
                : TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: HomiziColors.ink),
            decoration: homiziFieldDecoration(
              labelText: homiziText(context, 'Email or mobile number'),
              hintText: reading.isPhone
                  ? homiziText(context, '98765 43210')
                  : homiziText(context, 'meera.nair@homizi.in'),
              errorText: fieldError(_LoginField.contact),
              prefixIcon: _PhonePrefix(show: reading.isPhone),
              prefixIconConstraints: BoxConstraints(
                minWidth: reading.isPhone ? 78 : 16,
                minHeight: 36,
              ),
            ),
          ),
          if (config.captchaEnabled) ...[
            const SizedBox(height: 12),
            HcaptchaField(
              siteKey: config.hcaptchaSiteKey,
              onToken: (token) =>
                  ref.read(captchaTokenProvider.notifier).setToken(token),
            ),
          ],
          const SizedBox(height: 16),
          _GradientButton(
            buttonKey: const Key('send-code'),
            onPressed: _busy ? null : () => unawaited(_requestCode()),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HomiziColors.ink,
                    ),
                  )
                : Text(homiziText(context, _sendLabel(reading))),
          ),
        ],
      ),
    );
  }

  Widget _otpCard({
    required AuthContactReading reading,
    required bool hosted,
    required String? Function(_LoginField field) fieldError,
  }) {
    final phone = reading.isPhone;
    return _AuthCard(
      key: const ValueKey('auth-otp-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            homiziText(
              context,
              phone ? 'Enter the code for your mobile' : 'Enter the email code',
            ),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _contact.text.trim(),
            style: const TextStyle(color: HomiziColors.inkSoft),
          ),
          const SizedBox(height: 16),
          OtpCodeField(
            controller: _code,
            showBoxes: true,
            autofocus: true,
            errorText: fieldError(_LoginField.code),
            helperText: hosted && !phone
                ? homiziText(context, 'Enter the 6-digit code from the email.')
                : null,
          ),
          const SizedBox(height: 16),
          _GradientButton(
            buttonKey: const Key('verify-code'),
            onPressed: _busy ? null : () => unawaited(_verify()),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HomiziColors.ink,
                    ),
                  )
                : Text(homiziText(context, 'Verify and continue')),
          ),
          const SizedBox(height: 8),
          _GradientButton(
            buttonKey: const Key('send-code'),
            onPressed: !_resend.canResend || _busy
                ? null
                : () => unawaited(_requestCode()),
            child: Text(
              homiziText(
                context,
                !_resend.canResend
                    ? 'Resend in ${_resend.remaining}s'
                    : 'Resend code',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _googleButton({required bool showGoogle}) {
    return OutlinedButton.icon(
      key: const Key('continue-google'),
      style: OutlinedButton.styleFrom(
        foregroundColor: HomiziColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: HomiziColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: !showGoogle || _busy ? null : () => unawaited(_google()),
      icon: const Text(
        'G',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w800,
          color: HomiziColors.logoOrange,
        ),
      ),
      label: Text(
        homiziText(
          context,
          showGoogle ? 'Continue with Google' : 'Continue with Google · soon',
        ),
      ),
    );
  }

  Widget _stagingPanel({
    required AppConfig config,
    required bool demo,
    required bool showPassword,
    required String? Function(_LoginField field) fieldError,
    required String? passwordLive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomiziColors.soft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HomiziColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (config.connectsToSupabase)
                TextButton(
                  key: Key(demo ? 'use-staging-sign-in' : 'use-demo-mode'),
                  onPressed: _busy
                      ? null
                      : () {
                          ref
                              .read(forceDemoModeProvider.notifier)
                              .setEnabled(!demo);
                          setState(() => _showError(null, _LoginField.contact));
                        },
                  child: Text(
                    homiziText(
                      context,
                      demo ? 'Use staging sign-in' : 'Use demo mode',
                    ),
                  ),
                ),
              OutlinedButton(
                key: const Key('create-profile'),
                onPressed: _busy ? null : () => unawaited(_createProfile()),
                child: Text(homiziText(context, 'Create profile')),
              ),
              if (_intentNote != null) ...[
                const SizedBox(height: 12),
                LiveNotice(
                  key: const Key('create-profile-note'),
                  message: homiziText(context, _intentNote!),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('broker-create-profile'),
                  onPressed: () => context.go(brokerProfileSignInLocation()),
                  child: Text(homiziText(context, 'Create broker profile')),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('login-pick-role'),
                  onPressed: () => context.go(RoutePaths.role),
                  child: Text(homiziText(context, 'Pick a role')),
                ),
              ),
              if (showPassword) ...[
                const SizedBox(height: 8),
                TextField(
                  key: const Key('password-field'),
                  controller: _password,
                  obscureText: true,
                  style: const TextStyle(color: HomiziColors.ink),
                  decoration: homiziFieldDecoration(
                    labelText: homiziText(context, 'Password'),
                    helperText: homiziText(
                      context,
                      'At least 8 characters. The password is not logged.',
                    ),
                    errorText: fieldError(_LoginField.password),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('password-sign-in'),
                  onPressed: _busy
                      ? null
                      : () => unawaited(_passwordAuth(false)),
                  child: Text(homiziText(context, 'Sign in with password')),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('password-sign-up'),
                  onPressed: _busy
                      ? null
                      : () => unawaited(_passwordAuth(true)),
                  child: Text(
                    homiziText(context, 'Create account with password'),
                  ),
                ),
              ],
              if (passwordLive != null)
                LiveLabel(
                  key: const Key('login-error'),
                  message: homiziText(context, passwordLive),
                ),
              if (config.allowsDevOtp && !config.usesHostedEmailOtp) ...[
                const SizedBox(height: 8),
                Text(
                  homiziText(
                    context,
                    'Development code: ${AppConfig.devOtp}. Dev and staging only.',
                  ),
                  style: const TextStyle(
                    color: HomiziColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_error != null && config.connectsToSupabase) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('continue-demo-mode'),
                  onPressed: _busy ? null : () => unawaited(_continueInDemo()),
                  child: Text(homiziText(context, 'Continue in demo mode')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({this.onLongPress});

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: HomiziColors.accentWash,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const HomiziSquareMark(
              size: 40,
              color: HomiziColors.logoOrange,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'HOMIZI',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: HomiziColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomiziColors.line),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _PhonePrefix extends StatelessWidget {
  const _PhonePrefix({required this.show});

  final bool show;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: show
          ? const Padding(
              key: Key('auth-phone-prefix'),
              padding: EdgeInsets.only(left: 10, right: 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HomiziColors.accentWash,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '+91',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w800,
                      color: HomiziColors.ink,
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox(key: Key('auth-prefix-empty'), width: 8),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: HomiziColors.line)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: HomiziColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Divider(color: HomiziColors.line)),
      ],
    );
  }
}

class _LegalLine extends StatelessWidget {
  const _LegalLine();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: HomiziColors.muted);
    final link = style?.copyWith(
      color: HomiziColors.ink,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'By continuing you agree to the '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              key: const Key('auth-terms'),
              onTap: () => context.push(RoutePaths.terms),
              child: Text('Terms', style: link),
            ),
          ),
          const TextSpan(text: ' and '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              key: const Key('auth-privacy'),
              onTap: () => context.push(RoutePaths.privacy),
              child: Text('Privacy', style: link),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _PeachSkyline extends StatelessWidget {
  const _PeachSkyline();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: SizedBox(
        height: 110,
        width: double.infinity,
        child: CustomPaint(painter: _SkylinePainter()),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()..color = HomiziColors.accentWash;
    canvas.drawRect(Offset.zero & size, wash);
    final peach = Paint()
      ..color = HomiziColors.logoOrange.withValues(alpha: 0.22);
    final deeper = Paint()
      ..color = HomiziColors.brandGolden.withValues(alpha: 0.45);
    final blocks = <(double, double, double)>[
      (0.02, 0.55, 0.08),
      (0.11, 0.38, 0.07),
      (0.19, 0.62, 0.1),
      (0.30, 0.28, 0.06),
      (0.37, 0.48, 0.09),
      (0.47, 0.34, 0.08),
      (0.56, 0.58, 0.11),
      (0.68, 0.26, 0.07),
      (0.76, 0.44, 0.09),
      (0.86, 0.36, 0.08),
      (0.94, 0.52, 0.06),
    ];
    for (var i = 0; i < blocks.length; i++) {
      final (x, h, w) = blocks[i];
      final rect = Rect.fromLTWH(
        size.width * x,
        size.height * (1 - h),
        size.width * w,
        size.height * h,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        i.isEven ? peach : deeper,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.buttonKey,
    required this.onPressed,
    required this.child,
  });

  final Key buttonKey;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                colors: [HomiziColors.logoOrange, HomiziColors.brandDeepOrange],
              )
            : null,
        color: enabled ? null : HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: FilledButton(
        key: buttonKey,
        style: FilledButton.styleFrom(
          backgroundColor: HomiziColors.clear,
          disabledBackgroundColor: HomiziColors.clear,
          foregroundColor: HomiziColors.ink,
          disabledForegroundColor: HomiziColors.ink,
          shadowColor: HomiziColors.clear,
          surfaceTintColor: HomiziColors.clear,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

class _WelcomeSuccess extends StatelessWidget {
  const _WelcomeSuccess({
    required this.contact,
    required this.testAccount,
    required this.onHome,
  });

  final String contact;
  final bool testAccount;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PersonAvatar(),
            const SizedBox(height: 28),
            Text(
              homiziText(context, 'Welcome!'),
              key: const Key('login-confirmed'),
              textAlign: TextAlign.center,
              style: text.headlineMedium?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(context, 'Thanks for logging in'),
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: HomiziColors.inkSoft),
            ),
            if (contact.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                contact,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: HomiziColors.muted),
              ),
            ],
            if (testAccount) ...[
              const SizedBox(height: 8),
              Text(
                homiziText(
                  context,
                  'Test account. This session stays on this device.',
                ),
                key: const Key('login-test-account'),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: HomiziColors.inkSoft),
              ),
            ],
            const SizedBox(height: 36),
            _GradientButton(
              buttonKey: const Key('login-continue'),
              onPressed: onHome,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home_rounded, color: HomiziColors.ink),
                  const SizedBox(width: 8),
                  Text(homiziText(context, 'Home')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupSuccess extends StatelessWidget {
  const _SignupSuccess({required this.onHome, required this.contact});

  final VoidCallback onHome;
  final String contact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              homiziText(context, 'Yeah..!'),
              textAlign: TextAlign.center,
              style: text.headlineMedium?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              homiziText(context, 'Signed up successfully'),
              key: const Key('signup-confirmed'),
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(color: HomiziColors.inkSoft),
            ),
            if (contact.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                contact,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: HomiziColors.muted),
              ),
            ],
            const Spacer(),
            TextButton(
              key: const Key('signup-choose-role'),
              onPressed: () {
                final router = GoRouter.maybeOf(context);
                if (router == null) {
                  return;
                }
                router.go(RoutePaths.role);
              },
              child: Text(
                homiziText(context, 'Choose your role'),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _GradientButton(
              buttonKey: const Key('login-continue'),
              onPressed: onHome,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home_rounded, color: HomiziColors.ink),
                  const SizedBox(width: 8),
                  Text(homiziText(context, 'Home')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: HomiziColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: HomiziColors.logoOrange, width: 4),
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 64,
        color: HomiziColors.ink,
      ),
    );
  }
}

enum _LoginField { contact, code, password, name }

/// Ties a sign-in sentence to the field it describes.
/// A message about the session or the build stays off the fields.
_LoginField? _fieldFor(String error, _LoginField action) {
  final lower = error.toLowerCase();
  if (lower.contains('your name')) {
    return _LoginField.name;
  }
  if (lower.contains('password')) {
    return _LoginField.password;
  }
  if (lower.contains('too many') ||
      lower.contains('connection dropped') ||
      lower.contains('did not work') ||
      lower.contains('not available yet') ||
      lower.contains('rate limit')) {
    return null;
  }
  if (lower.contains('6-digit') ||
      lower.contains('6 digits') ||
      lower.contains('that code') ||
      lower.contains('the code shown') ||
      lower.contains('check the email and code')) {
    return _LoginField.code;
  }
  if (lower.contains('email or') ||
      lower.contains('email address') ||
      lower.startsWith('email ') ||
      lower.contains('mobile') ||
      lower.contains('phone sms')) {
    return _LoginField.contact;
  }
  if (lower.contains('terms and privacy') ||
      lower.contains('not configured') ||
      lower.contains('redirect') ||
      lower.contains('disabled') ||
      lower.contains('session expired') ||
      lower.contains('sign in again') ||
      lower.contains('sign-in failed')) {
    return null;
  }
  return action;
}
