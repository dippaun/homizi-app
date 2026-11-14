import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/otp/otp_code_field.dart';
import 'package:homizi/features/post_property/post_contact.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';

class PostOtpScreen extends ConsumerStatefulWidget {
  const PostOtpScreen({super.key});

  @override
  ConsumerState<PostOtpScreen> createState() => _PostOtpScreenState();
}

class _PostOtpScreenState extends ConsumerState<PostOtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  var _seconds = 60;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _seconds <= 0) {
        return;
      }
      setState(() => _seconds -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final target = ref.read(postOtpTargetProvider);
    if (target == null) {
      setState(() => _error = 'Send a code from the previous page.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await verifyPostCode(
      ref,
      mobile: target.channel == PostOtpChannel.mobile,
      contact: target.contact,
      code: _code.text,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    if (target.channel == PostOtpChannel.mobile) {
      ref.read(postContactProvider.notifier).markMobile(target.contact);
    } else {
      ref.read(postContactProvider.notifier).markEmail(target.contact);
    }
    context.pop(true);
  }

  Future<void> _resend() async {
    final target = ref.read(postOtpTargetProvider);
    if (target == null || _seconds > 0) {
      return;
    }
    final error = await sendPostCode(
      ref,
      mobile: target.channel == PostOtpChannel.mobile,
      contact: target.contact,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _error = error;
      if (error == null) {
        _seconds = 60;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = ref.watch(postOtpTargetProvider);
    final demo = ref.watch(appConfigProvider).allowsDevOtp;
    final mobile = target?.channel != PostOtpChannel.email;
    return PostPropertyPage(
      pageKey: const Key('post-otp-screen'),
      footer: PostGradientButton(
        buttonKey: const Key('post-otp-verify'),
        label: 'Verify',
        showArrow: false,
        busy: _busy,
        onPressed: _busy ? null : _verify,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            homiziText(
              context,
              mobile ? 'Verify mobile OTP' : 'Verify email OTP',
            ),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              target == null
                  ? 'Go back and send a code first.'
                  : 'Enter the 6-digit code sent to ${target.contact}.',
            ),
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
          ),
          if (demo) ...[
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                'Demo code ${AppConfig.devOtp}. No new SMS provider is used.',
              ),
              key: const Key('post-otp-demo'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          OtpCodeField(
            controller: _code,
            showBoxes: true,
            fieldKey: const Key('post-otp-field'),
            errorText: _error,
          ),
          const SizedBox(height: 12),
          TextButton(
            key: const Key('post-otp-resend'),
            onPressed: _seconds > 0 ? null : _resend,
            child: Text(
              _seconds > 0 ? 'Resend code in ${_seconds}s' : 'Resend code',
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
