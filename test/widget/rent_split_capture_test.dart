import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/tools/rent_split/rent_split_repository.dart';
import 'package:homizi/features/tools/split_screen.dart';

/// Writes 390x844 (DPR 2) screenshots of the rent split flow when
/// HOMIZI_CAPTURE_DIR is set. CI skips it.
void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('rent split capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  setUpAll(_loadCaptureFonts);

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
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

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
    }
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
  }

  Future<void> tap(WidgetTester tester, String key, {bool top = true}) async {
    final finder = find.byKey(Key(key));
    await reveal(tester, finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
    if (top) {
      final lists = find.byType(Scrollable);
      if (lists.evaluate().isNotEmpty) {
        await tester.drag(lists.first, const Offset(0, 3000));
        await tester.pumpAndSettle();
      }
    }
  }

  Future<void> scrollTo(WidgetTester tester, String key) async {
    await reveal(tester, find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('rent split flow', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 1688);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rentSplitRepositoryProvider.overrideWithValue(
            RentSplitRepository(
              local: MemoryRentSplitStore(),
              remote: const SkippingRentSplitRemote(),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _captureTheme(),
          builder: (context, child) =>
              RepaintBoundary(key: const Key('shot-frame'), child: child),
          home: const SplitScreen(roommates: ['Amit', 'Rahul']),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
    await shoot(tester, 'rentsplit-1-setup');
    await tap(tester, 'split-start');
    await shoot(tester, 'rentsplit-2-rooms');
    await tap(tester, 'split-room-0', top: false);
    await shoot(tester, 'rentsplit-3-room-sheet');
    await tap(tester, 'split-room-save');
    await tap(tester, 'split-calculate');
    await shoot(tester, 'rentsplit-4-result-smart');
    await scrollTo(tester, 'split-how');
    await shoot(tester, 'rentsplit-5-how-it-works');
    await tap(tester, 'split-mode-equal');
    await shoot(tester, 'rentsplit-6-result-equal');
    await tap(tester, 'split-mode-custom');
    await tester.enterText(find.byKey(const Key('split-custom-0')), '12000');
    await tester.pumpAndSettle();
    await scrollTo(tester, 'split-total');
    await shoot(tester, 'rentsplit-7-custom-error');
    await tap(tester, 'split-mode-smart');
    await tap(tester, 'split-review');
    await tap(tester, 'split-agree-0', top: false);
    await shoot(tester, 'rentsplit-8-review');
    await tap(tester, 'split-agree-1', top: false);
    await tap(tester, 'split-agree-2', top: false);
    await tap(tester, 'split-finalize');
    await shoot(tester, 'rentsplit-9-finalized');
    await tap(tester, 'split-pay', top: false);
    await shoot(tester, 'rentsplit-10-demo-paid');
  });
}

/// Inter has no ₹ glyph; the browser falls back on the web, the test
/// renderer does not, so fall back to Plus Jakarta Sans here.
ThemeData _captureTheme() {
  final base = HomiziTheme.light();
  const fallback = ['PlusJakartaSans'];
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fallback),
  );
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
  final path = root != null && root.isNotEmpty
      ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
      : '${Platform.resolvedExecutable}/../../../artifacts/material_fonts/MaterialIcons-Regular.otf';
  final material = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(ByteData.sublistView(await File(path).readAsBytes())),
    );
  await material.load();
}
