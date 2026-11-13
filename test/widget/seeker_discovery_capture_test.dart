import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/roles/seeker_matches_screen.dart';

void main() {
  testWidgets('seeker screenshots at 390x844 scale 2', (tester) async {
    final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
    if (dir == null || dir.isEmpty) {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = HomiziTheme.light();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) {
            return DefaultTextStyle.merge(
              style: const TextStyle(fontFamilyFallback: ['NotoSans']),
              child: RepaintBoundary(
                key: const Key('seeker-capture'),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const SeekerMatchesScreen(title: 'Interested Seekers'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await _precache(tester);

    Future<void> shoot(String name) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('seeker-capture')),
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

    await tester.tap(find.byKey(const Key('seeker-city')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seeker-city-Ahmedabad')));
    await tester.pumpAndSettle();
    await shoot('seekers-list');

    await tester.tap(find.byKey(const Key('seeker-card-aditi-mehta')));
    await tester.pumpAndSettle();
    await shoot('seeker-preview');
  });
}

Future<void> _precache(WidgetTester tester) async {
  final context = tester.element(find.byType(SeekerMatchesScreen).first);
  const assets = [
    'assets/avatars/avatar_01.webp',
    'assets/avatars/avatar_02.webp',
    'assets/avatars/avatar_03.webp',
    'assets/avatars/avatar_04.webp',
    'assets/avatars/avatar_05.webp',
    'assets/avatars/avatar_06.webp',
    'assets/photos/living_01.webp',
  ];
  await tester.runAsync(() async {
    for (final asset in assets) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  await tester.pump();
}

Future<void> _loadCaptureFonts() async {
  Future<void> loadFamily(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final name in files) {
      final bytes = await File(name).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await loadFamily('PlusJakartaSans', [
    'assets/fonts/PlusJakartaSans-Regular.ttf',
    'assets/fonts/PlusJakartaSans-Medium.ttf',
    'assets/fonts/PlusJakartaSans-SemiBold.ttf',
    'assets/fonts/PlusJakartaSans-Bold.ttf',
    'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
  ]);
  await loadFamily('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);
  final noto = File('/tmp/NotoSans-Regular.ttf');
  if (noto.existsSync()) {
    await loadFamily('NotoSans', [noto.path]);
  }
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
