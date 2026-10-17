import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/explore_screen.dart';
import 'package:homizi/features/payments/payments_screen.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/services/service_request_screen.dart';
import 'package:homizi/features/verification/kyc_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: HomiziTheme.light(), home: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('explore can switch from the list to the map', (tester) async {
    await pump(tester, const ExploreScreen());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('explore-view-toggle')), findsOneWidget);
    await tester.tap(find.text('Map'));
    await tester.pump();
    expect(find.byKey(const Key('osm-attribution')), findsOneWidget);
  });

  testWidgets('pay rent shows the test-mode banner and a demo result', (
    tester,
  ) async {
    await pump(tester, const PaymentsScreen());
    await tester.pump();
    expect(find.byKey(const Key('payments-test-banner')), findsOneWidget);
    expect(find.textContaining('Test mode'), findsOneWidget);
    await tester.tap(find.byKey(const Key('payment-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('payment-success')), findsOneWidget);
    await tester.tap(find.byKey(const Key('payment-success')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('identity check asks for consent and does not invent a pass', (
    tester,
  ) async {
    await pump(tester, const KycScreen());
    await tester.pump();
    expect(find.byKey(const Key('kyc-consent-copy')), findsOneWidget);
    expect(find.textContaining('Aadhaar'), findsWidgets);
    await tester.tap(find.byKey(const Key('kyc-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('kyc-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('kyc-coming-soon')), findsOneWidget);
    expect(find.text('Aadhaar verified'), findsNothing);
    expect(find.textContaining('123456789012'), findsNothing);
  });

  testWidgets('a cleaning request says a partner will call', (tester) async {
    await pump(tester, const ServiceRequestScreen(kind: ServiceKind.cleaning));
    await tester.pump();
    expect(find.textContaining('HOMIZI partner'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('service-from')),
      'Koramangala',
    );
    await tester.tap(find.byKey(const Key('service-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('service-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Requested'), findsOneWidget);
    expect(find.textContaining('not a confirmed booking'), findsWidgets);
  });
}
