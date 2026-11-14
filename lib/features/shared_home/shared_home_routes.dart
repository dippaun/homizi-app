import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/sign_in_gate.dart';
import 'package:homizi/features/shared_home/host_shared_home_screen.dart';
import 'package:homizi/features/shared_home/join_request_screen.dart';
import 'package:homizi/features/shared_home/join_status_screen.dart';
import 'package:homizi/features/shared_home/occupancy_search_screen.dart';
import 'package:homizi/features/shared_home/shared_home_detail_screen.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';

/// Smart occupancy matching and shared home routes. The results list is the
/// existing shared rooms route (`/flatmate/rooms`).
List<RouteBase> sharedHomeRoutes() {
  return [
    GoRoute(
      path: SharedHomePaths.search,
      builder: (context, state) => OccupancySearchScreen(
        group: state.uri.queryParameters['mode'] == 'group',
      ),
    ),
    GoRoute(
      path: SharedHomePaths.roomie,
      builder: (context, state) =>
          const OccupancySearchScreen(entry: OccupancyEntry.roomie),
    ),
    GoRoute(
      path: SharedHomePaths.host,
      builder: (context, state) => const HostSharedHomeScreen(),
    ),
    GoRoute(
      path: SharedHomePaths.hostRequests,
      builder: (context, state) =>
          guardPrivateRoute(state, const HostJoinRequestsScreen()),
    ),
    GoRoute(
      path: '/shared-homes/home/:id',
      builder: (context, state) =>
          SharedHomeDetailScreen(homeId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/shared-homes/home/:id/join',
      builder: (context, state) =>
          JoinRequestScreen(homeId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/shared-homes/request/:id',
      builder: (context, state) =>
          JoinStatusScreen(requestId: state.pathParameters['id'] ?? ''),
    ),
  ];
}
