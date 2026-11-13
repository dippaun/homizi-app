import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/roommates/demo_roommate_gateway.dart';
import 'package:homizi/features/roommates/finder/finder_catalog.dart';
import 'package:homizi/features/roommates/finder/roommate_routes.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/roommates/roommate_screen.dart';

void main() {
  testWidgets('roommate finder screenshots at 390x844 scale 2', (tester) async {
    final dir = Platform.environment['HOMIZI_ROOMMATE_SHOTS'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: RoutePaths.roommate,
      routes: [
        GoRoute(
          path: RoutePaths.roommate,
          builder: (context, state) => const RoommateScreen(),
        ),
        ...roommateFinderRoutes(),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ownVerificationProvider.overrideWith(VerifiedSession.new),
          roommateGatewayProvider.overrideWithValue(DemoRoommateGateway()),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(RoommateScreen));
    await tester.runAsync(() async {
      for (final person in finderPeople) {
        for (final photo in person.gallery) {
          await precacheImage(AssetImage(photo), context);
        }
      }
    });
    await tester.pumpAndSettle();

    Future<void> shoot(String name, Key key) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await shoot('01-finder', const Key('roommate-shot'));
    await tester.tap(find.byKey(const Key('roommate-filters')));
    await tester.pumpAndSettle();
    await shoot('02-filters', const Key('roommate-filter-shot'));
    await tester.tap(find.byKey(const Key('roommate-apply-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('roommate-tab-requirements')));
    await tester.pumpAndSettle();
    await shoot('03-requirements', const Key('roommate-shot'));
    await tester.tap(find.byKey(const Key('roommate-tab-find')));
    await tester.pumpAndSettle();

    final aditi = finderPeople.firstWhere(
      (person) => person.name == 'Aditi Mehta',
    );
    await tester.tap(find.byKey(Key('roommate-open-${aditi.id}')));
    await tester.pumpAndSettle();
    await shoot('04-preview', const Key('roommate-preview-shot'));

    await tester.tap(find.byKey(const Key('roommate-preview-interested')));
    await tester.pumpAndSettle();
    await shoot('05-its-a-match', const Key('roommate-match-shot'));
  });
}

Future<void> _loadCaptureFonts() async {
  final sans = FontLoader('PlusJakartaSans');
  for (final name in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();
  final inter = FontLoader('Inter');
  for (final name in const [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    inter.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await inter.load();
}
