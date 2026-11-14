import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/auth_failure.dart';
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
  var _panel = _AuthPanel.closed;
  var _codeSent = false;
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
      final next = GoRouter.maybeOf(context)?.state.uri.queryParameters['next'];
      final safe = hostResumePath(next);
      if (safe != null && ref.read(hostIntentProvider).afterAuth != safe) {
        ref
            .read(hostIntentProvider.notifier)
            .remember(safe, afterProfile: RoutePaths.home);
      }
      if (next != null && next.isNotEmpty && _panel == _AuthPanel.closed) {
        setState(() => _panel = _AuthPanel.login);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _googleTimer?.cancel();
    _scroll.dispose();
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

  void _onBack() {
    if (_confirmed) {
      _releaseHold();
      HomiziBackButton.leave(context);
      return;
    }
    if (_panel != _AuthPanel.closed) {
      setState(() {
        _panel = _AuthPanel.closed;
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
    if (_panel == _AuthPanel.signup && _name.text.trim().length < 2) {
      setState(() => _showError('Enter your name.', _LoginField.name));
      return;
    }
    final email = _contact.text.trim();
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
    final error = await ref
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
    final showPhone = providers.phone;
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

    final loginOpen = _panel == _AuthPanel.login;
    final signupOpen = _panel == _AuthPanel.signup;
    return MinTouchScope(
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        body: Stack(
          children: [
            const _AuthBackdrop(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  children: [
                    _AuthHeader(onBack: _onBack),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _confirmed
                          ? (_welcomeSignup
                                ? _SignupSuccess(
                                    onHome: _releaseHold,
                                    contact: _confirmedContact,
                                  )
                                : _WelcomeSuccess(
                                    contact: _confirmedContact,
                                    testAccount: _testAccountConfirm,
                                    onHome: _releaseHold,
                                  ))
                          : _PanelSplit(
                              panel: _panel,
                              login: _TitlePanel(
                                expanded: loginOpen,
                                showSubtitle:
                                    _panel == _AuthPanel.closed || loginOpen,
                                dark: true,
                                title: 'Login',
                                subtitle: loginOpen
                                    ? (showPhone
                                          ? "We'll send a 6-digit code to your email or mobile."
                                          : "We'll send a 6-digit code to your email.")
                                    : 'Email code',
                                onOpen: () => _open(_AuthPanel.login),
                                child: loginOpen
                                    ? _loginForm(
                                        config: config,
                                        demo: demo,
                                        hosted: hosted,
                                        showPassword: showPassword,
                                        showGoogle: showGoogle,
                                        showPhone: showPhone,
                                        stagingTools: stagingTools,
                                        fieldError: fieldError,
                                        tied: tied,
                                      )
                                    : null,
                              ),
                              signup: _TitlePanel(
                                expanded: signupOpen,
                                showSubtitle:
                                    _panel == _AuthPanel.closed || signupOpen,
                                dark: false,
                                title: 'Signup',
                                subtitle: 'Name and email',
                                onOpen: () => _open(_AuthPanel.signup),
                                child: signupOpen
                                    ? _signupForm(fieldError: fieldError)
                                    : null,
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

  Widget _loginForm({
    required AppConfig config,
    required bool demo,
    required bool hosted,
    required bool showPassword,
    required bool showGoogle,
    required bool showPhone,
    required bool stagingTools,
    required String? Function(_LoginField field) fieldError,
    required bool tied,
  }) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ref.watch(tenantIntentProvider) == TenantIntent.profile) ...[
            Text(
              key: const Key('tenant-profile-signin-prompt'),
              homiziText(context, 'Sign in to create your tenant profile.'),
              style: text.bodyMedium?.copyWith(color: HomiziColors.white),
            ),
            const SizedBox(height: 12),
          ],
          if (showGoogle) ...[
            FilledButton.icon(
              key: const Key('continue-google'),
              style: FilledButton.styleFrom(
                backgroundColor: HomiziColors.white,
                foregroundColor: HomiziColors.ink,
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: HomiziColors.line),
              ),
              onPressed: _busy ? null : () => unawaited(_google()),
              icon: const Text(
                'G',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w800,
                  color: HomiziColors.logoOrange,
                ),
              ),
              label: Text(homiziText(context, 'Continue with Google')),
            ),
            if (_googleNote != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('google-sign-in-note'),
                homiziText(context, _googleNote!),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: HomiziColors.white,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          TextField(
            key: const Key('contact-field'),
            controller: _contact,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: HomiziColors.ink),
            decoration: homiziFieldDecoration(
              labelText: homiziText(context, 'Email'),
              hintText: homiziText(context, 'ananya.sharma@homizi.in'),
              errorText: fieldError(_LoginField.contact),
            ),
          ),
          if (config.captchaEnabled && !_codeSent) ...[
            const SizedBox(height: 12),
            HcaptchaField(
              siteKey: config.hcaptchaSiteKey,
              onToken: (token) =>
                  ref.read(captchaTokenProvider.notifier).setToken(token),
            ),
          ],
          if (!_codeSent) ...[
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
                  : Text(homiziText(context, 'Send code')),
            ),
          ],
          if (showPhone)
            Align(
              child: TextButton(
                key: const Key('sign-in-with-mobile'),
                onPressed: _busy
                    ? null
                    : () {
                        final router = GoRouter.maybeOf(context);
                        if (router == null) {
                          return;
                        }
                        router.push(RoutePaths.loginPhone);
                      },
                child: Text(
                  homiziText(context, 'Use mobile number instead'),
                  style: const TextStyle(color: HomiziColors.white),
                ),
              ),
            ),
          if (_codeSent) ...[
            OtpCodeField(
              controller: _code,
              showBoxes: true,
              errorText: fieldError(_LoginField.code),
              helperText: hosted
                  ? homiziText(
                      context,
                      'Enter the 6-digit code from the email.',
                    )
                  : null,
            ),
            if (hosted) ...[
              const SizedBox(height: 4),
              Text(
                homiziText(
                  context,
                  'If the email contains a link, opening it still signs you in.',
                ),
                style: text.bodySmall?.copyWith(color: HomiziColors.white),
              ),
            ],
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
          if (_error != null && !tied) ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: HomiziColors.errorWash,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LiveNotice(
                  key: const Key('login-error'),
                  message: homiziText(context, _error!),
                  isError: true,
                ),
              ),
            ),
          ] else if (_error != null)
            LiveLabel(
              key: const Key('login-error'),
              message: homiziText(context, _error!),
            ),
          if (stagingTools) ...[
            const SizedBox(height: 28),
            DecoratedBox(
              decoration: BoxDecoration(
                color: HomiziColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HomiziColors.line),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      homiziText(
                        context,
                        config.environment == AppEnvironment.staging
                            ? 'Staging tools'
                            : 'Development tools',
                      ),
                      style: const TextStyle(
                        color: HomiziColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (config.connectsToSupabase)
                      TextButton(
                        key: Key(
                          demo ? 'use-staging-sign-in' : 'use-demo-mode',
                        ),
                        onPressed: _busy
                            ? null
                            : () {
                                ref
                                    .read(forceDemoModeProvider.notifier)
                                    .setEnabled(!demo);
                                setState(
                                  () => _showError(null, _LoginField.contact),
                                );
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
                      onPressed: _busy
                          ? null
                          : () => unawaited(_createProfile()),
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
                        onPressed: () =>
                            context.go(brokerProfileSignInLocation()),
                        child: Text(
                          homiziText(context, 'Create broker profile'),
                        ),
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
                        child: Text(
                          homiziText(context, 'Sign in with password'),
                        ),
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
                    if (_error != null && config.connectsToSupabase) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const Key('continue-demo-mode'),
                        onPressed: _busy
                            ? null
                            : () => unawaited(_continueInDemo()),
                        child: Text(
                          homiziText(context, 'Continue in demo mode'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (config.allowsDevOtp && !hosted) ...[
            const SizedBox(height: 16),
            Text(
              homiziText(
                context,
                'Development code: ${AppConfig.devOtp}. Dev and staging only.',
              ),
              style: const TextStyle(color: HomiziColors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _signupForm({
    required String? Function(_LoginField field) fieldError,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('signup-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: HomiziColors.ink),
            decoration: homiziFieldDecoration(
              labelText: homiziText(context, 'Name'),
              hintText: homiziText(context, 'Ananya Sharma'),
              errorText: fieldError(_LoginField.name),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contact-field'),
            controller: _contact,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: HomiziColors.ink),
            decoration: homiziFieldDecoration(
              labelText: homiziText(context, 'Email'),
              hintText: homiziText(context, 'ananya.sharma@homizi.in'),
              errorText: fieldError(_LoginField.contact),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            homiziText(context, 'How will you use Homizi?'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in const [
                ('tenant', 'Tenant', Key('signup-role-tenant')),
                ('host', 'Host', Key('signup-role-host')),
                ('broker', 'Property Partner', Key('signup-role-broker')),
                ('roommate', 'Home-Sharer', Key('signup-role-roommate')),
              ])
                FilterChip(
                  key: role.$3,
                  label: Text(role.$2),
                  selected: _signupRole == role.$1,
                  showCheckmark: false,
                  selectedColor: HomiziColors.logoOrange,
                  backgroundColor: HomiziColors.soft,
                  labelStyle: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: _signupRole == role.$1
                        ? HomiziColors.logoOrange
                        : HomiziColors.line,
                  ),
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _signupRole = role.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_codeSent)
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
                  : Text(homiziText(context, 'Send code')),
            ),
          if (_codeSent) ...[
            OtpCodeField(
              controller: _code,
              showBoxes: true,
              errorText: fieldError(_LoginField.code),
              helperText: homiziText(
                context,
                'Enter the 6-digit code from the email.',
              ),
            ),
            const SizedBox(height: 16),
            _GradientButton(
              buttonKey: const Key('verify-code'),
              onPressed: _busy ? null : () => unawaited(_verify()),
              child: Text(homiziText(context, 'Verify and continue')),
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            LiveNotice(
              key: const Key('login-error'),
              message: homiziText(context, _error!),
              isError: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HomiziBackButton(onPressed: onBack),
        const SizedBox(width: 4),
        Text(
          homiziText(context, 'Sign in'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(left: -90, top: -110, child: _YellowDisc(diameter: 230)),
        Positioned(
          right: -120,
          bottom: -140,
          child: _YellowDisc(diameter: 280),
        ),
      ],
    );
  }
}

class _YellowDisc extends StatelessWidget {
  const _YellowDisc({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: const BoxDecoration(
          color: HomiziColors.brandYellow,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PanelSplit extends StatelessWidget {
  const _PanelSplit({
    required this.panel,
    required this.login,
    required this.signup,
  });

  final _AuthPanel panel;
  final Widget login;
  final Widget signup;

  @override
  Widget build(BuildContext context) {
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 420);
    final share = switch (panel) {
      _AuthPanel.closed => 0.5,
      _AuthPanel.login => 0.78,
      _AuthPanel.signup => 0.22,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: share),
      duration: motion,
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final top = (value * 100).round().clamp(18, 82);
        return Column(
          children: [
            Flexible(flex: top, child: login),
            const SizedBox(height: 10),
            const _ArrowSeam(),
            const SizedBox(height: 10),
            Flexible(flex: 100 - top, child: signup),
          ],
        );
      },
    );
  }
}

class _ArrowSeam extends StatelessWidget {
  const _ArrowSeam();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_LoginScreenState>();
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundArrow(
            buttonKey: const Key('auth-open-signup'),
            icon: Icons.keyboard_arrow_up_rounded,
            background: HomiziColors.white,
            iconColor: HomiziColors.ink,
            tooltip: 'Open signup',
            onPressed: state == null
                ? null
                : () => state._open(_AuthPanel.signup),
          ),
          const SizedBox(width: 12),
          _RoundArrow(
            buttonKey: const Key('auth-open-login'),
            icon: Icons.keyboard_arrow_down_rounded,
            background: HomiziColors.ink,
            iconColor: HomiziColors.white,
            tooltip: 'Open login',
            onPressed: state == null
                ? null
                : () => state._open(_AuthPanel.login),
          ),
        ],
      ),
    );
  }
}

class _RoundArrow extends StatelessWidget {
  const _RoundArrow({
    required this.buttonKey,
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.tooltip,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final Color background;
  final Color iconColor;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: HomiziColors.shadow,
      child: IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          fixedSize: const Size(48, 48),
        ),
      ),
    );
  }
}

class _TitlePanel extends StatelessWidget {
  const _TitlePanel({
    required this.expanded,
    required this.showSubtitle,
    required this.dark,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    required this.child,
  });

  final bool expanded;
  final bool showSubtitle;
  final bool dark;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? HomiziColors.white : HomiziColors.ink;
    final subtitleColor = dark ? HomiziColors.white : HomiziColors.inkSoft;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, title),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            homiziText(context, subtitle),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
          ),
        ],
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? HomiziColors.ink : HomiziColors.white,
        borderRadius: BorderRadius.circular(28),
        border: dark ? null : Border.all(color: HomiziColors.line),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expanded)
              heading
            else
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(20),
                  child: Align(alignment: Alignment.centerLeft, child: heading),
                ),
              ),
            if (child != null) ...[
              const SizedBox(height: 16),
              Expanded(child: child!),
            ],
          ],
        ),
      ),
    );
  }
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
        color: HomiziColors.ink,
        borderRadius: BorderRadius.circular(28),
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
                color: HomiziColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(context, 'Thanks for logging in'),
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: HomiziColors.white),
            ),
            if (contact.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                contact,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: HomiziColors.white),
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
                style: text.bodyMedium?.copyWith(color: HomiziColors.white),
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
