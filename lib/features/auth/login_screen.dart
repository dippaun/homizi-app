import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
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
  final _scroll = ScrollController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  late final LoginConfirmHold _confirmHold;
  final _resend = ResendCountdown();
  final _attempts = OtpAttemptGate();
  bool _codeSent = false;
  String? _error;
  _LoginField? _errorField;
  bool _busy = false;
  bool _confirmed = false;
  String _confirmedContact = '';
  bool _testAccountConfirm = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final next = GoRouter.maybeOf(context)?.state.uri.queryParameters['next'];
      final safe = hostResumePath(next);
      if (safe == null || ref.read(hostIntentProvider).afterAuth == safe) {
        return;
      }
      ref
          .read(hostIntentProvider.notifier)
          .remember(safe, afterProfile: RoutePaths.home);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _googleTimer?.cancel();
    _scroll.dispose();
    _contact.dispose();
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
      SnackBar(content: Text(homiziText(context, message))),
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
        _googleNote = error;
      });
      return;
    }
    final phase = ref.read(sessionProvider).phase;
    if (phase == SessionPhase.ready || phase == SessionPhase.needsRole) {
      setState(() {
        _busy = false;
        _confirmed = true;
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
    setState(() {
      _busy = true;
      _confirmed = false;
      _showError(null, _LoginField.code);
    });
    _confirmHold.hold();
    final error = await ref
        .read(sessionProvider.notifier)
        .signIn(contact: _contact.text, code: _code.text);
    if (!mounted) {
      return;
    }
    _applySignInResult(error, _LoginField.code);
  }

  void _applySignInResult(String? error, _LoginField field) {
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
    _snack('Signed in.');
    setState(() {
      _busy = false;
      _confirmed = true;
      _confirmedContact = _contact.text.trim();
      _testAccountConfirm = isClientTestDemoAccount(_contact.text, _code.text);
    });
  }

  Future<void> _continueInDemo() async {
    setState(() {
      _busy = true;
      _confirmed = false;
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
      _confirmedContact = ref.read(sessionProvider).contact;
      _testAccountConfirm = false;
    });
  }

  void _showError(String? error, _LoginField action) {
    _error = error;
    _errorField = error == null ? null : _fieldFor(error, action);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final demo = ref.watch(forceDemoModeProvider);
    final hosted = config.usesHostedEmailOtp && !demo;
    final showPassword = hosted && config.allowsStagingPassword;
    final onContact = _errorField == _LoginField.contact;
    final onCode = _errorField == _LoginField.code;
    final onPassword = _errorField == _LoginField.password && showPassword;
    final tied = onContact || onCode || onPassword;
    String? fieldError(_LoginField field) {
      if (_error == null) {
        return null;
      }
      final selected = switch (field) {
        _LoginField.contact => onContact,
        _LoginField.code => onCode,
        _LoginField.password => onPassword,
      };
      if (!selected) {
        return null;
      }
      return homiziText(context, _error!);
    }

    final text = Theme.of(context).textTheme;
    final primary = homiziPrimaryButtonStyle();
    final stagingTools = config.environment != AppEnvironment.prod;
    final providers = ref.watch(authProviderSettingsProvider);
    final showGoogle = providers.google;
    final showPhone = providers.phone;
    return MinTouchScope(
      child: Scaffold(
        backgroundColor: HomiziColors.soft,
        appBar: AppBar(
          backgroundColor: HomiziColors.white,
          surfaceTintColor: HomiziColors.white,
          automaticallyImplyLeading: false,
          leading: HomiziBackButton(
            onPressed: () {
              _releaseHold();
              HomiziBackButton.leave(context);
            },
          ),
          title: Text(homiziText(context, 'Sign in')),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: HomiziMark(size: 28),
            ),
          ],
        ),
        body: _confirmed
            ? _SignedInConfirmation(
                contact: _confirmedContact,
                testAccount: _testAccountConfirm,
                onContinue: _releaseHold,
              )
            : ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  HomiziSpace.lg,
                  HomiziSpace.xs,
                  HomiziSpace.lg,
                  HomiziSpace.xl,
                ),
                children: [
                  Text(
                    homiziText(context, 'Sign in to HOMIZI'),
                    style: text.headlineSmall?.copyWith(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (ref.watch(tenantIntentProvider) ==
                      TenantIntent.profile) ...[
                    const SizedBox(height: 12),
                    Text(
                      key: const Key('tenant-profile-signin-prompt'),
                      homiziText(
                        context,
                        'Sign in to create your tenant profile.',
                      ),
                    ),
                  ],
                  const SizedBox(height: HomiziSpace.xs),
                  Text(
                    homiziText(
                      context,
                      showPhone
                          ? "We'll send a 6-digit code to your email or mobile."
                          : "We'll send a 6-digit code to your email.",
                    ),
                    style: text.bodyMedium?.copyWith(
                      color: HomiziColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                          color: HomiziColors.ink,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('contact-field'),
                    controller: _contact,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: HomiziColors.ink),
                    decoration: homiziFieldDecoration(
                      labelText: homiziText(context, 'Email'),
                      hintText: homiziText(context, 'you@example.test'),
                      errorText: fieldError(_LoginField.contact),
                    ),
                  ),
                  if (config.captchaEnabled && !_codeSent) ...[
                    const SizedBox(height: 12),
                    HcaptchaField(
                      siteKey: config.hcaptchaSiteKey,
                      onToken: (token) => ref
                          .read(captchaTokenProvider.notifier)
                          .setToken(token),
                    ),
                  ],
                  if (!_codeSent) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('send-code'),
                      style: primary,
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
                        style: text.bodySmall?.copyWith(
                          color: HomiziColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('verify-code'),
                      style: primary,
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
                    FilledButton(
                      key: const Key('send-code'),
                      style: primary,
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
                    LiveNotice(
                      key: const Key('login-error'),
                      message: homiziText(context, _error!),
                      isError: true,
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
                                  demo
                                      ? 'use-staging-sign-in'
                                      : 'use-demo-mode',
                                ),
                                onPressed: _busy
                                    ? null
                                    : () {
                                        ref
                                            .read(
                                              forceDemoModeProvider.notifier,
                                            )
                                            .setEnabled(!demo);
                                        setState(
                                          () => _showError(
                                            null,
                                            _LoginField.contact,
                                          ),
                                        );
                                      },
                                child: Text(
                                  homiziText(
                                    context,
                                    demo
                                        ? 'Use staging sign-in'
                                        : 'Use demo mode',
                                  ),
                                ),
                              ),
                            OutlinedButton(
                              key: const Key('create-profile'),
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(_createProfile()),
                              child: Text(
                                homiziText(context, 'Create profile'),
                              ),
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
                                onPressed: () =>
                                    context.go(RoutePaths.personalize),
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
                                  homiziText(
                                    context,
                                    'Create account with password',
                                  ),
                                ),
                              ),
                            ],
                            if (_error != null &&
                                config.connectsToSupabase) ...[
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
                      style: const TextStyle(
                        color: HomiziColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SignedInConfirmation extends StatelessWidget {
  const _SignedInConfirmation({
    required this.contact,
    required this.testAccount,
    required this.onContinue,
  });

  final String contact;
  final bool testAccount;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HomiziSpace.xl,
        HomiziSpace.xs,
        HomiziSpace.xl,
        HomiziSpace.xl,
      ),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: HomiziColors.successWash,
            borderRadius: BorderRadius.circular(HomiziSpace.cardRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(HomiziSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: HomiziColors.success,
                  size: 56,
                ),
                const SizedBox(height: HomiziSpace.md),
                Text(
                  homiziText(context, "You're signed in."),
                  key: const Key('login-confirmed'),
                  style: text.headlineSmall?.copyWith(color: HomiziColors.ink),
                ),
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: HomiziSpace.xs),
                  Text(
                    contact,
                    style: text.bodyMedium?.copyWith(
                      color: HomiziColors.inkSoft,
                    ),
                  ),
                ],
                if (testAccount) ...[
                  const SizedBox(height: HomiziSpace.xs),
                  Text(
                    homiziText(
                      context,
                      'Test account. This session stays on this device.',
                    ),
                    key: const Key('login-test-account'),
                    style: text.bodyMedium?.copyWith(color: HomiziColors.ink),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: HomiziSpace.xl),
        FilledButton(
          key: const Key('login-continue'),
          style: FilledButton.styleFrom(
            backgroundColor: HomiziColors.accent,
            foregroundColor: HomiziColors.ink,
            disabledBackgroundColor: HomiziColors.accentDisabled,
          ),
          onPressed: onContinue,
          child: Text(homiziText(context, 'Continue')),
        ),
      ],
    );
  }
}

enum _LoginField { contact, code, password }

/// Ties a sign-in sentence to the field it describes.
/// A message about the session or the build stays off the fields.
_LoginField? _fieldFor(String error, _LoginField action) {
  final lower = error.toLowerCase();
  if (lower.contains('password')) {
    return _LoginField.password;
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
      lower.contains('rate limit') ||
      lower.contains('redirect') ||
      lower.contains('disabled') ||
      lower.contains('session expired') ||
      lower.contains('sign in again') ||
      lower.contains('sign-in failed')) {
    return null;
  }
  return action;
}
