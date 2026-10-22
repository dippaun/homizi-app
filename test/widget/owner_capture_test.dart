import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _HostSession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'meera@example.test',
      role: AccountRole.host,
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _TenantSession extends SessionController {
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
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('owner screen capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  const config = AppConfig(
    environment: AppEnvironment.staging,
    supabaseUrl: '',
    supabaseAnonKey: '',
    policyVersion: '2026-10-11-draft',
  );

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

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> reveal(
    WidgetTester tester,
    Finder target, {
    bool up = false,
  }) async {
    for (var attempt = 0; attempt < 14; attempt++) {
      if (target.hitTestable().evaluate().isNotEmpty) {
        return;
      }
      final lists = find.byType(Scrollable);
      expect(lists, findsWidgets);
      await tester.drag(
        lists.last,
        Offset(0, up ? 420 : -420),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(target.hitTestable(), findsWidgets);
  }

  testWidgets(
    'capture owner landing, dashboard, wizard, and badges',
    (tester) async {
      phone(tester);
      final memory = DemoListingMemory(seed: demoOwnerSeed());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(config),
            sessionProvider.overrideWith(_HostSession.new),
            demoListingMemoryProvider.overrideWithValue(memory),
          ],
          child: const RepaintBoundary(
            key: Key('shot-frame'),
            child: HomiziApp(),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Explore'),
        ),
      );
      await settle(tester);
      await reveal(tester, find.byKey(const Key('for-owners-home')));
      await tester.pump();
      await shoot(tester, 'owner-explore-entry');

      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      await reveal(tester, find.byKey(const Key('for-owners-entry')));
      await tester.pump();
      await shoot(tester, 'owner-settings-entry');

      await tester.tap(find.byKey(const Key('for-owners-entry')));
      await settle(tester);
      expect(find.text('List your home free'), findsWidgets);
      await shoot(tester, 'for-owners');

      await reveal(tester, find.byKey(const Key('for-owners-dashboard')));
      await tester.pump();
      await shoot(tester, 'for-owners-actions');
      await tester.tap(find.byKey(const Key('for-owners-dashboard')));
      await settle(tester);
      expect(find.byKey(const Key('owner-dashboard')), findsOneWidget);
      await shoot(tester, 'owner-dashboard');

      await reveal(tester, find.text('Live'));
      await tester.pump();
      await shoot(tester, 'owner-dashboard-statuses');

      await reveal(tester, find.text('Stats'));
      await tester.pump();
      await tester.tap(find.text('Stats').hitTestable().first);
      await settle(tester);
      expect(find.byKey(const Key('listing-stats-chart')), findsOneWidget);
      await shoot(tester, 'listing-stats-7');

      await tester.tap(find.text('30 days'));
      await tester.pump(const Duration(milliseconds: 300));
      await shoot(tester, 'listing-stats-30');

      await tester.pageBack();
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      await reveal(tester, find.byKey(const Key('for-owners-resume')));
      await tester.tap(find.byKey(const Key('for-owners-resume')));
      await settle(tester);
      expect(find.text('List your property'), findsOneWidget);
      await shoot(tester, 'wizard-intent');

      const steps = [
        'wizard-location',
        'wizard-nearby',
        'wizard-living',
        'wizard-rules',
        'wizard-services',
        'wizard-charges',
        'wizard-photos',
      ];
      for (final name in steps) {
        await tester.tap(find.byKey(const Key('listing-continue')));
        await settle(tester);
        await shoot(tester, name);
      }

      await reveal(tester, find.text('Manage photos'));
      await tester.tap(find.text('Manage photos'));
      await settle(tester);
      await shoot(tester, 'wizard-photo-manager');
      await tester.pageBack();
      await settle(tester);

      await reveal(tester, find.text('Preview listing'));
      await tester.tap(find.text('Preview listing'));
      await settle(tester);
      await shoot(tester, 'wizard-preview');

      await tester.pageBack();
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      await reveal(tester, find.text('Host profile'));
      await tester.tap(find.text('Host profile'));
      await settle(tester);
      await reveal(tester, find.byKey(const Key('open-verification')));
      await tester.pump();
      await shoot(tester, 'host-badges');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'capture listing trust and reply badge',
    (tester) async {
      phone(tester);
      final gateway = DemoDiscoveryGateway();
      await gateway.likeListing(DemoCatalog.byId('lst_koramangala')!);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(config),
            sessionProvider.overrideWith(_TenantSession.new),
            discoveryGatewayProvider.overrideWith((ref) => gateway),
          ],
          child: const RepaintBoundary(
            key: Key('shot-frame'),
            child: HomiziApp(),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Explore'),
        ),
      );
      await settle(tester);
      await reveal(tester, find.text('Phone verified').first);
      await tester.pump();
      await shoot(tester, 'listing-card-badges');

      await reveal(tester, find.text('Sunlit 2BHK in Koramangala'), up: true);
      await tester.tap(find.text('Sunlit 2BHK in Koramangala'));
      await settle(tester);
      await reveal(tester, find.byKey(const Key('owner-reply-badge')));
      await tester.pump();
      await shoot(tester, 'listing-detail-reply');

      await tester.pageBack();
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Matches'),
        ),
      );
      await settle(tester);
      await reveal(tester, find.text('Phone verified').first);
      await tester.pump();
      await shoot(tester, 'matches-badges');

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Explore'),
        ),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      await tester.tap(find.text('Tenant profile'));
      await settle(tester);
      await reveal(tester, find.text('Verification'));
      await tester.pump();
      await shoot(tester, 'tenant-badges');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
