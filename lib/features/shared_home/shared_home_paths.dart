import 'package:homizi/core/routing/route_paths.dart';

/// Routes for smart occupancy matching and shared homes.
abstract final class SharedHomePaths {
  /// "Search a home" (occupancy entry). Add `?mode=group` for groups.
  static const search = '/shared-homes';

  /// "Find your roomie: share an existing home".
  static const roomie = '/shared-homes/roomie';

  /// Results reuse the existing shared rooms route.
  static String results({String entry = 'roomie'}) =>
      '${RoutePaths.flatmateRooms}?entry=$entry';

  static String home(String id) => '/shared-homes/home/$id';

  static String join(String id) => '/shared-homes/home/$id/join';

  static String request(String id) => '/shared-homes/request/$id';

  static const host = '/shared-homes/host';

  static const hostRequests = '/shared-homes/host/requests';
}
