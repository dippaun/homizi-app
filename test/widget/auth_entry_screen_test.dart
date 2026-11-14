import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:homizi/features/session/session_controller.dart';

class _Throws extends DemoAccountGateway {
  _Throws(this.message);

  final String message;

  @override
  Future<void> requestEmailOtp({required String email}) async {
    throw AccountFailure(message);
  }
}

Future<void> _open(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the entry screen starts with Login and Signup only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pump();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('New to HOMIZI? Create account'), findsOneWidget);
    expect(find.byKey(const Key('contact-field')), findsOneWidget);
    expect(find.byKey(const Key('signup-name')), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Email or mobile number'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('the arrows expand login and signup', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pump();

    expect(find.byKey(const Key('contact-field')), findsOneWidget);
    expect(find.byKey(const Key('signup-name')), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byKey(const Key('continue-google')), findsOneWidget);

    await _open(tester, const Key('auth-open-signup'));
    expect(find.text('Create account'), findsOneWidget);
    expect(find.byKey(const Key('contact-field')), findsOneWidget);
    expect(find.byKey(const Key('signup-name')), findsNothing);
    expect(find.byKey(const Key('continue-google')), findsOneWidget);
  });

  testWidgets('a raw provider error is shown as Homizi copy', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            rawEnvironment: 'staging',
            supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
            supabaseAnonKey: 'sb_publishable_example',
            policyVersion: '2026-10-11-draft',
          ),
        ),
        accountGatewayProvider.overrideWithValue(
          _Throws(
            'AuthApiException over_email_send_rate_limit supabase email rate limit exceeded',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    await _open(tester, const Key('auth-open-login'));
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'ananya.sharma@homizi.in',
    );
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.pump();

    expect(find.text(emailSendRateLimitMessage), findsWidgets);
    expect(find.textContaining('supabase'), findsNothing);
    expect(find.textContaining('Supabase'), findsNothing);
    expect(find.textContaining('over_email_send_rate_limit'), findsNothing);
  });

  testWidgets('login and signup each end on a confirmation screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        accountGatewayProvider.overrideWithValue(DemoAccountGateway()),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    await _open(tester, const Key('auth-open-login'));
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'ananya.sharma@homizi.in',
    );
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Thanks for logging in'), findsOneWidget);
    expect(find.byKey(const Key('login-continue')), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-continue')));
    await tester.pump();
    expect(find.text('Welcome!'), findsOneWidget);
  });

  testWidgets('signup confirms after the code', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        accountGatewayProvider.overrideWithValue(DemoAccountGateway()),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    await _open(tester, const Key('auth-open-signup'));
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'ananya.sharma@homizi.in',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.ensureVisible(find.byKey(const Key('verify-code')));
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();

    expect(find.text('Yeah..!'), findsOneWidget);
    expect(find.byKey(const Key('signup-confirmed')), findsOneWidget);
    expect(find.text('Signed up successfully'), findsOneWidget);
    expect(find.text('Choose your role'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(container.read(sessionProvider).homiziWire, isNull);
  });
}
