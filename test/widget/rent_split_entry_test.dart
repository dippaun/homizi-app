import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/roommates/demo_roommate_gateway.dart';
import 'package:homizi/features/roommates/mutual_interest_screen.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/tools/rent_split/rent_split_repository.dart';
import 'package:homizi/features/tools/split_screen.dart';

void main() {
  testWidgets('mutual interest opens the rent split with roommate names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = DemoRoommateGateway();
    final mutual = await gateway.mutual();
    final router = GoRouter(
      initialLocation: '/mutual',
      routes: [
        GoRoute(
          path: '/mutual',
          builder: (context, state) => const MutualInterestScreen(),
        ),
        GoRoute(
          path: RoutePaths.rentSplit,
          builder: (context, state) => SplitScreen(
            roommates: splitRoommatesFromQuery(
              state.uri.queryParameters['with'],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roommateGatewayProvider.overrideWithValue(gateway),
          rentSplitRepositoryProvider.overrideWithValue(
            RentSplitRepository(
              local: MemoryRentSplitStore(),
              remote: const SkippingRentSplitRemote(),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (mutual.isEmpty) {
      expect(find.byKey(const Key('mutual-split-rent')), findsNothing);
      return;
    }
    await tester.tap(find.byKey(const Key('mutual-split-rent')));
    await tester.pumpAndSettle();
    expect(find.text('Set up rent split'), findsOneWidget);
    final expected = (mutual.take(5).length + 1).clamp(1, 12);
    expect(
      tester.widget<Text>(find.byKey(const Key('split-people'))).data,
      '$expected',
    );
  });
}
