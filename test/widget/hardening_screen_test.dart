import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/safety/domain/safety_rules.dart';
import 'package:homizi/features/safety/report_block_screen.dart';
import 'package:homizi/features/settings/settings_screen.dart';
import 'package:homizi/features/support/help_screen.dart';

void main() {
  testWidgets('a report drops contact details and does not show an id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReportBlockScreen(
            targetType: 'property',
            targetId: 'lst_koramangala',
            blockedUserId: '9876543210',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('a listing'), findsOneWidget);
    expect(find.textContaining('lst_koramangala'), findsNothing);
    expect(find.textContaining('9876543210'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    expect(
      find.text('This report has no account id to block.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('report-details')),
      'call 9876543210',
    );
    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('cannot carry contact'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('report-confirmation')),
        matching: find.textContaining('9876543210'),
      ),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('report-details')),
      'The photos do not match.',
    );
    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Kept on this device'), findsOneWidget);
    expect(find.byKey(const Key('report-confirmation')), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(reportReasonValues, contains('spam'));
  });

  testWidgets('help and settings stay usable with larger text', (tester) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: MaterialApp(home: HelpScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('How do I delete my account?'),
      400,
    );
    expect(find.text('How do I delete my account?'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);

    await tester.pumpWidget(
      const ProviderScope(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: MaterialApp(home: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('delete-account')),
      400,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-account-confirm')), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.byKey(const Key('delete-account-confirm')),
    );
    expect(confirm.onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Deleted on this device'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
