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
import 'package:homizi/features/broker_flow/broker_flow_screen.dart';

const _demoConfig = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
  demoSkipLogin: true,
);

void main() {
  testWidgets('broker flow screenshots at 390x844 scale 2', (tester) async {
    final dir = Platform.environment['HOMIZI_BROKER_SHOTS'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(_demoConfig)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: const BrokerFlowScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    Future<void> shoot(String name) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('broker-flow-shot')),
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

    Future<void> tap(Key key) async {
      final finder = find.byKey(key);
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
    }

    await shoot('01-profile');
    await tap(const Key('broker-flow-continue'));
    await shoot('02-verify');
    await tap(const Key('broker-send-mobile'));
    await tester.enterText(
      find.byKey(const Key('broker-mobile-otp')),
      '000000',
    );
    await tap(const Key('broker-verify-mobile'));
    await tap(const Key('broker-send-email'));
    await tester.enterText(find.byKey(const Key('broker-email-otp')), '000000');
    await tap(const Key('broker-verify-email'));
    await tap(const Key('broker-open-digio'));
    await shoot('03-verify-checked');
    await tap(const Key('broker-flow-continue'));
    await shoot('04-trust-badge');
    await tap(const Key('broker-flow-continue'));
    await shoot('05-onboarding-confirmation');
    await tap(const Key('broker-flow-continue'));
    await shoot('06-listing-intro');
    await tap(const Key('broker-flow-continue'));
    await shoot('07-start-listing');
    await tap(const Key('broker-flow-continue'));
    await shoot('08-location');
    await tap(const Key('broker-flow-continue'));
    await shoot('09-nearby');
    await tap(const Key('broker-flow-continue'));
    await shoot('10-living');
    await tap(const Key('broker-flow-continue'));
    await shoot('11-rules');
    await tap(const Key('broker-flow-continue'));
    await shoot('12-services');
    await tap(const Key('broker-flow-continue'));
    await shoot('13-rent');
    await tap(const Key('broker-owner-auth-toggle'));
    await tap(const Key('broker-owner-auth-upload'));
    await shoot('14-rent-authorisation');
    await tap(const Key('broker-flow-continue'));
    await shoot('15-photos');
    await tap(const Key('broker-flow-continue'));
    await shoot('16-review');
    await tap(const Key('broker-flow-publish'));
    await shoot('17-published');
    await tap(const Key('broker-flow-continue'));
    await tester.pump(const Duration(milliseconds: 50));
    await shoot('18-desk');
    await tap(const Key('broker-flow-continue'));
    await shoot('19-confirmation');
  });
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

  final inter = FontLoader('Inter');
  for (final name in const [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    inter.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await inter.load();

  final icons = File(_materialIconsPath());
  final material = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
  await material.load();
}

String _materialIconsPath() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    return '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  }
  return '${Platform.resolvedExecutable}/../../../artifacts/material_fonts/MaterialIcons-Regular.otf';
}
