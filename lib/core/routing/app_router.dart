import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/routing/session_redirect.dart';
import 'package:homizi/features/agreements/agreements_screen.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/bootstrap/splash_screen.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/discovery/explore_screen.dart';
import 'package:homizi/features/discovery/filter_screen.dart';
import 'package:homizi/features/discovery/listing_detail_screen.dart';
import 'package:homizi/features/explore/recently_viewed_screen.dart';
import 'package:homizi/features/explore/saved_searches_screen.dart';
import 'package:homizi/features/home/home_screen.dart';
import 'package:homizi/features/interest/swipe_screen.dart';
import 'package:homizi/features/legal/public_legal_pages.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';
import 'package:homizi/features/listings/listing_preview_screen.dart';
import 'package:homizi/features/listings/photo_manager_screen.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/moderation/moderation_screen.dart';
import 'package:homizi/features/notifications/notifications_screen.dart';
import 'package:homizi/features/onboarding/welcome_screen.dart';
import 'package:homizi/features/owner/for_owners_screen.dart';
import 'package:homizi/features/owner/listing_stats_screen.dart';
import 'package:homizi/features/owner/owner_dashboard_screen.dart';
import 'package:homizi/features/payments/payments_screen.dart';
import 'package:homizi/features/profile/host_profile_screen.dart';
import 'package:homizi/features/profile/profile_hub_screen.dart';
import 'package:homizi/features/profile/tenant_profile_screen.dart';
import 'package:homizi/features/requirements/requirement_form_screen.dart';
import 'package:homizi/features/roles/role_selection_screen.dart';
import 'package:homizi/features/roommates/roommate_screen.dart';
import 'package:homizi/features/safety/report_block_screen.dart';
import 'package:homizi/features/saved/saved_screen.dart';
import 'package:homizi/features/seekers/seekers_screen.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/services/service_request_screen.dart';
import 'package:homizi/features/services/services_hub_screen.dart';
import 'package:homizi/features/services/staff_service_leads_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/settings/settings_screen.dart';
import 'package:homizi/features/shell/home_shell.dart';
import 'package:homizi/features/support/help_screen.dart';
import 'package:homizi/features/tools/agreement_screen.dart';
import 'package:homizi/features/tools/checklist_screen.dart';
import 'package:homizi/features/tools/deposit_screen.dart';
import 'package:homizi/features/tools/receipt_screen.dart';
import 'package:homizi/features/tools/split_screen.dart';
import 'package:homizi/features/tools/tools_screen.dart';
import 'package:homizi/features/verification/kyc_screen.dart';

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
      appBar: AppBar(title: Text(homiziText(context, 'Page not available'))),
      body: Center(
        child: Text(
          homiziText(context, state.error?.toString() ?? 'Unknown route'),
        ),
      ),
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
        path: RoutePaths.recentlyViewed,
        builder: (context, state) => const RecentlyViewedScreen(),
      ),
      GoRoute(
        path: RoutePaths.savedSearches,
        builder: (context, state) => const SavedSearchesScreen(),
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
          otherUserId: state.uri.queryParameters['user'],
          avatarUrl: state.uri.queryParameters['avatar'],
        ),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.help,
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: RoutePaths.tools,
        builder: (context, state) => const ToolsScreen(),
      ),
      GoRoute(
        path: RoutePaths.rentReceipt,
        builder: (context, state) => const ReceiptScreen(),
      ),
      GoRoute(
        path: RoutePaths.rentSplit,
        builder: (context, state) => const SplitScreen(),
      ),
      GoRoute(
        path: RoutePaths.rentAgreement,
        builder: (context, state) => const AgreementScreen(),
      ),
      GoRoute(
        path: RoutePaths.moveInChecklist,
        builder: (context, state) => const ChecklistScreen(),
      ),
      GoRoute(
        path: RoutePaths.depositTracker,
        builder: (context, state) => const DepositScreen(),
      ),
      GoRoute(
        path: RoutePaths.privacy,
        builder: (context, state) => const PrivacyPolicyPage(),
      ),
      GoRoute(
        path: RoutePaths.terms,
        builder: (context, state) => const TermsPage(),
      ),
      GoRoute(
        path: RoutePaths.support,
        builder: (context, state) => const SupportSafetyPage(),
      ),
      GoRoute(
        path: RoutePaths.deleteAccount,
        builder: (context, state) => const DeleteAccountPage(),
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
        builder: (context, state) => ListingEditorScreen(
          propertyId: state.uri.queryParameters['id'],
          fresh: state.uri.queryParameters['fresh'] == '1',
        ),
      ),
      GoRoute(
        path: RoutePaths.forOwners,
        builder: (context, state) => const ForOwnersScreen(),
      ),
      GoRoute(
        path: RoutePaths.ownerDashboard,
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/owner/stats/:id',
        builder: (context, state) =>
            ListingStatsScreen(propertyId: state.pathParameters['id'] ?? ''),
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
        path: RoutePaths.moderation,
        builder: (context, state) => const ModerationScreen(),
      ),
      GoRoute(
        path: RoutePaths.services,
        builder: (context, state) => const ServicesHubScreen(),
      ),
      GoRoute(
        path: RoutePaths.serviceRequest,
        builder: (context, state) => ServiceRequestScreen(
          kind:
              serviceKindFromWire(state.uri.queryParameters['kind']) ??
              ServiceKind.cleaning,
        ),
      ),
      GoRoute(
        path: RoutePaths.payments,
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: RoutePaths.agreements,
        builder: (context, state) => const AgreementsScreen(),
      ),
      GoRoute(
        path: RoutePaths.verifyIdentity,
        builder: (context, state) => const KycScreen(),
      ),
      GoRoute(
        path: RoutePaths.staffServiceLeads,
        builder: (context, state) => const StaffServiceLeadsScreen(),
      ),
      GoRoute(
        path: RoutePaths.report,
        builder: (context, state) => ReportBlockScreen(
          targetType: state.uri.queryParameters['targetType'] ?? 'listing',
          targetId: state.uri.queryParameters['targetId'] ?? '',
          blockedUserId: state.uri.queryParameters['blockedUserId'],
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
                path: RoutePaths.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
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
                path: RoutePaths.roommates,
                builder: (context, state) => const RoommateScreen(),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.seekers,
                builder: (context, state) => const SeekersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.listings,
                builder: (context, state) => const OwnerDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                builder: (context, state) => const ProfileHubScreen(),
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
