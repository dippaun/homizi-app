import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/find_roomie/find_roomie_models.dart';

/// Find Your Roomie. Connect, match, explore, request, then confirm.
abstract final class FindRoomiePaths {
  static const connect = '/find-roomie';

  static String match(String personId) => '/find-roomie/match/$personId';

  static String explore(String personId) => '/find-roomie/explore/$personId';

  static String request(String personId, String homeId) {
    return Uri(
      path: '/find-roomie/request/$personId',
      queryParameters: {'home': homeId},
    ).toString();
  }

  static String confirm(String personId, String homeId) {
    return Uri(
      path: '/find-roomie/confirm/$personId',
      queryParameters: {'home': homeId},
    ).toString();
  }

  /// Existing rent split. First names only, never a phone number.
  static String splitWith(String viewerName, String roomieName) {
    return Uri(
      path: RoutePaths.rentSplit,
      queryParameters: {
        'with':
            '${findRoomieFirstName(viewerName)},${findRoomieFirstName(roomieName)}',
      },
    ).toString();
  }
}
