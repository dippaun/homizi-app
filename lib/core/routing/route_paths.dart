/// Screen inventory routes for the MVP shell.
/// S-16, S-17, S-18 and S-21 are intentionally absent (candidates or deferred).
abstract final class RoutePaths {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const role = '/role';
  static const home = '/home';
  static const explore = '/explore';
  static const filters = '/filters';
  static const recentlyViewed = '/recently-viewed';
  static const savedSearches = '/saved-searches';
  static const discover = '/discover';
  static const roommates = '/roommates';
  static const matches = '/matches';
  static const saved = '/saved';
  static const seekers = '/seekers';
  static const listings = '/listings';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const help = '/help';

  /// Home "Tools" switch (slice A) and Settings both open this grid.
  static const tools = '/tools';
  static const profile = '/profile';
  static const rentReceipt = '/tools/receipt';
  static const rentSplit = '/tools/split';
  static const rentAgreement = '/tools/agreement';
  static const moveInChecklist = '/tools/checklist';
  static const depositTracker = '/tools/deposit';
  static const privacy = '/privacy';
  static const terms = '/terms';
  static const support = '/support';
  static const deleteAccount = '/delete-account';

  /// Reachable with no session. Play and the web app use these paths.
  static const publicLegal = <String>{privacy, terms, support, deleteAccount};
  static const tenantProfile = '/profile/tenant';
  static const hostProfile = '/profile/host';
  static const requirement = '/requirements';
  static const hostHome = '/host';
  static const hostOptions = '/host/options';
  static const hostSeekers = '/host/seekers';
  static const hostLeads = '/host/leads';
  static const hostVisits = '/host/visits';
  static const brokerRegister = '/broker/register';
  static const brokerSeekers = '/broker/seekers';
  static const listingEditor = '/listings/edit';
  static const photoManager = '/listings/photos';
  static const listingPreview = '/listings/preview';
  static const forOwners = '/owners';
  static const ownerDashboard = '/owner';

  static String listingStats(String id) => '/owner/stats/$id';
  static const report = '/safety/report';
  static const moderation = '/moderation';
  static const services = '/services';
  static const serviceRequest = '/services/request';
  static const payments = '/payments';
  static const agreements = '/agreements';
  static const verifyIdentity = '/verify';
  static const staffServiceLeads = '/moderation/service-leads';

  static String listing(String id) => '/listing/$id';

  static String reportLocation({
    required String targetType,
    required String targetId,
    String? blockedUserId,
  }) {
    return Uri(
      path: report,
      queryParameters: {
        'targetType': targetType,
        'targetId': targetId,
        if (blockedUserId != null && blockedUserId.isNotEmpty)
          'blockedUserId': blockedUserId,
      },
    ).toString();
  }

  static String chat(
    String matchId, {
    String? name,
    String? title,
    String? otherUserId,
    String? avatar,
  }) {
    final query = <String, String>{
      if (name != null && name.isNotEmpty) 'name': name,
      if (title != null && title.isNotEmpty) 'title': title,
      if (otherUserId != null && otherUserId.isNotEmpty) 'user': otherUserId,
      if (avatar != null && avatar.isNotEmpty) 'avatar': avatar,
    };
    final path = '/matches/$matchId/chat';
    if (query.isEmpty) {
      return path;
    }
    return Uri(path: path, queryParameters: query).toString();
  }
}
