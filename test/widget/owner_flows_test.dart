import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/owner/demo_owner_gateway.dart';
import 'package:homizi/features/owner/for_owners_screen.dart';
import 'package:homizi/features/owner/listing_stats_screen.dart';
import 'package:homizi/features/owner/owner_dashboard_screen.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';
import 'package:homizi/features/trust/trust_badge_section.dart';
import 'package:homizi/features/trust/user_badges.dart';

const _demoConfig = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
);

const _prodConfig = AppConfig(
  environment: AppEnvironment.prod,
  supabaseUrl: 'https://example.supabase.co',
  supabaseAnonKey: 'public-anon',
  policyVersion: '2026-10-11-draft',
);

class _FilledDraft extends ListingDraftController {
  @override
  ListingDraft build() {
    return const ListingDraft(
      title: '1BHK in Indiranagar',
      city: 'Bengaluru',
      locality: 'Indiranagar',
      rentText: '32000',
      depositText: '64000',
    );
  }
}

void main() {
  testWidgets('for owners explains the three steps and zero brokerage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memory = DemoListingMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          ownerGatewayProvider.overrideWith((ref) => DemoOwnerGateway(memory)),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ForOwnersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('List your home free'), findsOneWidget);
    expect(find.text('Match with verified tenants'), findsOneWidget);
    expect(find.text('Meet and finalise'), findsOneWidget);
    expect(find.textContaining('Zero brokerage'), findsOneWidget);
    expect(find.textContaining('NoBroker'), findsNothing);
    expect(find.byKey(const Key('for-owners-start')), findsOneWidget);
  });

  testWidgets('dashboard pauses a live listing and opens stats', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memory = DemoListingMemory(seed: demoOwnerSeed());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          ownerGatewayProvider.overrideWith((ref) => DemoOwnerGateway(memory)),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const OwnerDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2BHK near Sony Signal, Koramangala'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('In review'), findsOneWidget);
    expect(find.text('Paused'), findsWidgets);
    expect(find.text('Rented'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Phone verified'), findsWidgets);

    await tester.tap(find.byKey(const Key('pause-demo-own-koramangala')));
    await tester.pumpAndSettle();
    expect(find.text('Listing paused.'), findsOneWidget);
    expect(memory.byId('demo-own-koramangala')?.status, 'paused');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          ownerGatewayProvider.overrideWith((ref) => DemoOwnerGateway(memory)),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ListingStatsScreen(propertyId: 'demo-own-koramangala'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('listing-stats-chart')), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(find.textContaining('views'), findsWidgets);
    expect(find.textContaining('saves'), findsWidgets);
  });

  testWidgets('the wizard moves from basics to rent and autosaves a draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memory = DemoListingMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          listingDraftProvider.overrideWith(_FilledDraft.new),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(memory: memory),
          ),
          ownerGatewayProvider.overrideWith((ref) => DemoOwnerGateway(memory)),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ListingEditorScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Basics'), findsOneWidget);
    await tester.tap(find.byKey(const Key('listing-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Rent and deposit'), findsOneWidget);

    await tester.tap(find.byKey(const Key('listing-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Amenities and house rules'), findsOneWidget);
    expect(memory.homes.values, isNotEmpty);
    expect(memory.homes.values.single.status, 'draft');
  });

  testWidgets('badges render and the demo ID switch is hidden in production', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrustBadgeRow(
            badges: UserBadges(
              phoneVerified: true,
              emailVerified: true,
              profileComplete: true,
              idVerifiedDemo: true,
              aadhaarVerified: true,
              faceVerified: true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Phone verified'), findsOneWidget);
    expect(find.text('Email verified'), findsOneWidget);
    expect(find.text('Profile complete'), findsOneWidget);
    expect(find.text('Aadhaar verified'), findsOneWidget);
    expect(find.text('Face verified'), findsOneWidget);
    expect(find.text('ID verified (demo)'), findsNothing);

    final memory = DemoListingMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_prodConfig),
          ownerGatewayProvider.overrideWith((ref) => DemoOwnerGateway(memory)),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const Scaffold(body: TrustBadgeSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-id-badge')), findsNothing);
    expect(find.byKey(const Key('open-verification')), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          ownerGatewayProvider.overrideWith((ref) => DemoOwnerGateway(memory)),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const Scaffold(body: TrustBadgeSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-id-badge')), findsNothing);
    expect(find.byKey(const Key('verification-unverified')), findsOneWidget);
    expect(find.text('ID verified (demo)'), findsNothing);
    expect(memory.idVerifiedDemo, isFalse);
  });

  testWidgets('lead inbox prints status words and hides contact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memory = DemoListingMemory(
      seed: [
        demoOwnerSeed().firstWhere((home) => home.id == 'demo-own-koramangala'),
      ],
    );
    final gateway = DemoOwnerGateway(memory);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          ownerGatewayProvider.overrideWith((ref) => gateway),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const OwnerDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('leads-demo-own-koramangala')),
      400,
    );
    await tester.tap(find.byKey(const Key('leads-demo-own-koramangala')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owner-leads-sheet')), findsOneWidget);
    expect(find.text('Meera K.'), findsOneWidget);
    expect(find.text('Arjun P.'), findsOneWidget);
    expect(find.text('Interest'), findsOneWidget);
    expect(find.text('Visit request'), findsOneWidget);
    expect(find.text('New'), findsWidgets);
    expect(find.text('Replied'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('lead-status-demo-lead-meera')),
        matching: find.text('New'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Not replied yet'), findsWidgets);
    expect(find.textContaining('NoBroker'), findsNothing);
    expect(find.textContaining('99acres'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('CG Road'), findsNothing);
    expect(find.textContaining('Law Garden'), findsNothing);

    await tester.tap(
      find.byKey(const Key('lead-mark-demo-lead-meera-replied')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lead marked Replied.'), findsOneWidget);
    expect(find.text('You set this to Replied'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('lead-status-demo-lead-meera')),
        matching: find.text('Replied'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('lead-response-demo-lead-meera')))
          .data,
      contains('Replied in'),
    );
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);
  });

  testWidgets('interested tenants sheet still hides phone and email', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memory = DemoListingMemory(
      seed: [
        demoOwnerSeed().firstWhere((home) => home.id == 'demo-own-koramangala'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          ownerGatewayProvider.overrideWith((ref) => DemoOwnerGateway(memory)),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const OwnerDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('interested-demo-own-koramangala')),
      400,
    );
    await tester.tap(find.byKey(const Key('interested-demo-own-koramangala')));
    await tester.pumpAndSettle();

    expect(find.text('Interested tenants'), findsWidgets);
    expect(find.text('Meera K.'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('CG Road'), findsNothing);
    expect(find.textContaining('NoBroker'), findsNothing);
  });
}
