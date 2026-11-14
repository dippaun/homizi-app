import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_failure.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/auth/auth_provider_settings.dart';
import 'package:homizi/features/auth/contact_otp_screen.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class _OpensGoogle extends DemoAccountGateway {
  @override
  Future<AccountSnapshot?> signInWithGoogle({
    required String policyVersion,
    required String redirectTo,
  }) async {
    return null;
  }
}

class _ProvidersOff extends AuthProviderSettingsController {
  @override
  AuthProviderSettings build() {
    return const AuthProviderSettings(google: false, phone: false);
  }
}

void main() {
  test('settings hide a provider only when the flag is false', () {
    expect(
      parseAuthProviderSettings(<String, Object>{
        'external': <String, Object>{'google': false, 'phone': false},
      }),
      isA<AuthProviderSettings>()
          .having((s) => s.google, 'google', isFalse)
          .having((s) => s.phone, 'phone', isFalse),
    );
    expect(
      parseAuthProviderSettings(<String, Object>{
        'external': <String, Object>{'google': true, 'phone': true},
      }).google,
      isTrue,
    );
    expect(
      parseAuthProviderSettings(<String, Object>{
        'external': <String, Object>{},
      }).google,
      isTrue,
    );
    expect(parseAuthProviderSettings('nope').phone, isTrue);
    expect(parseAuthProviderSettings(null).google, isTrue);
  });

  test('a failed settings read hides Google and phone', () async {
    final down = await loadAuthProviderSettings(
      supabaseUrl: 'https://example.test',
      publishableKey: 'publishable',
      get: (uri, headers) async {
        expect(uri.path, '/auth/v1/settings');
        expect(headers['apikey'], 'publishable');
        return http.Response('no', 401);
      },
    );
    expect(down.google, isFalse);
    expect(down.phone, isFalse);

    final off = await loadAuthProviderSettings(
      supabaseUrl: 'https://example.test/',
      publishableKey: 'publishable',
      get: (uri, headers) async =>
          http.Response('{"external":{"google":false,"phone":false}}', 200),
    );
    expect(off.google, isFalse);
    expect(off.phone, isFalse);
  });

  test('the email send rate limit stays friendly and hides the code', () {
    final message = authFailureMessage(
      const AuthException(
        'email rate limit exceeded for owner@example.test',
        statusCode: '429',
        code: 'over_email_send_rate_limit',
      ),
    );
    expect(message, emailSendRateLimitMessage);
    expect(message, isNot(contains('Supabase code')));
    expect(message, isNot(contains('over_email_send_rate_limit')));
    expect(message.contains('@'), isFalse);
  });

  testWidgets('sign-in hides Google and mobile when the project has them off', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProviderSettingsProvider.overrideWith(_ProvidersOff.new),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('auth-open-login')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('continue-google')), findsNothing);
    expect(find.byKey(const Key('sign-in-with-mobile')), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Use mobile number instead'), findsNothing);
    expect(
      find.text("We'll send a 6-digit code to your email."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('send-code')), findsOneWidget);
    expect(find.byKey(const Key('contact-field')), findsOneWidget);
  });

  testWidgets('verify mobile says it is coming soon instead of failing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProviderSettingsProvider.overrideWith(_ProvidersOff.new),
        ],
        child: const MaterialApp(home: ContactOtpScreen(link: true)),
      ),
    );
    await tester.pump();

    expect(find.text('Verify mobile'), findsOneWidget);
    expect(find.byKey(const Key('mobile-verification-soon')), findsOneWidget);
    expect(find.text(mobileVerificationSoonMessage), findsOneWidget);
    expect(find.byKey(const Key('send-phone-code')), findsNothing);
    expect(find.textContaining('error'), findsNothing);
  });

  testWidgets('opening Google times out with a retry', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            environment: AppEnvironment.dev,
            supabaseUrl: '',
            supabaseAnonKey: '',
            policyVersion: '2026-10-11-draft',
          ),
        ),
        accountGatewayProvider.overrideWithValue(_OpensGoogle()),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('auth-open-login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-google')));
    await tester.pump();

    expect(find.text(googleOpeningMessage), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    expect(find.text(googleRetryMessage), findsOneWidget);
    expect(find.text(googleOpeningMessage), findsNothing);
    expect(find.byKey(const Key('continue-google')), findsOneWidget);
  });
}
