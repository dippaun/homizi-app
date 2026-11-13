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
import 'package:homizi/features/matching/priority_keys.dart';
import 'package:homizi/features/priorities/priority_routes.dart';
import 'package:homizi/features/priorities/priority_store.dart';
import 'package:homizi/features/roles/role_provider.dart';

void main() {
  testWidgets('priority screenshots at 390x844 scale 2', (tester) async {
    final dir = Platform.environment['HOMIZI_PRIORITY_SHOTS'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shoot(String name) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('priority-shot')).evaluate().isNotEmpty
            ? find.byKey(const Key('priority-shot'))
            : find.byKey(const Key('priority-saved-shot')),
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

    Future<void> open({
      HomiziRole? role,
      PriorityPhase? phase,
      String location = RoutePaths.priorities,
    }) async {
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          ...priorityRoutes(),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey('$location-${role?.name}-${phase?.name}'),
          overrides: [
            if (role != null) currentRoleProvider.overrideWithValue(role),
            if (phase != null)
              priorityStateProvider.overrideWith(() => _ShotPhase(phase)),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    await open();
    await shoot('01-tenant-priorities');
    await tester.scrollUntilVisible(find.text('How It Works'), 500);
    await tester.pump(const Duration(milliseconds: 50));
    await shoot('02-tenant-how-it-works');

    await open(role: HomiziRole.host);
    await shoot('03-host-priorities');
    await tester.scrollUntilVisible(find.text('How It Works'), 500);
    await tester.pump(const Duration(milliseconds: 50));
    await shoot('04-host-how-it-works');

    await open(role: HomiziRole.broker);
    await shoot('05-partner-priorities');

    await open(phase: PriorityPhase.loading);
    await shoot('06-loading');

    await open(phase: PriorityPhase.empty);
    await shoot('07-empty');

    await open(phase: PriorityPhase.error);
    await shoot('08-error');

    await open(location: RoutePaths.prioritiesSaved);
    await shoot('09-saved');
  });
}

class _ShotPhase extends PriorityController {
  _ShotPhase(this.phase);

  final PriorityPhase phase;

  @override
  PriorityState build() {
    final empty = phase == PriorityPhase.empty;
    return PriorityState(
      phase: phase,
      tenantOrder: empty ? const <PriorityKey>[] : tenantPriorityOrder,
      hostOrder: empty ? const <PriorityKey>[] : hostPriorityOrder,
      message: phase == PriorityPhase.error
          ? 'The ranking is saved on this device. It could not sync yet.'
          : '',
    );
  }
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

  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    root != null && root.isNotEmpty
        ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
        : '${Platform.resolvedExecutable}/../../../artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  final material = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
  await material.load();
}
