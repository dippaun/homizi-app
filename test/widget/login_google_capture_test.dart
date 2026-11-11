import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
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
import 'package:homizi/l10n/app_localizations.dart';

class _ShotGateway implements AccountGateway {
  String? googleError;

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
    return AccountSnapshot(contact: email, policyVersion: policyVersion);
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

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final file in files) {
      final bytes = await File('assets/fonts/$file').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await family('PlusJakartaSans', const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
  ]);
  await family('Inter', const [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]);
  await family('Roboto', const ['Roboto-Medium.ttf']);

  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = root == null || root.isEmpty
      ? File(
          '${File(Platform.resolvedExecutable).parent.parent.parent.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
        )
      : File(
          '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
  if (!icons.existsSync()) {
    throw StateError('MaterialIcons font missing at ${icons.path}');
  }
  final material = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
  await material.load();
}

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('google sign-in screenshots stay out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  testWidgets('capture the Google button and the not-enabled message', (
    tester,
  ) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calls = _ShotGateway();
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
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: const Key('shot-frame'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    Future<void> shoot(String name) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('shot-frame')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.ensureVisible(find.byKey(const Key('continue-with-google')));
    await tester.pump();
    await shoot('signup-google');
    calls.googleError = googleProviderNotEnabledMessage;
    await tester.tap(find.byKey(const Key('continue-with-google')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('google-sign-in-error')));
    await tester.pump();
    await shoot('signup-google-not-enabled');
    expect(find.text(googleProviderNotEnabledMessage), findsOneWidget);
  });
}
