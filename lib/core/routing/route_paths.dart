/// Screen inventory routes for the MVP shell.
/// S-16, S-17, S-18 and S-21 are intentionally absent (candidates or deferred).
abstract final class RoutePaths {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const role = '/role';
  static const explore = '/explore';
  static const filters = '/filters';
  static const discover = '/discover';
  static const matches = '/matches';
  static const saved = '/saved';
  static const settings = '/settings';
  static const help = '/help';
  static const tenantProfile = '/profile/tenant';
  static const hostProfile = '/profile/host';
  static const requirement = '/requirements';
  static const listingEditor = '/listings/edit';
  static const photoManager = '/listings/photos';
  static const listingPreview = '/listings/preview';
  static const report = '/safety/report';

  static String listing(String id) => '/listing/$id';

  static String chat(String matchId, {String? name, String? title}) {
    final query = <String, String>{
      if (name != null && name.isNotEmpty) 'name': name,
      if (title != null && title.isNotEmpty) 'title': title,
    };
    final path = '/matches/$matchId/chat';
    if (query.isEmpty) {
      return path;
    }
    return Uri(path: path, queryParameters: query).toString();
  }
}
