import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/discovery/filter_screen.dart';
import 'package:homizi/features/profile/tenant_profile_screen.dart';

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('range slider capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  const config = AppConfig(
    environment: AppEnvironment.dev,
    supabaseUrl: '',
    supabaseAnonKey: '',
    policyVersion: '2026-10-11-draft',
  );

  Future<void> shoot(WidgetTester tester, String name) async {
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

  testWidgets('capture the tenant budget slider', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accounts = DemoAccountGateway();
    await accounts.saveTenantProfile(
      const TenantProfile(
        displayName: 'Ananya Rao',
        occupation: 'Product designer',
        preferences: TenantPreferences(
          budgetMinInr: 12000,
          budgetMaxInr: 35000,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          accountGatewayProvider.overrideWith((ref) => accounts),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: const RepaintBoundary(
            key: Key('shot-frame'),
            child: TenantProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final budget = find.byKey(const Key('tenant-budget-value'));
    await tester.ensureVisible(budget);
    await tester.pumpAndSettle();
    final budgetTop = tester.getTopLeft(budget).dy;
    if (budgetTop > 180) {
      await tester.drag(
        find.byType(Scrollable).first,
        Offset(0, 180 - budgetTop),
      );
      await tester.pumpAndSettle();
    }
    await shoot(tester, 'tenant-profile-budget-slider');
    expect(find.text('₹12,000 – ₹35,000'), findsOneWidget);
  });

  testWidgets('capture the filter rent slider', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: const RepaintBoundary(
            key: Key('shot-frame'),
            child: FilterScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final band = find.text('₹20,000–₹35,000');
    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pumpAndSettle();
    await tester.tap(band);
    await tester.pumpAndSettle();
    final rent = find.byKey(const Key('filter-rent-value'));
    await tester.ensureVisible(rent);
    await tester.pumpAndSettle();
    final rentTop = tester.getTopLeft(rent).dy;
    if (rentTop > 160) {
      await tester.drag(
        find.byType(Scrollable).first,
        Offset(0, 160 - rentTop),
      );
      await tester.pumpAndSettle();
    }
    await shoot(tester, 'filter-sheet-rent-slider');
    expect(find.text('₹20,000 – ₹35,000'), findsOneWidget);
  });
}
