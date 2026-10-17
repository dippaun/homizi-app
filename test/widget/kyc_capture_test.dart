import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/kyc_launcher.dart';
import 'package:homizi/features/verification/kyc_providers.dart';
import 'package:homizi/features/verification/kyc_screen.dart';

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('kyc capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 50));
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

  Future<void> frame(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [kycLauncherProvider.overrideWithValue(_QuietLauncher())],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: RepaintBoundary(key: const Key('shot-frame'), child: child),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('consent screen', (tester) async {
    await frame(tester, const KycScreen());
    await shoot(tester, 'kyc-consent');
  });

  testWidgets('selfie step', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kycGatewayProvider.overrideWithValue(_CaptureGateway()),
          kycLauncherProvider.overrideWithValue(_QuietLauncher()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: const RepaintBoundary(
            key: Key('shot-frame'),
            child: KycScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('kyc-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('kyc-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await shoot(tester, 'kyc-selfie');
  });

  testWidgets('verified badges', (tester) async {
    const badges = UserBadges(
      phoneVerified: true,
      emailVerified: true,
      aadhaarVerified: true,
      faceVerified: true,
    );
    await frame(
      tester,
      Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          toolbarHeight: 80,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Meera K.'),
              IdentityBadgeRow(badges: badges),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text('Sunlit 2BHK in Koramangala'),
            SizedBox(height: 12),
            TrustBadgeRow(badges: badges),
            SizedBox(height: 24),
            Text('Arjun P.'),
            SizedBox(height: 8),
            IdentityBadgeRow(badges: badges),
          ],
        ),
      ),
    );
    await shoot(tester, 'kyc-verified-badges');
  });
}

class _QuietLauncher implements KycLauncher {
  @override
  Future<bool> open(Uri uri) async => false;
}

class _CaptureGateway implements KycGateway {
  var _consented = false;

  @override
  Future<KycSnapshot> current() async => KycSnapshot.notStarted;

  @override
  Future<KycSnapshot> giveConsent(KycDocumentKind kind) async {
    _consented = true;
    return const KycSnapshot(
      status: 'consent_given',
      aadhaarStatus: KycCheckState.notStarted,
      faceStatus: KycCheckState.notStarted,
      message: kycConsentCopy,
    );
  }

  @override
  Future<KycSnapshot> start(KycDocumentKind kind) async {
    if (!_consented) {
      throw const KycFailure('Consent is required before verification.');
    }
    return const KycSnapshot(
      status: 'pending',
      aadhaarStatus: KycCheckState.inProgress,
      faceStatus: KycCheckState.inProgress,
      gatewayUrl: 'https://app.digio.in/#/gateway/login/KID/person/token',
      message: 'Verification is in progress.',
    );
  }

  @override
  Future<KycSnapshot> deleteMine() async => KycSnapshot.notStarted;
}
