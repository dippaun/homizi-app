import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 520);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: HomiziTheme.light(),
      home: Scaffold(body: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state golden', (tester) async {
    await _pump(
      tester,
      const EmptyState(
        title: 'No homes match',
        message: 'Try a wider budget or clear the filters.',
      ),
    );
    await expectLater(
      find.byType(EmptyState),
      matchesGoldenFile('goldens/empty_state.png'),
    );
  });

  testWidgets('map preview golden', (tester) async {
    await _pump(
      tester,
      const Padding(
        padding: EdgeInsets.all(16),
        child: LocationBlock(locality: 'Koramangala', city: 'Bengaluru'),
      ),
    );
    await expectLater(
      find.byKey(const Key('map-preview')),
      matchesGoldenFile('goldens/map_preview.png'),
    );
  });
}
