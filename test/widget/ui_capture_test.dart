import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/locale_controller.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/chat/demo_thread_gateway.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/thread_providers.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';
import 'package:homizi/features/profile/tenant_profile_screen.dart';
import 'package:homizi/features/requirements/requirement_form_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/settings/settings_screen.dart';
import 'package:homizi/l10n/app_localizations.dart';

class _HindiLocale extends LocaleController {
  @override
  Locale build() => const Locale('hi');
}

class _LanguageFrame extends ConsumerWidget {
  const _LanguageFrame();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: HomiziTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    );
  }
}

class _OfflineCache extends DiscoveryController {
  @override
  DiscoveryState build() {
    return const DiscoveryState(
      error: offlineMessage,
      listings: DemoCatalog.listings,
    );
  }
}

class _ShotListing extends ListingDraftController {
  @override
  ListingDraft build() {
    return const ListingDraft(
      title: 'Furnished 2BHK in Koramangala',
      city: 'Bengaluru',
      locality: 'Koramangala',
      rentText: '22000',
      depositText: '44000',
    );
  }
}

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
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('screen capture stays out of CI', () {
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

  Future<void> tapNav(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
  }

  Widget frame(Widget child) {
    return RepaintBoundary(key: const Key('shot-frame'), child: child);
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('capture onboarding', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: frame(const HomiziApp()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    await shoot(tester, 'onboarding');
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('capture discovery, listing, and matches', (tester) async {
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
    await shoot(tester, 'explore');

    await tapNav(tester, 'Discover');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, 'discovery');

    await tapNav(tester, 'Explore');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('listing-card-lst_koramangala')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.textContaining(
        'You matched. Contact stays hidden until they share theirs.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('until you both match'), findsNothing);
    await shoot(tester, 'listing-detail');

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tapNav(tester, 'Matches');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.textContaining(
        'You matched. Contact stays hidden until they share theirs.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('until you both match'), findsNothing);
    await shoot(tester, 'matches');
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('capture search', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          sessionProvider.overrideWith(_ReadySession.new),
        ],
        child: frame(const HomiziApp()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(SearchBar), 'Kothrud');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shoot(tester, 'search');
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('capture offline', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          sessionProvider.overrideWith(_ReadySession.new),
          discoveryProvider.overrideWith(_OfflineCache.new),
        ],
        child: frame(const HomiziApp()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, 'offline');
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('capture language', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localeProvider.overrideWith(_HindiLocale.new)],
        child: frame(const _LanguageFrame()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(find.text('भाषा'), 300);
    await tester.pump();
    expect(find.text('Settings'), findsNothing);
    expect(find.textContaining('सेटिंग्स'), findsWidgets);
    expect(find.textContaining('@'), findsNothing);
    await shoot(tester, 'language');
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('capture chat', (tester) async {
    phone(tester);
    final gateway = DemoThreadGateway();
    gateway.seedMessage(
      matchId: 'match-1',
      body:
          'The 2 BHK is free from the first. Saturday morning works for a visit.',
      mine: false,
    );
    gateway.seedMessage(
      matchId: 'match-1',
      body: 'Saturday morning is good. I will use the visit times below.',
      mine: true,
    );
    gateway.seedVisit(
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
          threadGatewayProvider.overrideWith((ref) => gateway),
        ],
        child: frame(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            home: const ChatScreen(
              matchId: 'match-1',
              otherName: 'Rohan M.',
              listingTitle: 'Sunlit 2BHK in Koramangala',
              otherUserId: 'demo-host-rohan',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await shoot(tester, 'chat');
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('capture profile', (tester) async {
    phone(tester);
    final accounts = DemoAccountGateway();
    await accounts.saveTenantProfile(
      const TenantProfile(
        displayName: 'Ananya Rao',
        occupation: 'Product designer',
        bio:
            'Looking for a furnished 2 BHK in Koramangala or HSR Layout. I work hybrid and keep weeknights quiet.',
      ),
    );
    await accounts.requestMockVerification();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          accountGatewayProvider.overrideWith((ref) => accounts),
        ],
        child: frame(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            home: const TenantProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await shoot(tester, 'profile');
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('capture requirement wizard', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
        ],
        child: frame(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            home: const RequirementFormScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('requirement-locality')),
      'Koramangala',
    );
    await tester.pump();
    await shoot(tester, 'requirement-wizard');
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('capture listing wizard', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          listingDraftProvider.overrideWith(_ShotListing.new),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
        ],
        child: frame(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HomiziTheme.light(),
            home: const ListingEditorScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await shoot(tester, 'listing-wizard');
  }, timeout: const Timeout(Duration(seconds: 40)));
}
