import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/tools/domain/smart_move.dart';
import 'package:homizi/features/tools/smart_liver_screen.dart';
import 'package:homizi/features/tools/smart_move_screen.dart';

void main() {
  setUp(SmartMoveInterestStore.instance.clear);

  testWidgets('Smart Liver calculates a healthy rent band', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const SmartLiverScreen(),
        ),
      ),
    );

    expect(find.byKey(const Key('smart-liver-screen')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('smart-liver-income')),
      '60000',
    );
    await tester.tap(find.byKey(const Key('smart-liver-calculate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('smart-liver-result')), findsOneWidget);
    expect(find.byKey(const Key('smart-liver-range')), findsOneWidget);
    expect(find.byKey(const Key('smart-liver-tip')), findsOneWidget);
    expect(find.textContaining('₹15,000'), findsWidgets);
  });

  testWidgets('Smart Move shows disclaimer, maths, and interest confirm', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SmartMoveScreen(),
        ),
        GoRoute(
          path: '/demo/done',
          builder: (context, state) => Scaffold(
            key: const Key('demo-success-screen'),
            body: Text(state.uri.queryParameters['title'] ?? 'Done'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    expect(find.byKey(const Key('smart-move-disclaimer')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('smart-move-rent')), '20000');
    await tester.enterText(find.byKey(const Key('smart-move-years')), '5');
    await tester.tap(find.byKey(const Key('smart-move-calculate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('smart-move-result')), findsOneWidget);
    expect(find.byKey(const Key('smart-move-paid')), findsOneWidget);
    expect(find.textContaining('₹12,00,000'), findsOneWidget);
    expect(find.textContaining('₹8,40,000'), findsOneWidget);

    final list = find.byType(Scrollable);
    await tester.scrollUntilVisible(
      find.byKey(const Key('smart-move-name')),
      300,
      scrollable: list.first,
    );
    await tester.enterText(
      find.byKey(const Key('smart-move-name')),
      'Kabir Shah',
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('smart-move-contact')),
      200,
      scrollable: list.first,
    );
    await tester.enterText(
      find.byKey(const Key('smart-move-contact')),
      'kabir@homizi.in',
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('smart-move-interest')),
      200,
      scrollable: list.first,
    );
    await tester.tap(find.byKey(const Key('smart-move-interest')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo-success-screen')), findsOneWidget);
    expect(SmartMoveInterestStore.instance.rows, hasLength(1));
  });
}
