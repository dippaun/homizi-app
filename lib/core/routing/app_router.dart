import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/routing/session_redirect.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/bootstrap/splash_screen.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/discovery/explore_screen.dart';
import 'package:homizi/features/discovery/filter_screen.dart';
import 'package:homizi/features/discovery/listing_detail_screen.dart';
import 'package:homizi/features/interest/swipe_screen.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';
import 'package:homizi/features/listings/listing_preview_screen.dart';
import 'package:homizi/features/listings/photo_manager_screen.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/onboarding/welcome_screen.dart';
import 'package:homizi/features/profile/host_profile_screen.dart';
import 'package:homizi/features/profile/tenant_profile_screen.dart';
import 'package:homizi/features/requirements/requirement_form_screen.dart';
import 'package:homizi/features/roles/role_selection_screen.dart';
import 'package:homizi/features/safety/report_block_screen.dart';
import 'package:homizi/features/saved/saved_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/settings/settings_screen.dart';
import 'package:homizi/features/shell/home_shell.dart';
import 'package:homizi/features/support/help_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh();
  ref.listen(sessionProvider, (previous, next) => refresh.ping());
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      return sessionRedirect(
        phase: session.phase,
        location: state.uri.path,
        hasConsent: session.hasConsent,
      );
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not available')),
      body: Center(child: Text(state.error?.toString() ?? 'Unknown route')),
    ),
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.role,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: RoutePaths.filters,
        builder: (context, state) => const FilterScreen(),
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (context, state) =>
            ListingDetailScreen(listingId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/matches/:matchId/chat',
        builder: (context, state) => ChatScreen(
          matchId: state.pathParameters['matchId'] ?? '',
          otherName: state.uri.queryParameters['name'] ?? 'Match',
          listingTitle: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.help,
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: RoutePaths.tenantProfile,
        builder: (context, state) => const TenantProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.hostProfile,
        builder: (context, state) => const HostProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.requirement,
        builder: (context, state) => const RequirementFormScreen(),
      ),
      GoRoute(
        path: RoutePaths.listingEditor,
        builder: (context, state) => const ListingEditorScreen(),
      ),
      GoRoute(
        path: RoutePaths.photoManager,
        builder: (context, state) => const PhotoManagerScreen(),
      ),
      GoRoute(
        path: RoutePaths.listingPreview,
        builder: (context, state) => const ListingPreviewScreen(),
      ),
      GoRoute(
        path: RoutePaths.report,
        builder: (context, state) => ReportBlockScreen(
          targetType: state.uri.queryParameters['targetType'] ?? 'listing',
          targetId: state.uri.queryParameters['targetId'] ?? '',
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.explore,
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.discover,
                builder: (context, state) => const SwipeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.matches,
                builder: (context, state) => const MatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.saved,
                builder: (context, state) => const SavedScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _SessionRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
