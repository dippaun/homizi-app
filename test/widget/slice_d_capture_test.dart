import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/agreements/agreements_screen.dart';
import 'package:homizi/features/discovery/explore_screen.dart';
import 'package:homizi/features/payments/payments_screen.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/services/service_request_screen.dart';
import 'package:homizi/features/services/services_hub_screen.dart';
import 'package:homizi/features/services/staff_service_leads_screen.dart';
import 'package:homizi/features/verification/kyc_screen.dart';

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('slice D capture stays out of CI', () {
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
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: RepaintBoundary(key: const Key('shot-frame'), child: child),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('explore map', (tester) async {
    await frame(tester, const ExploreScreen());
    await tester.tap(find.text('Map'));
    await tester.pump();
    await shoot(tester, 'explore-map');
  });

  testWidgets('pay rent', (tester) async {
    await frame(tester, const PaymentsScreen());
    await shoot(tester, 'pay-rent');
  });

  testWidgets('rent agreement', (tester) async {
    await frame(tester, const AgreementsScreen());
    await shoot(tester, 'rent-agreement');
  });

  testWidgets('verify identity', (tester) async {
    await frame(tester, const KycScreen());
    await shoot(tester, 'verify-identity');
  });

  testWidgets('home services', (tester) async {
    await frame(tester, const ServicesHubScreen());
    await shoot(tester, 'home-services');
  });

  testWidgets('service request', (tester) async {
    await frame(tester, const ServiceRequestScreen(kind: ServiceKind.cleaning));
    await shoot(tester, 'service-request');
  });

  testWidgets('staff service leads', (tester) async {
    await frame(tester, const StaffServiceLeadsScreen());
    await tester.pump();
    await shoot(tester, 'staff-service-leads');
  });
}
