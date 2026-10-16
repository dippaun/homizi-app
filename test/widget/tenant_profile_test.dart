import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/profile/tenant_profile_screen.dart';

void main() {
  testWidgets('tenant profile saves name, bio, and preferences', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accounts = DemoAccountGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              supabaseUrl: '',
              supabaseAnonKey: '',
              policyVersion: '2026-10-11-draft',
            ),
          ),
          accountGatewayProvider.overrideWith((ref) => accounts),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const TenantProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('tenant-display-name')),
      'Ananya',
    );
    await tester.enterText(find.byKey(const Key('tenant-bio')), 'Quiet weeks.');
    await tester.enterText(find.byKey(const Key('tenant-budget-min')), '10000');
    await tester.enterText(find.byKey(const Key('tenant-budget-max')), '25000');
    await tester.enterText(
      find.byKey(const Key('tenant-localities')),
      'Koramangala, HSR',
    );
    await tester.ensureVisible(find.byKey(const Key('pref-type-apartment')));
    await tester.tap(find.byKey(const Key('pref-type-apartment')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-tenant-profile')));
    await tester.tap(find.byKey(const Key('save-tenant-profile')));
    await tester.pumpAndSettle();

    final saved = await accounts.loadTenantProfile();
    expect(saved.displayName, 'Ananya');
    expect(saved.bio, 'Quiet weeks.');
    expect(saved.preferences.budgetMinInr, 10000);
    expect(saved.preferences.budgetMaxInr, 25000);
    expect(saved.preferences.localities, ['Koramangala', 'HSR']);
    expect(saved.preferences.propertyTypes, ['apartment']);
    expect(find.textContaining('Profile saved'), findsOneWidget);
  });
}
