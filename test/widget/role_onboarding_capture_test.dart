import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _NeedsRole extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.needsRole,
      contact: 'ananya.iyer@homizi.in',
      policyVersion: '2026-10-11-draft',
    );
  }

  @override
  Future<String?> selectPrimaryRole(String wire) async {
    state = state.copyWith(
      role: accountRoleForPrimaryWire(wire),
      homiziWire: wire,
      phase: SessionPhase.ready,
    );
    return null;
  }
}

/// Phone frames for the screenshots branch. No-op unless HOMIZI_CAPTURE_DIR
/// is set, so a normal `flutter test` stays green.
void main() {
  testWidgets('role onboarding screenshots at 390x844', (tester) async {
    final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [sessionProvider.overrideWith(_NeedsRole.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HomiziApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

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

    Future<void> choose(String wire) async {
      await tester.tap(find.byKey(Key('role-card-$wire')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('role-continue')));
      await tester.tap(find.byKey(const Key('role-continue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    await shoot('01-role-page');

    await choose('tenant');
    await tester.tap(find.byKey(const Key('personalize-city-Bengaluru')));
    await tester.pump();
    await tester.tap(find.text('A whole home'));
    await tester.tap(find.text('Within a month'));
    await tester.pump();
    await shoot('02-tenant-preferences');
    await tester.ensureVisible(find.byKey(const Key('personalize-save')));
    await tester.tap(find.byKey(const Key('personalize-save')));
    await tester.pump();
    await tester.pump();
    await shoot('03-tenant-ready');
    await tester.tap(find.byKey(const Key('role-ready-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await shoot('04-tenant-home');

    container.read(routerProvider).go('/role');
    await tester.pump();
    await tester.pump();
    await choose('host');
    await tester.tap(find.byKey(const Key('owner-city-Pune')));
    await tester.tap(find.text('Apartment'));
    await tester.tap(find.text('Just one'));
    await tester.pump();
    await shoot('05-host-setup');
    await tester.ensureVisible(find.byKey(const Key('owner-setup-continue')));
    await tester.tap(find.byKey(const Key('owner-setup-continue')));
    await tester.pump();
    await tester.pump();
    await shoot('06-host-ready');
    await tester.tap(find.byKey(const Key('role-ready-dashboard')));
    await tester.pump();
    await tester.pump();
    await shoot('07-host-dashboard');

    container.read(routerProvider).go('/role');
    await tester.pump();
    await tester.pump();
    await choose('broker');
    await tester.enterText(
      find.byKey(const Key('partner-agency')),
      'Deshpande Realty',
    );
    await tester.tap(find.byKey(const Key('partner-city-Bengaluru')));
    await tester.pump();
    await shoot('08-partner-setup');
    await tester.ensureVisible(find.byKey(const Key('partner-setup-continue')));
    await tester.tap(find.byKey(const Key('partner-setup-continue')));
    await tester.pump();
    await tester.pump();
    await shoot('09-partner-ready');
    await tester.tap(find.byKey(const Key('role-ready-continue')));
    await tester.pump();
    await tester.pump();
    await shoot('10-partner-dashboard');

    container.read(routerProvider).go('/role');
    await tester.pump();
    await tester.pump();
    await choose('roommate');
    await tester.tap(find.byKey(const Key('sharer-city-Mumbai')));
    await tester.enterText(
      find.byKey(const Key('sharer-locality')),
      'Bandra West',
    );
    await tester.ensureVisible(find.byKey(const Key('sharer-room-private')));
    await tester.tap(find.byKey(const Key('sharer-room-private')));
    await tester.pump();
    await shoot('11-sharer-setup');
    await tester.ensureVisible(find.byKey(const Key('sharer-setup-continue')));
    await tester.tap(find.byKey(const Key('sharer-setup-continue')));
    await tester.pump();
    await tester.pump();
    await shoot('12-sharer-ready');
    await tester.tap(find.byKey(const Key('role-ready-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await shoot('13-sharer-roomie');
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
  final icons = FontLoader('MaterialIcons');
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
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
