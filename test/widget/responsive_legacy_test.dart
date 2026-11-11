import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/matching/match_routes.dart';
import 'package:homizi/features/owner/for_owners_screen.dart';
import 'package:homizi/features/seekers/seekers_screen.dart';

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('match feed swipe deck fits at ${width.toInt()}px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: RoutePaths.matchFeed,
        routes: intelligentMatchRoutes(),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: HomiziTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('match-feed')), findsOneWidget);
      expect(find.text('Interested'), findsOneWidget);
      expect(find.byType(HomiziFrame), findsWidgets);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('legacy seekers and owners fit at ${width.toInt()}px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: HomiziTheme.light(),
            home: const SeekersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HomiziFrame), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ForOwnersScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: HomiziTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HomiziFrame), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });
  }
}
