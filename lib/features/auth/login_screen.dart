import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/session/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _contact = TextEditingController();
  final _code = TextEditingController();
  int _cooldown = 0;
  String? _error;
  bool _busy = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _contact.dispose();
    _code.dispose();
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
    if (config.usesHostedEmailOtp) {
      setState(() {
        _busy = true;
        _error = null;
      });
      final error = await ref
          .read(sessionProvider.notifier)
          .requestEmailCode(_contact.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error;
      });
      if (error == null) {
        _startCooldown();
      }
      return;
    }
    if (!config.allowsDevOtp) {
      setState(() {
        _error =
            'OTP delivery is not configured for production builds. No code was sent.';
      });
      return;
    }
    setState(() => _error = null);
    _startCooldown();
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(sessionProvider.notifier)
        .signIn(contact: _contact.text, code: _code.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return Scaffold(
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
              config.usesHostedEmailOtp
                  ? 'Enter your email. Staging sends a 6-digit code to that inbox. Phone SMS is not connected.'
                  : config.connectsToSupabase
                  ? 'Use an email or an Indian mobile number. No SMS or email is sent. The development code opens a Supabase session with the local fixture password.'
                  : 'Use an email or an Indian mobile number. No SMS or email is sent. This session stays on the device until Supabase is configured.',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('contact-field'),
            controller: _contact,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Email or mobile'),
              hintText: homiziText(context, 'you@example.test'),
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
                _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Send code',
              ),
            ),
          ),
          if (config.allowsDevOtp && !config.usesHostedEmailOtp) ...[
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
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, _error!),
              key: const Key('login-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
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
        ],
      ),
    );
  }
}
