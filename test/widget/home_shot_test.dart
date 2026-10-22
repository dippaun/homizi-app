import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya@example.test',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  testWidgets('home screenshots stay opt-in', (tester) async {
    final dir = Platform.environment['HOMIZI_HOME_SHOTS'];
    if (dir == null || dir.isEmpty) {
      expect(Platform.environment.containsKey('HOMIZI_HOME_SHOTS'), isFalse);
      return;
    }
    await _capture(tester, dir);
  });
}

Future<void> _capture(WidgetTester tester, String dir) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(_ReadySession.new)],
      child: const RepaintBoundary(
        key: Key('home-shot-boundary'),
        child: HomiziApp(),
      ),
    ),
  );
  await tester.pump();
  expect(find.byKey(const Key('home-screen')), findsOneWidget);

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('home-shot-boundary')),
  );
  await _write(tester, boundary, File('$dir/home.png'));

  await tester.drag(
    find.byKey(const Key('home-scroll')),
    const Offset(0, -360),
  );
  await tester.pump();
  await _write(tester, boundary, File('$dir/home-scrolled.png'));
}

Future<void> _write(
  WidgetTester tester,
  RenderRepaintBoundary boundary,
  File file,
) async {
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  final data = bytes;
  expect(data, isNotNull);
  if (data == null) {
    return;
  }
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}
