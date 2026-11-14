import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

/// Writes 390x844 (DPR 2) screenshots of every KYC state when
/// HOMIZI_CAPTURE_DIR is set. CI skips it.
void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('kyc capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  setUpAll(_loadCaptureFonts);

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

  Future<void> frame(
    WidgetTester tester,
    Widget child, {
    KycGateway? gateway,
  }) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 1688);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (gateway != null) kycGatewayProvider.overrideWithValue(gateway),
          kycLauncherProvider.overrideWithValue(_QuietLauncher()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: RepaintBoundary(key: const Key('shot-frame'), child: child),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pump();
  }

  final now = DateTime.utc(2026, 11, 14, 12);
  Widget screen() => KycScreen(now: () => now);

  testWidgets('coming soon', (tester) async {
    await frame(tester, screen());
    await shoot(tester, 'kyc-1-coming-soon');
  });

  testWidgets('every step of the live flow', (tester) async {
    final gateway = _CaptureGateway();
    await frame(tester, screen(), gateway: gateway);
    await shoot(tester, 'kyc-2-intro');
    await tap(tester, 'kyc-get-started');
    await shoot(tester, 'kyc-3-method');
    await tap(tester, 'kyc-method-next');
    await tap(tester, 'kyc-consent');
    await shoot(tester, 'kyc-4-consent');
    await tap(tester, 'kyc-continue');
    await shoot(tester, 'kyc-5-face-step');
    await tap(tester, 'kyc-open-digio');
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, 'kyc-6-pending');
  });

  testWidgets('failed', (tester) async {
    final gateway = _CaptureGateway()
      ..started = true
      ..stage = const KycSnapshot(
        status: 'rejected',
        aadhaarStatus: KycCheckState.verified,
        faceStatus: KycCheckState.failed,
        message: '',
      );
    await frame(tester, screen(), gateway: gateway);
    await shoot(tester, 'kyc-7-failed');
  });

  testWidgets('expired', (tester) async {
    final gateway = _CaptureGateway()
      ..started = true
      ..stage = KycSnapshot(
        status: 'pending',
        aadhaarStatus: KycCheckState.inProgress,
        faceStatus: KycCheckState.inProgress,
        message: '',
        startedAt: now.subtract(const Duration(days: 12)),
      );
    await frame(tester, screen(), gateway: gateway);
    await shoot(tester, 'kyc-8-expired');
  });

  testWidgets('verified', (tester) async {
    final gateway = _CaptureGateway()
      ..started = true
      ..stage = const KycSnapshot(
        status: 'verified',
        aadhaarStatus: KycCheckState.verified,
        faceStatus: KycCheckState.verified,
        maskedLast4: '4821',
        message: '',
      );
    await frame(tester, screen(), gateway: gateway);
    await shoot(tester, 'kyc-9-verified');
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
          toolbarHeight: 96,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Meera K.'),
              SizedBox(height: 4),
              IdentityBadgeRow(badges: badges),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text('Listing host'),
            SizedBox(height: 8),
            TrustBadgeRow(badges: badges),
            SizedBox(height: 24),
            Text('Roommate card'),
            SizedBox(height: 8),
            IdentityBadgeRow(badges: badges),
          ],
        ),
      ),
    );
    await shoot(tester, 'kyc-10-badges');
  });
}

class _QuietLauncher implements KycLauncher {
  @override
  Future<bool> open(Uri uri) async => true;
}

class _CaptureGateway implements KycGateway {
  var started = false;
  KycSnapshot stage = const KycSnapshot(
    status: 'pending',
    aadhaarStatus: KycCheckState.verified,
    faceStatus: KycCheckState.inProgress,
    gatewayUrl:
        'https://app.digio.in/#/gateway/login/KID/person/token?redirect_url=x',
    message: '',
  );

  @override
  Future<bool> available() async => true;

  @override
  Future<KycSnapshot> current() async =>
      started ? stage : KycSnapshot.notStarted;

  @override
  Future<KycSnapshot> giveConsent(KycDocumentKind kind) async {
    return const KycSnapshot(
      status: 'consent_given',
      aadhaarStatus: KycCheckState.notStarted,
      faceStatus: KycCheckState.notStarted,
      message: kycConsentCopy,
    );
  }

  @override
  Future<KycSnapshot> start(KycDocumentKind kind, {String? returnUrl}) async {
    started = true;
    return stage;
  }

  @override
  Future<KycSnapshot> deleteMine() async => KycSnapshot.notStarted;
}

Future<void> _loadCaptureFonts() async {
  final sans = FontLoader('PlusJakartaSans');
  for (final name in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final path = root != null && root.isNotEmpty
      ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
      : '${Platform.resolvedExecutable}/../../../artifacts/material_fonts/MaterialIcons-Regular.otf';
  final material = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(ByteData.sublistView(await File(path).readAsBytes())),
    );
  await material.load();
}
