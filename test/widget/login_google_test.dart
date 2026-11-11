import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/auth/google_oauth.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _GoogleGateway implements AccountGateway {
  String? googleError;
  int googleCalls = 0;
  String? lastRedirect;

  @override
  Future<AccountSnapshot?> restore({required String policyVersion}) async =>
      null;

  @override
  Future<AccountSnapshot> signInDev({
    required AuthContact contact,
    required String policyVersion,
  }) async {
    return AccountSnapshot(
      contact: contact.displayContact,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<void> requestEmailOtp({required String email}) async {}

  @override
  Future<AccountSnapshot?> adoptMagicLinkSession({
    required String policyVersion,
    required bool recordConsent,
  }) async => null;

  @override
  Future<AccountSnapshot> signUpWithPassword({
    required String email,
    required String password,
    required String policyVersion,
    required String? emailRedirectTo,
  }) async {
    return AccountSnapshot(contact: email, policyVersion: policyVersion);
  }

  @override
  Future<AccountSnapshot> signInWithPasswordAccount({
    required String email,
    required String password,
    required String policyVersion,
  }) async {
    return AccountSnapshot(contact: email, policyVersion: policyVersion);
  }

  @override
  Future<void> ensureStagingTestUser({required String email}) async {}

  @override
  Future<void> signInWithGoogle({
    required String redirectTo,
    required String supabaseUrl,
    required String publishableKey,
  }) async {
    googleCalls += 1;
    lastRedirect = redirectTo;
    final error = googleError;
    if (error != null) {
      throw AccountFailure(error);
    }
  }

  @override
  Future<AccountSnapshot> verifyEmailOtp({
    required String email,
    required String code,
    required String policyVersion,
  }) async {
    return AccountSnapshot(
      userId: 'otp-user',
      contact: email,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<void> recordConsent({required String policyVersion}) async {}

  @override
  Future<void> setRole(AccountRole role) async {}

  @override
  Future<void> setPrimaryRole(String wire) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String> deleteAccount() async => 'Deleted on this device.';

  @override
  Future<TenantProfile> loadTenantProfile() async => const TenantProfile();

  @override
  Future<void> saveTenantProfile(TenantProfile profile) async {}

  @override
  Future<String> saveProfilePhoto(Uint8List pngBytes) async => '';

  @override
  Future<void> removeProfilePhoto() async {}

  @override
  Future<VerificationStatus> requestMockVerification() async =>
      VerificationStatus.mockPending;

  @override
  Future<HostProfile> loadHostProfile() async => const HostProfile();

  @override
  Future<void> saveHostProfile(HostProfile profile) async {}
}

Future<_GoogleGateway> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  final calls = _GoogleGateway();
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
      accountGatewayProvider.overrideWithValue(calls),
    ],
  );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(container.dispose);
  final session = container.read(sessionProvider.notifier);
  await session.finishBoot();
  await session.acceptConsent();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: HomiziTheme.light(), home: const LoginScreen()),
    ),
  );
  await tester.pump();
  return calls;
}

void main() {
  testWidgets('Continue with Google sits under the email code', (tester) async {
    await _pump(tester);

    expect(find.byKey(const Key('continue-with-google')), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byKey(const Key('google-logo')), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.byKey(const Key('continue-with-apple')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('continue-with-google'))).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('verify-code'))).dy,
      ),
    );

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('continue-with-google')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, GoogleSignInColors.fill);
    expect(material.color, isNot(HomiziColors.brandYellow));
    expect(material.color, isNot(GoogleSignInColors.yellow));
    final label = tester.widget<Text>(find.text('Continue with Google'));
    expect(label.style?.color, GoogleSignInColors.label);
    expect(label.style?.color, isNot(HomiziColors.white));
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a disabled Google provider shows a friendly message', (
    tester,
  ) async {
    final calls = await _pump(tester);
    calls.googleError = googleProviderNotEnabledMessage;
    await tester.ensureVisible(find.byKey(const Key('continue-with-google')));
    await tester.tap(find.byKey(const Key('continue-with-google')));
    await tester.pumpAndSettle();

    expect(calls.googleCalls, 1);
    expect(calls.lastRedirect, googleOAuthRedirect);
    expect(find.byKey(const Key('google-sign-in-error')), findsOneWidget);
    expect(find.text(googleProviderNotEnabledMessage), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const Key('verify-code')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
