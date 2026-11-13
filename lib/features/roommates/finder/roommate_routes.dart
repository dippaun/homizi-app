import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/roommates/finder/roommate_match_screen.dart';
import 'package:homizi/features/roommates/finder/roommate_preview_screen.dart';

/// Preview, match, and the retired /roomie redirects.
///
/// The finder itself is the shell branch at [RoutePaths.roommate].
List<RouteBase> roommateFinderRoutes() {
  return [
    GoRoute(
      path: RoutePaths.roommates,
      redirect: (context, state) => RoutePaths.roommate,
    ),
    GoRoute(
      path: '/roommate/person/:id',
      builder: (context, state) =>
          RoommatePreviewScreen(personId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/roommate/match/:id',
      builder: (context, state) =>
          RoommateMatchScreen(personId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/roommate/sent/:id',
      builder: (context, state) => RoommateMatchScreen(
        personId: state.pathParameters['id'] ?? '',
        mutual: false,
      ),
    ),
    GoRoute(
      path: RoutePaths.roommateSaved,
      builder: (context, state) => const RoommateRequirementsSavedScreen(),
    ),
    GoRoute(
      path: RoutePaths.roomie,
      redirect: (context, state) => RoutePaths.roommate,
    ),
    GoRoute(
      path: RoutePaths.roomiePreferences,
      redirect: (context, state) => RoutePaths.roommate,
    ),
    GoRoute(
      path: RoutePaths.roomieSaved,
      redirect: (context, state) => RoutePaths.roommate,
    ),
    GoRoute(
      path: RoutePaths.roomieLifestyle,
      redirect: (context, state) => RoutePaths.roommate,
    ),
    GoRoute(
      path: RoutePaths.roomiePriorities,
      redirect: (context, state) => RoutePaths.roommate,
    ),
    GoRoute(
      path: '/roomie/person/:id',
      redirect: (context, state) => RoutePaths.roommate,
    ),
    GoRoute(
      path: '/roomie/match/:id',
      redirect: (context, state) => RoutePaths.roommate,
    ),
    GoRoute(
      path: '/roomie/chat/:id',
      redirect: (context, state) => RoutePaths.roommate,
    ),
    GoRoute(
      path: '/roomie/explore/:id',
      redirect: (context, state) => RoutePaths.roommate,
    ),
  ];
}
