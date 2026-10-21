import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/roommates/roomie/roomie_entry_screen.dart';
import 'package:homizi/features/roommates/roomie/roomie_flow_screens.dart';
import 'package:homizi/features/roommates/roomie/roomie_preferences_screen.dart';

/// Routes for Find Your Roomie. Registered at `/roomie`.
List<RouteBase> roomieRoutes() {
  return [
    GoRoute(
      path: RoutePaths.roomie,
      builder: (context, state) => const RoomieEntryScreen(),
    ),
    GoRoute(
      path: RoutePaths.roomiePreferences,
      builder: (context, state) => const RoomiePreferencesScreen(),
    ),
    GoRoute(
      path: RoutePaths.roomieSaved,
      builder: (context, state) => const RoomieSavedScreen(),
    ),
    GoRoute(
      path: '/roomie/person/:id',
      builder: (context, state) =>
          RoomieDetailScreen(personId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/roomie/match/:id',
      builder: (context, state) =>
          RoomieMatchScreen(personId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/roomie/chat/:id',
      builder: (context, state) =>
          RoomieChatScreen(personId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/roomie/explore/:id',
      builder: (context, state) =>
          RoomieExploreScreen(personId: state.pathParameters['id'] ?? ''),
    ),
  ];
}
