import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/host_public_profile_page.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

void main() {
  final dir = Platform.environment['HOMIZI_INSTA_SHOTS'];
  if (dir == null || dir.isEmpty) {
    test('public profile screenshots stay out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_INSTA_SHOTS'), isFalse);
    });
    return;
  }

  Future<void> loadFonts() async {
    final sans = FontLoader('PlusJakartaSans');
    final inter = FontLoader('Inter');
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
    for (final name in const [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
    ]) {
      final bytes = await File('assets/fonts/$name').readAsBytes();
      inter.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await sans.load();
    await inter.load();
    final root = Platform.environment['FLUTTER_ROOT'];
    final icons = File(
      root != null && root.isNotEmpty
          ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
          : '${File(Platform.resolvedExecutable).parent.parent.parent.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    final material = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
    await material.load();
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('shot-frame')),
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

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadFonts);
    final listing = DemoCatalog.byId('lst_koramangala')!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_SignedInTenant.new)],
        child: RepaintBoundary(
          key: const Key('shot-frame'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            home: ListingHostPage(listing: listing),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('capture the public profile', (tester) async {
    await open(tester);
    await shoot(tester, '01-profile');

    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    await shoot(tester, '02-grid');

    scroll.position.jumpTo(0);
    await tester.pump();
    await tester.tap(find.byKey(const Key('host-profile-tab-about')));
    await tester.pump(const Duration(milliseconds: 700));
    await shoot(tester, '03-about');

    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    await shoot(tester, '04-about-reviews');
  }, timeout: const Timeout(Duration(seconds: 60)));
}

class _SignedInTenant extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'meera.nair@homizi.in',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}
