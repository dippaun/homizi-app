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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              rawEnvironment: 'staging',
              supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
              supabaseAnonKey: 'sb_publishable_example',
              policyVersion: '2026-10-11-draft',
            ),
          ),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.textContaining('000000'), findsNothing);
    expect(find.textContaining('Phone SMS is not connected'), findsOneWidget);
  });
}
