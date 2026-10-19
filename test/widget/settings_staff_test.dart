import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/moderation/moderation_providers.dart';
import 'package:homizi/features/settings/settings_screen.dart';

void main() {
  testWidgets('analytics can be turned off and staff see the queue link', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [staffStatusProvider.overrideWith((ref) async => true)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('open-moderation')),
      400,
    );
    expect(find.byKey(const Key('open-moderation')), findsOneWidget);
    expect(find.textContaining('No phone number or email'), findsOneWidget);
    final sharing = tester.widget<SwitchListTile>(
      find.byKey(const Key('analytics-sharing')),
    );
    expect(sharing.value, isTrue);

    await tester.tap(find.byKey(const Key('analytics-sharing')));
    await tester.pump();
    expect(container.read(analyticsOptOutProvider), isTrue);
    expect(find.textContaining('@'), findsNothing);
  });
}
