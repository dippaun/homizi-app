import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/listing_detail_screen.dart';

void main() {
  final dir = Platform.environment['HOMIZI_DETAIL_SHOTS'];
  if (dir == null || dir.isEmpty) {
    test('listing detail shots stay out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_DETAIL_SHOTS'), isFalse);
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
    final roboto = FontLoader('Roboto');
    final robotoFile = File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto/Roboto-Regular.ttf',
    );
    if (robotoFile.existsSync()) {
      roboto.addFont(
        Future.value(ByteData.sublistView(await robotoFile.readAsBytes())),
      );
      await roboto.load();
    }
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

  Future<void> open(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadFonts);
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(
          key: const Key('shot-frame'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            home: ListingDetailScreen(listingId: id),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('capture the listing detail', (tester) async {
    await open(tester, 'lst_koramangala');
    await shoot(tester, '01-hero');

    await tester.ensureVisible(find.text('Amenities'));
    await tester.pump();
    await shoot(tester, '02-specs-amenities');

    await tester.ensureVisible(find.byKey(const Key('listing-office-commute')));
    await tester.pump();
    await shoot(tester, '03-commute-nearby');

    await tester.ensureVisible(find.text('Why this matches?'));
    await tester.pump();
    await shoot(tester, '04-host-match');

    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-hero')));
    await tester.pumpAndSettle();
    await shoot(tester, '05-gallery');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('listing-nearby-places')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-nearby-places')));
    await tester.pumpAndSettle();
    await shoot(tester, '06-nearby-page');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('capture a flatmate room', (tester) async {
    await open(tester, 'lst_baner');
    await shoot(tester, '07-flatmate-room');
    await tester.ensureVisible(find.byKey(const Key('listing-specs')));
    await tester.pump();
    await shoot(tester, '08-flatmate-specs');
  }, timeout: const Timeout(Duration(seconds: 40)));
}
