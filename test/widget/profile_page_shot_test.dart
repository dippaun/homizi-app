import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/profile/profile_hub_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

String _flutterFile(String relative) {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    return '$root/$relative';
  }
  return '${Platform.environment['HOME']}/flutter-sdk/flutter/$relative';
}

Future<void> _loadFileFamily(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family);
  loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> _loadFamily(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    final data = await rootBundle.load(asset);
    loader.addFont(Future<ByteData>.value(data));
  }
  await loader.load();
}

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('profile page capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFamily('PlusJakartaSans', const [
      'assets/fonts/PlusJakartaSans-Regular.ttf',
      'assets/fonts/PlusJakartaSans-Medium.ttf',
      'assets/fonts/PlusJakartaSans-SemiBold.ttf',
      'assets/fonts/PlusJakartaSans-Bold.ttf',
      'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
    ]);
    await _loadFamily('Inter', const [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ]);
    await _loadFileFamily(
      'MaterialIcons',
      _flutterFile(
        'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
    await _loadFileFamily(
      'Noto Sans',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    );
  });

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required bool full,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final position = scrollable.position;
    final listHeight = position.maxScrollExtent + position.viewportDimension;
    final height = full ? listHeight + 80 : 844.0;
    tester.view.physicalSize = Size(390, height);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('profile-shot')),
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

  for (final role in ProfilePageRole.values) {
    testWidgets('${role.name} profile shots', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWith(_ReadySession.new)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light().copyWith(
              textTheme: HomiziTheme.light().textTheme.apply(
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            builder: (context, child) {
              return DefaultTextStyle.merge(
                style: const TextStyle(fontFamilyFallback: ['DejaVuSans']),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: ProfileHubScreen(previewRole: role, showSpecNav: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await shoot(tester, 'profile-${role.name}-top', full: false);
      await shoot(tester, 'profile-${role.name}-full', full: true);
    });
  }
}
