import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/roles/demo_seekers.dart';
import 'package:homizi/features/roles/seeker_match.dart';
import 'package:homizi/features/roles/seeker_matches_screen.dart';
import 'package:homizi/features/roles/seeker_providers.dart';

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

    Future<void> pumpScreen({
      required Key appKey,
      SeekerMatchGateway? gateway,
      bool settle = true,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seekerMatchGatewayProvider.overrideWithValue(
              gateway ?? _DemoSeekers(),
            ),
          ],
          child: MaterialApp(
            key: appKey,
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
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
      if (settle) {
        await tester.pump();
        await _precache(tester);
      }
    }

    await pumpScreen(appKey: const Key('app-board'));
    await tester.tap(find.byKey(const Key('seeker-city')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seeker-city-Ahmedabad')));
    await tester.pumpAndSettle();
    await shoot('seekers-list');

    await tester.tap(find.byKey(const Key('seeker-tab-best')));
    await tester.pumpAndSettle();
    await shoot('seekers-best');

    await tester.tap(find.byKey(const Key('seeker-tab-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seeker-shortlist-aditi-mehta')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('seeker-tab-shortlist')));
    await tester.pumpAndSettle();
    await shoot('seekers-shortlist');

    await tester.tap(find.byKey(const Key('seeker-filter')));
    await tester.pumpAndSettle();
    await shoot('seekers-filter');
    await tester.tap(find.byKey(const Key('seeker-filter-apply')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seeker-card-aditi-mehta')));
    await tester.pumpAndSettle();
    await shoot('seeker-requirements');

    await tester.tap(find.byKey(const Key('seeker-tab-about')));
    await tester.pumpAndSettle();
    await shoot('seeker-about');

    await tester.ensureVisible(
      find.byKey(const Key('seeker-tab-compatibility')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seeker-tab-compatibility')));
    await tester.pumpAndSettle();
    await shoot('seeker-compatibility');

    await tester.tap(find.byKey(const Key('seeker-maybe-later')));
    await tester.pumpAndSettle();
    await shoot('confirm-maybe-later');
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seeker-message')));
    await tester.pumpAndSettle();
    await shoot('confirm-message');
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seeker-not-fit')));
    await tester.pumpAndSettle();
    await shoot('confirm-not-fit');

    await pumpScreen(
      appKey: const Key('app-empty'),
      gateway: _FixedSeekers(const SeekerMatchPage(seekers: [], basis: '')),
      settle: false,
    );
    await tester.pump();
    await shoot('seekers-empty');

    await pumpScreen(
      appKey: const Key('app-error'),
      gateway: _FailingSeekers(),
      settle: false,
    );
    await tester.pump();
    await shoot('seekers-error');

    await pumpScreen(
      appKey: const Key('app-loading'),
      gateway: _HangingSeekers(),
      settle: false,
    );
    await shoot('seekers-loading');
  });
}

class _DemoSeekers implements SeekerMatchGateway {
  @override
  Future<SeekerMatchPage> load() async => demoSeekerPage();
}

class _FixedSeekers implements SeekerMatchGateway {
  _FixedSeekers(this.page);

  final SeekerMatchPage page;

  @override
  Future<SeekerMatchPage> load() async => page;
}

class _FailingSeekers implements SeekerMatchGateway {
  @override
  Future<SeekerMatchPage> load() async => throw StateError('offline');
}

class _HangingSeekers implements SeekerMatchGateway {
  @override
  Future<SeekerMatchPage> load() => Completer<SeekerMatchPage>().future;
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
