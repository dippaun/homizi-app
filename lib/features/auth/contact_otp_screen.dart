import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/auth/login_confirm.dart';
import 'package:homizi/features/auth/otp/captcha_token.dart';
import 'package:homizi/features/auth/otp/hcaptcha_field.dart';
import 'package:homizi/features/auth/otp/homizi_fields.dart';
import 'package:homizi/features/auth/otp/indian_phone.dart';
import 'package:homizi/features/auth/otp/indian_phone_field.dart';
import 'package:homizi/features/auth/otp/otp_attempt.dart';
import 'package:homizi/features/auth/otp/otp_code_field.dart';
import 'package:homizi/features/auth/otp/otp_confirmation.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shell/min_touch.dart';

enum ContactChannel { email, phone }

/// Email or mobile code for a signed-in person, or mobile sign-in.
class ContactOtpScreen extends ConsumerStatefulWidget {
  const ContactOtpScreen({
    super.key,
    this.channel = ContactChannel.phone,
    this.link = false,
    this.previewError,
    this.previewCooldown = 0,
    this.previewConfirmed = false,
    this.previewContact = '',
  });

  final ContactChannel channel;
  final bool link;
  final String? previewError;
  final int previewCooldown;
  final bool previewConfirmed;
  final String previewContact;

  @override
  ConsumerState<ContactOtpScreen> createState() => _ContactOtpScreenState();
}

class _ContactOtpScreenState extends ConsumerState<ContactOtpScreen> {
  final _contact = TextEditingController();
  final _code = TextEditingController();
  final _resend = ResendCountdown();
  final _attempts = OtpAttemptGate();
  Timer? _timer;
  bool _busy = false;
  bool _confirmed = false;
  String? _error;
  bool _codeSent = false;

  bool get _email => widget.channel == ContactChannel.email;

  String _confirmedTitle(SessionState session) {
    final verified = _email ? session.emailVerified : session.phoneVerified;
    if (!verified && widget.previewConfirmed) {
      return _email ? 'Email verified' : 'Mobile verified';
    }
    if (!verified) {
      return 'Code accepted';
    }
    return _email ? 'Email verified' : 'Mobile verified';
  }

  String _confirmedDetail(SessionState session) {
    final verified = _email ? session.emailVerified : session.phoneVerified;
    if (verified || widget.previewConfirmed) {
      return _rawContact;
    }
    return 'This stays on this device until a Supabase project confirms it.';
  }

  @override
  void initState() {
    super.initState();
    if (widget.previewContact.isNotEmpty) {
      _contact.text = widget.previewContact;
    }
    if (widget.previewCooldown > 0) {
      _resend.remaining = widget.previewCooldown;
      _codeSent = true;
      _startTicks();
    }
    _error = widget.previewError;
    _confirmed = widget.previewConfirmed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _contact.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startTicks() {
    _timer?.cancel();
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

  String get _rawContact {
    if (_email) {
      return _contact.text.trim();
    }
    return indianMobileE164(_contact.text) ?? _contact.text;
  }

  Future<void> _send() async {
    final config = ref.read(appConfigProvider);
    if (config.captchaEnabled && ref.read(captchaTokenProvider).isEmpty) {
      setState(() => _error = captchaRequiredMessage);
      _snack(captchaRequiredMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = _email
        ? await ref.read(sessionProvider.notifier).requestEmailCode(_rawContact)
        : await ref
              .read(sessionProvider.notifier)
              .requestPhoneCode(_rawContact, link: widget.link);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
      _codeSent = error == null;
    });
    if (error == null) {
      _attempts.reset();
      setState(_resend.start);
      _startTicks();
      _snack('Code sent.');
    } else {
      _snack(error);
    }
  }

  Future<void> _verify() async {
    if (_attempts.blocked) {
      setState(() => _error = retryCapMessage);
      _snack(retryCapMessage);
      return;
    }
    if (!isSixDigitCode(_code.text)) {
      setState(() => _error = incorrectOtpMessage);
      _snack(incorrectOtpMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = ref.read(sessionProvider.notifier);
    final error = _email
        ? await session.signIn(contact: _rawContact, code: _code.text)
        : await session.verifyPhoneCode(
            raw: _rawContact,
            code: _code.text,
            link: widget.link,
          );
    if (!mounted) {
      return;
    }
    if (error != null) {
      final lower = error.toLowerCase();
      if (lower.contains('incorrect') || lower.contains('expired')) {
        _attempts.recordFailure();
      }
      final shown = _attempts.blocked ? retryCapMessage : error;
      setState(() {
        _busy = false;
        _error = shown;
      });
      _snack(shown);
      return;
    }
    if (widget.link && ref.read(sessionProvider).userId == null) {
      ref.read(loginConfirmHoldProvider.notifier).hold();
    }
    if (!widget.link) {
      ref.read(loginConfirmHoldProvider.notifier).hold();
    }
    setState(() {
      _busy = false;
      _confirmed = true;
    });
    _snack(_email ? 'Email verified.' : 'Mobile verified.');
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final title = _email
        ? 'Verify email'
        : widget.link
        ? 'Verify mobile'
        : 'Sign in with mobile';
    return MinTouchScope(
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          backgroundColor: HomiziColors.white,
          surfaceTintColor: HomiziColors.white,
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, title)),
        ),
        body: _confirmed
            ? OtpConfirmation(
                title: _confirmedTitle(ref.watch(sessionProvider)),
                detail: _confirmedDetail(ref.watch(sessionProvider)),
                onContinue: () {
                  ref.read(loginConfirmHoldProvider.notifier).release();
                  HomiziBackButton.leave(context);
                },
              )
            : ListView(
                padding: const EdgeInsets.all(HomiziSpace.lg),
                children: [
                  Text(
                    homiziText(
                      context,
                      _email
                          ? 'We email a 6-digit code. It confirms this address on the account you are using.'
                          : widget.link
                          ? 'We text a 6-digit code. The number is linked to this account. It does not create a second one.'
                          : 'Use a mobile that is already verified on your Homizi account.',
                    ),
                    style: const TextStyle(color: HomiziColors.inkSoft),
                  ),
                  const SizedBox(height: 16),
                  if (_email)
                    TextField(
                      key: const Key('verify-email-field'),
                      controller: _contact,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: HomiziColors.ink),
                      decoration: homiziFieldDecoration(
                        labelText: homiziText(context, 'Email'),
                        errorText: _error != null && _error!.contains('email')
                            ? homiziText(context, _error!)
                            : null,
                      ),
                    )
                  else
                    IndianPhoneField(
                      controller: _contact,
                      errorText:
                          _error != null &&
                              (_error!.contains('mobile') ||
                                  _error!.contains('number') ||
                                  _error!.contains('linked'))
                          ? homiziText(context, _error!)
                          : null,
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
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('send-phone-code'),
                    style: homiziPrimaryButtonStyle(),
                    onPressed: !_resend.canResend || _busy
                        ? null
                        : () => unawaited(_send()),
                    child: _busy && !_codeSent
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: HomiziColors.ink,
                            ),
                          )
                        : Text(
                            homiziText(
                              context,
                              !_resend.canResend
                                  ? 'Resend in ${_resend.remaining}s'
                                  : 'Send code',
                            ),
                          ),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 8),
                    Text(
                      homiziText(context, otpExpiryHint),
                      key: const Key('otp-expiry-hint'),
                      style: const TextStyle(color: HomiziColors.muted),
                    ),
                  ],
                  if (_codeSent) ...[
                    const SizedBox(height: 16),
                    OtpCodeField(
                      controller: _code,
                      fieldKey: const Key('phone-otp-field'),
                      showBoxes: true,
                      errorText:
                          _error != null &&
                              (_error!.contains('code') ||
                                  _error!.contains('expired') ||
                                  _error!.contains('tries'))
                          ? homiziText(context, _error!)
                          : null,
                    ),
                  ],
                  if (_error != null &&
                      !(_error!.contains('code') ||
                          _error!.contains('email') ||
                          _error!.contains('mobile') ||
                          _error!.contains('number')))
                    Text(
                      homiziText(context, _error!),
                      key: const Key('contact-otp-error'),
                      style: const TextStyle(color: HomiziColors.error),
                    ),
                  const SizedBox(height: 12),
                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('verify-phone-code'),
                      style: homiziPrimaryButtonStyle(),
                      onPressed: _busy ? null : () => unawaited(_verify()),
                      child: _busy && _codeSent
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
                  ],
                  if (config.allowsDevOtp && !config.usesHostedPhoneOtp) ...[
                    const SizedBox(height: 20),
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
