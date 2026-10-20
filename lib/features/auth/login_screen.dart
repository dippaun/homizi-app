import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/broker/broker_auth.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shell/min_touch.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _contact = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  int _cooldown = 0;
  String? _error;
  _LoginField? _errorField;
  bool _busy = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _contact.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldown -= 1;
        if (_cooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _requestCode() async {
    final config = ref.read(appConfigProvider);
    final hosted =
        config.usesHostedEmailOtp && !ref.read(forceDemoModeProvider);
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
      _showError(null, _LoginField.password);
    });
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
    setState(() {
      _busy = false;
      _showError(error, _LoginField.password);
    });
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _showError(null, _LoginField.code);
    });
    final error = await ref
        .read(sessionProvider.notifier)
        .signIn(contact: _contact.text, code: _code.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _showError(error, _LoginField.code);
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

    return MinTouchScope(
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          title: Text(homiziText(context, 'Sign in')),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: HomiziMark(size: 28),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              homiziText(context, 'Your number stays on this screen.'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                hosted
                    ? kIsWeb
                          ? 'Enter your email. Staging emails a 6-digit code. Type that code in this browser. A link to in.homizi.app:// is not required. Phone SMS is not connected.'
                          : 'Enter your email. Staging emails a 6-digit code. Type that code below. If the email contains a link, opening it on this phone still signs you in. Phone SMS is not connected.'
                    : config.connectsToSupabase && !demo
                    ? 'Use an email or an Indian mobile number. No SMS or email is sent. The development code opens a Supabase session with the local fixture password.'
                    : 'Use an email or an Indian mobile number. No SMS or email is sent. This session stays on the device until Supabase is configured.',
              ),
            ),
            if (config.connectsToSupabase) ...[
              const SizedBox(height: 8),
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
            ],
            const SizedBox(height: 24),
            TextField(
              key: const Key('contact-field'),
              controller: _contact,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Email or mobile'),
                hintText: homiziText(context, 'you@example.test'),
                errorText: fieldError(_LoginField.contact),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const Key('send-code'),
              onPressed: _cooldown > 0 || _busy
                  ? null
                  : () => unawaited(_requestCode()),
              child: Text(
                homiziText(
                  context,
                  _cooldown > 0
                      ? 'Resend in ${_cooldown}s'
                      : hosted
                      ? 'Send code'
                      : 'Send sign-in email',
                ),
              ),
            ),
            if (config.allowsDevOtp && !hosted) ...[
              const SizedBox(height: 16),
              Text(
                homiziText(
                  context,
                  'Development code: ${AppConfig.devOtp}. It is shown only in dev and staging, and it is never logged.',
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const Key('otp-field'),
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: homiziText(context, '6-digit code'),
                helperText: hosted
                    ? homiziText(
                        context,
                        'Enter the 6-digit code from the email.',
                      )
                    : null,
                errorText: fieldError(_LoginField.code),
              ),
            ),
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
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('verify-code'),
              onPressed: _busy ? null : () => unawaited(_verify()),
              child: Text(
                homiziText(
                  context,
                  _busy ? 'Checking code…' : 'Verify and continue',
                ),
              ),
            ),
            if (hosted && config.allowsStagingPassword) ...[
              const SizedBox(height: 20),
              TextField(
                key: const Key('password-field'),
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
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
                onPressed: _busy ? null : () => unawaited(_passwordAuth(false)),
                child: Text(homiziText(context, 'Sign in with password')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('password-sign-up'),
                onPressed: _busy ? null : () => unawaited(_passwordAuth(true)),
                child: Text(
                  homiziText(context, 'Create account with password'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('broker-create-profile'),
                onPressed: () => context.go(brokerProfileSignInLocation()),
                child: Text(homiziText(context, 'Create profile')),
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
          ],
        ),
      ),
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
