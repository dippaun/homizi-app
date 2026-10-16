import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/auth/login_screen.dart';

void main() {
  testWidgets('staging login asks for email and hides the development code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              rawEnvironment: 'staging',
              supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
              supabaseAnonKey: 'sb_publishable_example',
              policyVersion: '2026-10-11-draft',
              stagingPasswordAuth: true,
            ),
          ),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.textContaining('000000'), findsNothing);
    expect(find.textContaining('6-digit code'), findsWidgets);
    expect(find.textContaining('If the email contains a link'), findsOneWidget);
    expect(find.textContaining('Phone SMS is not connected'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.byKey(const Key('otp-field')), findsOneWidget);
    expect(find.byKey(const Key('password-sign-in')), findsOneWidget);
    expect(find.byKey(const Key('use-demo-mode')), findsOneWidget);
    expect(find.text('Enter the 6-digit code from the email.'), findsOneWidget);
    expect(find.textContaining('Optional'), findsNothing);
  });
}
