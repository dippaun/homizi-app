import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/tenant_flow/tenant_flow_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFlow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: const TenantFlowScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> goNext(WidgetTester tester) async {
    final button = find.byKey(const Key('tenant-flow-next'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('tenant flow walks explainers, match, chat, and visit booked', (
    tester,
  ) async {
    await pumpFlow(tester);
    expect(find.byKey(const Key('tenant-flow-intro')), findsOneWidget);
    expect(find.byType(HomiziBackButton), findsOneWidget);
    expect(find.text('Smart Matching'), findsOneWidget);
    expect(find.text('for Better Living'), findsOneWidget);

    await goNext(tester);
    expect(
      find.byKey(const Key('tenant-flow-priorities-explain')),
      findsOneWidget,
    );
    expect(find.text('1/6'), findsOneWidget);
    expect(find.text('Preferred Location'), findsWidgets);
    expect(find.byType(HomiziBackButton), findsOneWidget);

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-host-explain')), findsOneWidget);
    expect(find.text('2/6'), findsOneWidget);
    expect(find.text('Working Professional'), findsOneWidget);

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-how')), findsOneWidget);
    expect(find.text('3/6'), findsOneWidget);

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-results')), findsOneWidget);
    expect(find.text('4/6'), findsOneWidget);
    expect(find.text('Properties'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tenant-tab-roomies')));
    await tester.pumpAndSettle();
    expect(find.text('Ananya Iyer'), findsWidgets);

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-score')), findsOneWidget);
    expect(find.text('5/6'), findsOneWidget);
    expect(find.textContaining('Total Compatibility Score'), findsOneWidget);

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-colour')), findsOneWidget);
    expect(find.text('6/6'), findsOneWidget);
    expect(find.text('70–100%'), findsOneWidget);
    expect(find.text('40–69%'), findsOneWidget);
    expect(find.text('0–39%'), findsOneWidget);

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-happier')), findsOneWidget);
    expect(find.text('Happier People'), findsOneWidget);

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-journey')), findsOneWidget);
    expect(find.text('Simple. Smart. Social.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Your Best Matches First'), 400);
    expect(find.text('Mandatory Photo Sequence'), findsOneWidget);

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-rank')), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tenant-side-host')));
    await tester.pump();
    expect(find.text('Non-Smoker'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tenant-side-tenant')));
    await tester.pump();

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-browse')), findsOneWidget);
    expect(find.byKey(const Key('tenant-browse-list')), findsOneWidget);

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-swipe')), findsOneWidget);
    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-detail')), findsOneWidget);
    expect(find.textContaining('Room (Main Photo)'), findsOneWidget);
    await tester.tap(find.byType(HomiziBackButton));
    await tester.pump();
    await tester.tap(find.byType(HomiziBackButton));
    await tester.pump();
    expect(find.byKey(const Key('tenant-flow-browse')), findsOneWidget);

    final interested = find.byKey(
      const Key('tenant-interested-lst_match_bandra'),
    );
    await tester.ensureVisible(interested);
    await tester.tap(interested);
    await tester.pump();
    expect(find.byKey(const Key('tenant-flow-match')), findsOneWidget);
    expect(find.text("It's a Match!"), findsOneWidget);

    await goNext(tester);
    expect(find.byKey(const Key('tenant-flow-chat')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('tenant-chat-field')),
      'call 9876543210',
    );
    await tester.tap(find.byKey(const Key('tenant-chat-send')));
    await tester.pump();
    expect(find.textContaining('9876543210'), findsNothing);
    expect(find.textContaining('hidden because it included'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tenant-share-contact')));
    await tester.pump();
    expect(find.byKey(const Key('tenant-flow-contact')), findsOneWidget);
    expect(find.textContaining('phone number stays off'), findsOneWidget);
    await tester.tap(find.byType(HomiziBackButton));
    await tester.pump();

    await tester.tap(find.byKey(const Key('tenant-share-docs')));
    await tester.pump();
    expect(find.byKey(const Key('tenant-flow-docs')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tenant-flow-next')));
    await tester.pump();
    expect(find.textContaining('No file was uploaded'), findsOneWidget);
    await tester.tap(find.byType(HomiziBackButton));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('tenant-schedule-visit')));
    await tester.tap(find.byKey(const Key('tenant-schedule-visit')));
    await tester.pump();
    expect(find.byKey(const Key('tenant-flow-visit')), findsOneWidget);
    await tester.tap(find.text('Saturday 11:00 AM'));
    await tester.pump();
    expect(find.byKey(const Key('tenant-flow-booked')), findsOneWidget);
    expect(find.text('Visit booked'), findsWidgets);
    expect(find.text('Saturday 11:00 AM'), findsOneWidget);
    expect(find.byType(HomiziBackButton), findsOneWidget);
  });
}
