import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/post_analyzer/property_swipe_page.dart';
import 'package:homizi/shared/widgets/homizi_property_card.dart';

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('property swipe capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
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

  Future<void> frame(WidgetTester tester, Widget app) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 1688);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app);
    await tester.pump();
  }

  Widget framed(Widget home) {
    return ProviderScope(
      child: RepaintBoundary(
        key: const Key('shot-frame'),
        child: MaterialApp(theme: HomiziTheme.light(), home: home),
      ),
    );
  }

  testWidgets('capture the property swipe screens', (tester) async {
    await frame(tester, framed(const PropertySwipePage()));
    await shoot(tester, 'match-swipe');

    await tester.drag(
      find.descendant(
        of: find.byKey(const Key('swipe-card')),
        matching: find.byType(ListView),
      ),
      const Offset(0, -280),
    );
    await tester.pump();
    await shoot(tester, 'match-swipe-reasons');

    await tester.drag(
      find.descendant(
        of: find.byKey(const Key('swipe-card')),
        matching: find.byType(ListView),
      ),
      const Offset(0, 280),
    );
    await tester.pump();
    await tester.tap(find.text('Private Room in 2BHK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shoot(tester, 'match-preview');
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.drag(
      find.descendant(
        of: find.byKey(const Key('swipe-card')),
        matching: find.byType(ListView),
      ),
      const Offset(0, -900),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('match-interested')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shoot(tester, 'match-interest-sent');
  });

  testWidgets('capture the empty deck and the compact card', (tester) async {
    await frame(
      tester,
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              supabaseUrl: 'https://example.test',
              supabaseAnonKey: 'public-anon',
              policyVersion: 'test',
            ),
          ),
          discoveryProvider.overrideWith(_EmptyDiscovery.new),
        ],
        child: RepaintBoundary(
          key: const Key('shot-frame'),
          child: MaterialApp(
            theme: HomiziTheme.light(),
            home: const PropertySwipePage(),
          ),
        ),
      ),
    );
    await shoot(tester, 'match-swipe-empty');

    const data = HomiziPropertyCardData(
      id: 'compact-shot',
      title: 'Private Room in 2BHK',
      place: 'Bandra West, Mumbai',
      rentLabel: '₹25,000 / month',
      matchPercent: 88,
      verifiedListing: true,
      photos: [
        HomiziPropertyPhoto(
          ref: 'assets/images/real/bedroom.webp',
          caption: 'Room (Main Photo)',
        ),
      ],
      details: [
        HomiziPropertyDetail(
          icon: HomiziDetailIcon.room,
          label: 'Private Room',
        ),
        HomiziPropertyDetail(icon: HomiziDetailIcon.bhk, label: '2BHK'),
      ],
      amenities: ['Furnished', 'AC', 'WiFi'],
      topReasons: [],
      hostName: 'Rohan S.',
      nearby: [],
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('shot-frame'),
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: HomiziPropertyCard(
                data: data,
                variant: HomiziPropertyCardVariant.compact,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await shoot(tester, 'property-card-compact');
  });
}

class _EmptyDiscovery extends DiscoveryController {
  @override
  DiscoveryState build() => const DiscoveryState();
}
