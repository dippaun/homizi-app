import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/sign_in_gate.dart';
import 'package:homizi/features/find_roomie/find_roomie_confirm_screen.dart';
import 'package:homizi/features/find_roomie/find_roomie_connect_screen.dart';
import 'package:homizi/features/find_roomie/find_roomie_explore_screen.dart';
import 'package:homizi/features/find_roomie/find_roomie_match_screen.dart';
import 'package:homizi/features/find_roomie/find_roomie_paths.dart';
import 'package:homizi/features/find_roomie/find_roomie_request_screen.dart';

/// Connect, match, explore together, joint request, and confirmation.
List<RouteBase> findRoomieRoutes() {
  return [
    GoRoute(
      path: FindRoomiePaths.connect,
      builder: (context, state) =>
          guardPrivateRoute(state, const FindRoomieConnectScreen()),
    ),
    GoRoute(
      path: '/find-roomie/match/:id',
      builder: (context, state) => guardPrivateRoute(
        state,
        FindRoomieMatchScreen(personId: state.pathParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/find-roomie/explore/:id',
      builder: (context, state) => guardPrivateRoute(
        state,
        FindRoomieExploreScreen(personId: state.pathParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/find-roomie/request/:id',
      builder: (context, state) => guardPrivateRoute(
        state,
        FindRoomieRequestScreen(
          personId: state.pathParameters['id'] ?? '',
          homeId: state.uri.queryParameters['home'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/find-roomie/confirm/:id',
      builder: (context, state) => guardPrivateRoute(
        state,
        FindRoomieConfirmScreen(
          personId: state.pathParameters['id'] ?? '',
          homeId: state.uri.queryParameters['home'] ?? '',
        ),
      ),
    ),
  ];
}
