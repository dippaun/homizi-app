import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/matching/match_inputs.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _SignedIn extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'test@homizi.in',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('matching screenshots stay out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  testWidgets('matches page and why this match', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_SignedIn.new)],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          builder: (context, child) => RepaintBoundary(
            key: const Key('shot-frame'),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const MatchesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await _shoot(tester, dir, '01-matches');
    await tester.scrollUntilVisible(
      find.text('Chat'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _shoot(tester, dir, '01b-matches-chat');
    await tester.ensureVisible(
      find.byKey(const Key('match-score-demo-match-lst_koramangala')),
    );

    await tester.tap(
      find.byKey(const Key('match-score-demo-match-lst_koramangala')),
    );
    await tester.pumpAndSettle();
    await _shoot(tester, dir, '02-why-this-match');
  });

  testWidgets('why sheet factors', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 11, 14, 18, 5);
    final report = scoreMatch(
      seeker: const SeekerMatchInput(
        budgetMinInr: 10000,
        budgetMaxInr: 18000,
        officeLatitude: 23.04977,
        officeLongitude: 72.511,
        officeLabel: 'Prahlad Nagar',
        smoking: 'never',
        food: 'veg',
        propertyTypes: ['apartment'],
        occupancy: 'entire',
      ),
      subject: const MatchSubject(
        rentInr: 15000,
        latitude: 23.012,
        longitude: 72.511,
        smoking: 'never',
        food: 'veg',
        propertyType: 'apartment',
        bedrooms: 2,
        pets: 'allowed',
      ),
      computedAt: now.subtract(const Duration(minutes: 5)),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: Scaffold(
          body: RepaintBoundary(
            key: const Key('shot-frame'),
            child: MatchBreakdownSheet(
              match: listingMatchFromReport(report),
              now: now,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _shoot(tester, dir, '03-why-factors');
  });
}

Future<void> _shoot(WidgetTester tester, String dir, String name) async {
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

Future<void> _loadFonts() async {
  final sans = FontLoader('PlusJakartaSans');
  for (final name in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();

  final icons = File(_materialIconsPath());
  if (icons.existsSync()) {
    final material = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
    await material.load();
  }
}

String _materialIconsPath() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    return '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  }
  return '${File(Platform.resolvedExecutable).parent.parent.parent.path}/artifacts/material_fonts/MaterialIcons-Regular.otf';
}
