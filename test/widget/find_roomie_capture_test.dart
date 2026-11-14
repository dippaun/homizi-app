import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/find_roomie/find_roomie_catalog.dart';
import 'package:homizi/features/find_roomie/find_roomie_providers.dart';
import 'package:homizi/features/find_roomie/find_roomie_store.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'test@homizi.in',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _EmptyDiscovery extends DiscoveryController {
  @override
  DiscoveryState build() => const DiscoveryState();
}

/// 390×844 phone frames for the screenshots branch. No-op unless
/// HOMIZI_FIND_ROOMIE_SHOTS is set, so the suite stays green.
void main() {
  testWidgets('find your roomie screenshots at 390x844', (tester) async {
    final dir = Platform.environment['HOMIZI_FIND_ROOMIE_SHOTS'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_ReadySession.new),
          discoveryProvider.overrideWith(_EmptyDiscovery.new),
          findRoomieLocalProvider.overrideWithValue(MemoryFindRoomieLocal()),
        ],
        child: const HomiziApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('home-screen'))),
    );

    Future<void> shoot(String name) async {
      await tester.pump();
      final view = tester.binding.renderViews.single;
      final layer = view.debugLayer;
      if (layer is! OffsetLayer) {
        throw StateError('The view has no layer to capture.');
      }
      await tester.runAsync(() async {
        final image = await layer.toImage(
          Offset.zero & view.size,
          pixelRatio: 2,
        );
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    router.go(RoutePaths.roommate);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('find-roomie-entry')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await _settlePhotos(tester);
    await shoot('find-roomie-00-entry');

    await tester.tap(find.byKey(const Key('find-roomie-entry')));
    await tester.pumpAndSettle();
    await _settlePhotos(tester);
    await shoot('find-roomie-01-connect');

    final mira = sampleFindRoomieDeck().people.first;
    await tester.scrollUntilVisible(
      find.byKey(Key('find-roomie-connect-${mira.id}')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(Key('find-roomie-connect-${mira.id}')));
    await tester.pumpAndSettle();
    await _settlePhotos(tester);
    await shoot('find-roomie-02-match');

    await tester.scrollUntilVisible(
      find.byKey(const Key('find-roomie-explore')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('find-roomie-explore')));
    await tester.pumpAndSettle();
    await _settlePhotos(tester);
    await shoot('find-roomie-03-explore');

    final home = sampleFindRoomieHomes.first;
    await tester.scrollUntilVisible(
      find.byKey(Key('find-roomie-request-${home.id}')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(Key('find-roomie-request-${home.id}')));
    await tester.pumpAndSettle();
    await shoot('find-roomie-04-request');

    await tester.scrollUntilVisible(
      find.byKey(const Key('find-roomie-self-confirm')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('find-roomie-self-confirm')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('find-roomie-partner-confirm')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('find-roomie-partner-confirm')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('find-roomie-open-home')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('find-roomie-open-home')));
    await tester.pumpAndSettle();
    await _settlePhotos(tester);
    await shoot('find-roomie-05-shared-home');

    router.pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('find-roomie-to-confirm')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('find-roomie-to-confirm')));
    await tester.pumpAndSettle();
    await shoot('find-roomie-06-confirm');
  });
}

Future<void> _settlePhotos(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).last);
  await tester.runAsync(() async {
    for (final person in sampleFindRoomieDeck().people) {
      final photo = person.photoRef;
      if (photo != null) {
        await precacheImage(AssetImage(photo), context);
        await precacheImage(
          ResizeImage(AssetImage(photo), width: 780),
          context,
        );
      }
    }
    for (final home in sampleFindRoomieHomes) {
      for (final photo in home.photoAssets) {
        if (!photo.startsWith('assets/')) {
          continue;
        }
        await precacheImage(AssetImage(photo), context);
        await precacheImage(
          ResizeImage(AssetImage(photo), width: 780),
          context,
        );
        await precacheImage(
          ResizeImage(AssetImage(photo), width: 390),
          context,
        );
      }
    }
  });
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump();
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
  final icons = FontLoader('MaterialIcons');
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/tmp/flutter-sdk/flutter';
  final iconFile = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFile.existsSync()) {
    final bytes = await iconFile.readAsBytes();
    icons.addFont(Future.value(ByteData.sublistView(bytes)));
    await icons.load();
  }
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
