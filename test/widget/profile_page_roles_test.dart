import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpRole(WidgetTester tester, ProfilePageRole role) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: ProfileHubScreen(previewRole: role, showSpecNav: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tenant sample shows Priya, priorities, and the spec nav', (
    tester,
  ) async {
    await pumpRole(tester, ProfilePageRole.tenant);
    expect(find.text('Priya Nair'), findsOneWidget);
    expect(find.text('My top priorities'), findsOneWidget);
    expect(find.text('Latest matches'), findsOneWidget);
    expect(find.text('92% Match'), findsOneWidget);
    expect(find.text('Preview as hosts see it'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Matches'), findsWidgets);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Profile'), findsWidgets);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-aadhaar-status'))).data,
      'Verified',
    );
  });

  testWidgets('owner sample shows listings and the owner note', (tester) async {
    await pumpRole(tester, ProfilePageRole.owner);
    expect(find.text('Rohan Sharma'), findsOneWidget);
    expect(find.text('My listings'), findsOneWidget);
    expect(find.text('Tenant preferences'), findsOneWidget);
    expect(find.text('Property authorisation'), findsOneWidget);
    expect(find.textContaining('not automatically the owner'), findsOneWidget);
    expect(find.text('Add a listing'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
  });

  testWidgets('broker sample shows areas, brokerage, and mandates', (
    tester,
  ) async {
    await pumpRole(tester, ProfilePageRole.broker);
    expect(find.text('Neha Kulkarni'), findsOneWidget);
    expect(find.text('Areas I cover'), findsOneWidget);
    expect(find.text('Brokerage & business'), findsOneWidget);
    expect(find.text('Featured listings'), findsOneWidget);
    expect(find.text('Broker authorisation'), findsOneWidget);
    expect(find.text('Kulkarni Realty'), findsOneWidget);
    expect(find.text('All 14'), findsOneWidget);
  });

  testWidgets('roomie sample shows the room, flatmate, and permission', (
    tester,
  ) async {
    await pumpRole(tester, ProfilePageRole.roomie);
    expect(find.text('Kunal Verma'), findsOneWidget);
    expect(find.text('Room on offer'), findsOneWidget);
    expect(find.text('Who lives here'), findsOneWidget);
    expect(find.text("Flatmate I'm looking for"), findsOneWidget);
    expect(find.text('Owner permission'), findsOneWidget);
    expect(find.text('Share my room'), findsOneWidget);
    expect(find.text('Open spot'), findsOneWidget);
  });

  testWidgets('add a listing and edit profile open real routes', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '${RoutePaths.profilePreview}?role=owner',
      routes: [
        GoRoute(
          path: RoutePaths.profilePreview,
          builder: (context, state) => ProfileHubScreen(
            previewRole: profilePageRoleFromQuery(
              state.uri.queryParameters['role'],
            ),
            showSpecNav: true,
          ),
        ),
        GoRoute(
          path: RoutePaths.listingEditor,
          builder: (context, state) =>
              const Scaffold(body: Text('Listing wizard')),
        ),
        GoRoute(
          path: RoutePaths.hostProfile,
          builder: (context, state) =>
              const Scaffold(body: Text('Host editor')),
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addListing = find.text('Add a listing');
    await tester.ensureVisible(addListing);
    await tester.pumpAndSettle();
    await tester.tap(addListing);
    await tester.pumpAndSettle();
    expect(find.text('Listing wizard'), findsOneWidget);

    router.go('${RoutePaths.profilePreview}?role=owner');
    await tester.pumpAndSettle();
    final editProfile = find.text('Edit profile');
    await tester.ensureVisible(editProfile);
    await tester.pumpAndSettle();
    await tester.tap(editProfile);
    await tester.pumpAndSettle();
    expect(find.text('Host editor'), findsOneWidget);
  });
}
