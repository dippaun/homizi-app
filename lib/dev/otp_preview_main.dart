import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/auth/contact_otp_screen.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/auth/otp/hcaptcha_field.dart';
import 'package:homizi/features/profile/profile_hub_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

/// Screenshot harness. Not used by the product router.
/// Open with `?scene=email|email-otp|phone|phone-error|resend|success|profile-off|profile-on`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final scene = Uri.base.queryParameters['scene'] ?? 'email';
  runApp(OtpPreviewApp(scene: scene));
}

class OtpPreviewApp extends StatelessWidget {
  const OtpPreviewApp({required this.scene, super.key});

  final String scene;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            environment: AppEnvironment.dev,
            supabaseUrl: '',
            supabaseAnonKey: '',
            policyVersion: '2026-10-11-draft',
            hcaptchaSiteKey: hcaptchaTestSiteKey,
          ),
        ),
        if (scene == 'profile-on')
          sessionProvider.overrideWith(_Verified.new)
        else if (scene == 'profile-off')
          sessionProvider.overrideWith(_Unverified.new),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: HomiziTheme.light(),
        home: _scene(scene),
      ),
    );
  }
}

Widget _scene(String scene) {
  return switch (scene) {
    'email-otp' => const LoginScreen(
      previewCooldown: 42,
      previewCode: '482913',
    ),
    'phone' => const ContactOtpScreen(previewContact: '9876543210'),
    'phone-error' => const ContactOtpScreen(
      previewContact: '9876543210',
      previewError: 'That code is incorrect. Check the 6 digits and try again.',
      previewCooldown: 37,
    ),
    'resend' => const ContactOtpScreen(
      previewContact: '9876543210',
      previewCooldown: 42,
    ),
    'success' => const ContactOtpScreen(
      previewContact: '+919876543210',
      previewConfirmed: true,
    ),
    'profile-on' || 'profile-off' => const ProfileHubScreen(),
    _ => const LoginScreen(),
  };
}

class _Verified extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
      contact: 'ananya@example.test',
      emailVerified: true,
      phoneVerified: true,
    );
  }
}

class _Unverified extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
      contact: 'ananya@example.test',
    );
  }
}
