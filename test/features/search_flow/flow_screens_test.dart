import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/search_flow/broker_flat_screen.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:homizi/features/search_flow/flow_swipe_screen.dart';
import 'package:homizi/features/search_flow/requirements_screen.dart';
import 'package:homizi/features/search_flow/tenant_kind_screen.dart';

Future<void> _pump(WidgetTester tester, Widget screen, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('requirements stay editable and are reused', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(flowPrefsProvider.notifier).update(
      container.read(flowPrefsProvider).copyWith(
        budgetMin: 22000,
        budgetMax: 40000,
        note: 'Near the metro',
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FlowRequirementsScreen()),
      ),
    );
    expect(find.text('22000'), findsOneWidget);
    expect(find.text('40000'), findsOneWidget);
    final note = tester.widget<TextField>(
      find.byKey(const Key('flow-preference-note')),
    );
    expect(note.controller?.text, 'Near the metro');
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('search screens fit a phone and a wide window', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const screens = <Widget>[
      TenantKindScreen(),
      FlowRequirementsScreen(),
      BrokerFlatScreen(),
      FlowSwipeScreen(deck: 'property'),
      FlowSwipeScreen(deck: 'demand'),
      FlowSwipeScreen(deck: 'people'),
    ];
    for (final size in const [Size(360, 800), Size(1280, 900)]) {
      for (final screen in screens) {
        await _pump(tester, screen, size);
        expect(tester.takeException(), isNull);
        expect(find.byType(BackButton), findsOneWidget);
      }
    }
  });
}
