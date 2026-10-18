import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/analytics/demo_analytics_gateway.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/chat/demo_thread_gateway.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/thread_providers.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/settings/settings_screen.dart';
import 'package:homizi/l10n/app_localizations.dart';

class _ReadySession extends SessionController {
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
  final dir = Platform.environment['HOMIZI_STORE_SHOTS'];
  if (dir == null || dir.isEmpty) {
    test('play screenshots stay out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_STORE_SHOTS'), isFalse);
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
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('shot-frame')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget frame(Widget child) {
    return RepaintBoundary(key: const Key('shot-frame'), child: child);
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> tapNav(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
  }

  testWidgets('capture play phone screenshots', (tester) async {
    phone(tester);
    final gateway = DemoDiscoveryGateway();
    await gateway.likeListing(DemoCatalog.byId('lst_koramangala')!);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          sessionProvider.overrideWith(_ReadySession.new),
          discoveryGatewayProvider.overrideWith((ref) => gateway),
        ],
        child: frame(const HomiziApp()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tapNav(tester, 'Explore');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, '01-explore');

    await tester.tap(find.byKey(const Key('listing-card-lst_koramangala')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await shoot(tester, '02-listing');

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tapNav(tester, 'Matches');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, '03-matches');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('capture chat', (tester) async {
    phone(tester);
    final threads = DemoThreadGateway();
    threads.seedMessage(
      matchId: 'match-1',
      body: 'Saturday morning works for a visit.',
      mine: false,
    );
    threads.seedMessage(
      matchId: 'match-1',
      body: 'Saturday morning is good.',
      mine: true,
    );
    threads.seedVisit(
      VisitRequest(
        id: 'visit-shot',
        matchId: 'match-1',
        requesterId: 'demo-host',
        slots: [DateTime.utc(2026, 10, 18, 11, 30)],
        status: 'requested',
        mine: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          threadGatewayProvider.overrideWith((ref) => threads),
          analyticsGatewayProvider.overrideWith(
            (ref) => DemoAnalyticsGateway(optedOut: () => false),
          ),
        ],
        child: frame(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: ChatScreen(
              matchId: 'match-1',
              otherName: 'Rohan M.',
              listingTitle: 'Sunlit 2BHK in Koramangala',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await shoot(tester, '04-chat');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('capture settings', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          sessionProvider.overrideWith(_ReadySession.new),
        ],
        child: frame(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('analytics-sharing')),
      400,
    );
    await tester.pump();
    await shoot(tester, '05-settings');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
