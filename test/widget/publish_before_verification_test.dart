import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/listing_preview_screen.dart';
import 'package:homizi/features/publish/published_activity.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/requirements/requirement_form_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/session/sign_in_source.dart';

class _ReviewRequirements extends DemoInventoryGateway {
  @override
  Future<RequirementDraft?> loadLatestRequirement() async {
    return const RequirementDraft(
      city: 'Bengaluru',
      locality: 'Koramangala',
      localities: ['Koramangala'],
      budgetMinInr: 15000,
      budgetMaxInr: 25000,
      seekerKind: 'roommate',
      wizardStep: 13,
    );
  }
}

class _SignedOut extends SessionController {
  @override
  SessionState build() => const SessionState(phase: SessionPhase.signedOut);
}

class _ReadyListing extends ListingDraftController {
  @override
  ListingDraft build() {
    return const ListingDraft(
      title: 'Baner room',
      city: 'Pune',
      locality: 'Baner',
      rentText: '18000',
      photos: [
        PhotoSlot(label: 'Living room', isPrimary: true),
        PhotoSlot(label: 'Bedroom', isPrimary: false),
        PhotoSlot(label: 'Kitchen', isPrimary: false),
      ],
    );
  }
}

void main() {
  testWidgets('unverified roommate publish shows a live brief', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        inventoryGatewayProvider.overrideWith((ref) => _ReviewRequirements()),
        signedInProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const RequirementFormScreen(seekerKind: 'roommate'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 14 of 14'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.textContaining('until a server accepts'), findsNothing);
    expect(
      find.textContaining('You can verify your profile later'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('requirement-publish')));
    await tester.tap(find.byKey(const Key('requirement-publish')));
    await tester.pumpAndSettle();

    expect(find.text('Verify to continue'), findsNothing);
    expect(find.text('Your brief is live'), findsOneWidget);
    expect(find.text('Unverified'), findsOneWidget);
    expect(
      find.text('Verify your profile to get more responses'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('publish-verify-now')), findsOneWidget);
    expect(find.byKey(const Key('publish-verify-later')), findsOneWidget);
    expect(find.byType(HomiziBackButton), findsOneWidget);
    expect(find.text(InventoryCopy.serverRequirementPublished), findsNothing);

    final published = container.read(publishedActivityProvider);
    expect(published, hasLength(1));
    expect(published.single.title, 'Roommate brief');
    expect(published.single.unverified, isTrue);
    expect(published.single.onServer, isFalse);
    expect(published.single.place, 'Bengaluru · Koramangala');
  });

  testWidgets('My activity lists an unverified published brief', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(publishedActivityProvider.notifier)
        .remember(
          const PublishedActivityItem(
            id: 'brief-1',
            kind: PublishedKind.brief,
            title: 'Roommate brief',
            place: 'Bengaluru · Koramangala',
            unverified: true,
            onServer: false,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const Scaffold(
            body: Column(
              children: [Text('My activity'), PublishedActivitySection()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My activity'), findsOneWidget);
    expect(find.byKey(const Key('activity-published')), findsOneWidget);
    expect(find.text('Roommate brief'), findsOneWidget);
    expect(find.text('Bengaluru · Koramangala'), findsOneWidget);
    expect(find.text('Unverified'), findsOneWidget);
  });

  testWidgets('signed-out publish opens sign-in', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: RoutePaths.requirement,
      routes: [
        GoRoute(
          path: RoutePaths.requirement,
          builder: (context, state) =>
              const RequirementFormScreen(seekerKind: 'roommate'),
        ),
        GoRoute(
          path: RoutePaths.login,
          builder: (context, state) => const Scaffold(
            body: Text('Sign in', key: Key('publish-sign-in')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryGatewayProvider.overrideWith((ref) => _ReviewRequirements()),
          sessionProvider.overrideWith(_SignedOut.new),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('requirement-publish')));
    await tester.tap(find.byKey(const Key('requirement-publish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publish-sign-in')), findsOneWidget);
    expect(find.text('Your brief is live'), findsNothing);
    expect(find.text('Verify to continue'), findsNothing);
    expect(router.state.uri.path, RoutePaths.login);
  });

  testWidgets('unverified home publish confirms without a verify sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listingDraftProvider.overrideWith(_ReadyListing.new),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
          signedInProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ListingPreviewScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('listing-publish')));
    await tester.tap(find.byKey(const Key('listing-publish')));
    await tester.pumpAndSettle();

    expect(find.text('Verify to continue'), findsNothing);
    expect(find.byKey(const Key('listing-posted')), findsOneWidget);
    expect(find.text('Unverified'), findsOneWidget);
    expect(
      find.text('Verify your profile to get more responses'),
      findsOneWidget,
    );
    expect(find.text(InventoryCopy.serverListingPublished), findsNothing);
    expect(find.textContaining('The server did not publish'), findsOneWidget);
    expect(find.byType(HomiziBackButton), findsOneWidget);
  });
}
