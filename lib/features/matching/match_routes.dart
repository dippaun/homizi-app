import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/matching/match_detail.dart';
import 'package:homizi/features/matching/match_flow.dart';

List<RouteBase> intelligentMatchRoutes() {
  return [
    GoRoute(
      path: RoutePaths.intelligentMatch,
      builder: (context, state) => const MatchHubScreen(),
    ),
    GoRoute(
      path: RoutePaths.matchPriorities,
      builder: (context, state) => const MatchPrioritiesScreen(),
    ),
    GoRoute(
      path: RoutePaths.matchPrioritiesSaved,
      builder: (context, state) => const MatchConfirmScreen(
        title: 'Priorities saved',
        detail:
            'Your ranks and must-have marks are saved on this device. Best matches use them right away.',
        nextLabel: 'Browse Best Matches',
        nextPath: RoutePaths.matchFeed,
      ),
    ),
    GoRoute(
      path: RoutePaths.matchFeed,
      builder: (context, state) => const MatchFeedScreen(),
    ),
    GoRoute(
      path: RoutePaths.matchSwipe,
      builder: (context, state) => const MatchSwipeScreen(),
    ),
    GoRoute(
      path: RoutePaths.matchCommuteSaved,
      builder: (context, state) => const MatchConfirmScreen(
        title: 'Commute is now priority 1',
        detail:
            'Commute to Office is at the top of your tenant priorities. You can drag it again any time.',
        nextLabel: 'See matches',
        nextPath: RoutePaths.matchFeed,
      ),
    ),
    GoRoute(
      path: RoutePaths.matchCommute,
      builder: (context, state) => const MatchCommuteScreen(),
    ),
    GoRoute(
      path: '/match/commute/:id',
      builder: (context, state) =>
          MatchCommuteScreen(homeId: state.pathParameters['id']),
    ),
    GoRoute(
      path: RoutePaths.matchSignalsReset,
      builder: (context, state) => const ResetSignalsScreen(),
    ),
    GoRoute(
      path: '/match/explained/:id',
      builder: (context, state) =>
          MatchExplainedScreen(id: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/match/card/:id',
      builder: (context, state) =>
          MatchCardScreen(id: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/match/mutual/:id',
      builder: (context, state) =>
          ItsAMatchScreen(id: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/match/chat/:id',
      builder: (context, state) =>
          MatchChatScreen(id: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/match/visit/:id/done',
      builder: (context, state) => MatchConfirmScreen(
        title: 'Visit booked',
        detail:
            'The visit time is saved for this match. It is a time slot, not a street address.',
        nextLabel: 'Back to chat',
        nextPath: RoutePaths.matchChat(state.pathParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/match/visit/:id',
      builder: (context, state) =>
          MatchVisitScreen(id: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/match/contact/:id/done',
      builder: (context, state) => const MatchConfirmScreen(
        title: 'Contact shared',
        detail:
            'You agreed to share contact for this match. The phone number stays off this screen.',
        nextLabel: 'Back to the match',
        nextPath: RoutePaths.matchFeed,
      ),
    ),
    GoRoute(
      path: '/match/contact/:id',
      builder: (context, state) =>
          MatchContactScreen(id: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/match/docs/:id/done',
      builder: (context, state) => MatchConfirmScreen(
        title: 'Documents shared',
        detail:
            'The documents flag is on for this match. No file was uploaded.',
        nextLabel: 'Back to chat',
        nextPath: RoutePaths.matchChat(state.pathParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/match/docs/:id',
      builder: (context, state) =>
          MatchDocsScreen(id: state.pathParameters['id'] ?? ''),
    ),
  ];
}
