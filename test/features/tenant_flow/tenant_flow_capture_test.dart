import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/tenant_flow/tenant_flow_screen.dart';

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('tenant flow capture stays opt-in', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> loadFace(String family, String path) async {
    final bytes = await File(path).readAsBytes();
    await ui.loadFontFromList(bytes, fontFamily: family);
  }

  Future<void> loadCaptureFonts() async {
    const root = 'assets/fonts';
    await loadFace('PlusJakartaSans', '$root/PlusJakartaSans-Regular.ttf');
    await loadFace('PlusJakartaSans', '$root/PlusJakartaSans-Medium.ttf');
    await loadFace('PlusJakartaSans', '$root/PlusJakartaSans-SemiBold.ttf');
    await loadFace('PlusJakartaSans', '$root/PlusJakartaSans-Bold.ttf');
    await loadFace('PlusJakartaSans', '$root/PlusJakartaSans-ExtraBold.ttf');
    await loadFace('Inter', '$root/Inter-Regular.ttf');
    await loadFace('Inter', '$root/Inter-Medium.ttf');
    await loadFace('Inter', '$root/Inter-SemiBold.ttf');
    await loadFace('Inter', '$root/Inter-Bold.ttf');
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final icons = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (icons.existsSync()) {
        await loadFace('MaterialIcons', icons.path);
      }
    }
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
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

  Future<void> goNext(WidgetTester tester) async {
    final button = find.byKey(const Key('tenant-flow-next'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('capture tenant flow screens', (tester) async {
    await tester.runAsync(loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: const RepaintBoundary(
            key: Key('shot-frame'),
            child: TenantFlowScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    await shoot(tester, '01-intro');
    await goNext(tester);
    await shoot(tester, '02-priorities');
    await goNext(tester);
    await shoot(tester, '03-host-preferences');
    await goNext(tester);
    await shoot(tester, '04-how-matching-works');
    await goNext(tester);
    await shoot(tester, '05-match-results');
    await tester.tap(find.byKey(const Key('tenant-tab-roomies')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, '06-match-results-roomies');
    await goNext(tester);
    await shoot(tester, '07-score-explained');
    await goNext(tester);
    await shoot(tester, '08-colour-codes');
    await goNext(tester);
    await shoot(tester, '09-happier');
    await goNext(tester);
    await shoot(tester, '10-journey');
    await goNext(tester);
    await shoot(tester, '11-rank');
    await goNext(tester);
    await shoot(tester, '12-browse');
    await goNext(tester);
    await shoot(tester, '13-swipe');
    await goNext(tester);
    await shoot(tester, '14-detail');
    await tester.tap(find.byType(HomiziBackButton));
    await tester.pump();
    await tester.tap(find.byType(HomiziBackButton));
    await tester.pump();
    final interested = find.byKey(
      const Key('tenant-interested-lst_match_bandra'),
    );
    await tester.ensureVisible(interested);
    await tester.tap(interested);
    await tester.pump();
    await shoot(tester, '15-its-a-match');
    await goNext(tester);
    await shoot(tester, '16-chat');
    await tester.tap(find.byKey(const Key('tenant-share-contact')));
    await tester.pump();
    await shoot(tester, '17-contact');
    await tester.tap(find.byType(HomiziBackButton));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tenant-share-docs')));
    await tester.pump();
    await shoot(tester, '18-documents');
    await tester.tap(find.byType(HomiziBackButton));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('tenant-schedule-visit')));
    await tester.tap(find.byKey(const Key('tenant-schedule-visit')));
    await tester.pump();
    await shoot(tester, '19-book-visit');
    await tester.tap(find.text('Saturday 11:00 AM'));
    await tester.pump();
    await shoot(tester, '20-visit-booked');
  });
}
