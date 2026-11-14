/// Screen inventory routes for the MVP shell.
/// S-16, S-17, S-18 and S-21 are intentionally absent (candidates or deferred).
abstract final class RoutePaths {
  static const splash = '/splash';
  static const demoDone = '/demo/done';
  static const welcome = '/welcome';
  static const login = '/login';
  static const loginPhone = '/login/phone';
  static const verifyContact = '/account/verify';
  static const personalize = '/personalize';

  /// First onboarding page. Role, then a short setup for that role.
  static const role = '/role';
  static const ownerSetup = '/onboarding/owner';
  static const partnerSetup = '/onboarding/partner';
  static const sharerSetup = '/onboarding/sharer';
  static const roleReady = '/onboarding/ready';

  /// Property partner home: seeker demand, listings, and leads.
  static const partnerHome = '/partner';
  static const home = '/home';
  static const more = '/more';
  static const about = '/about';
  static const explore = '/explore';
  static const filters = '/filters';
  static const office = '/office';
  static const officeSaved = '/office/saved';
  static const searchStart = '/search/start';
  static const searchMatches = '/search/matches';

  /// List Your Property. Page 7, then the eight steps.
  static const listStart = '/list/start';
  static const recentlyViewed = '/recently-viewed';
  static const savedSearches = '/saved-searches';
  static const discover = '/discover';
  static const roommates = '/roommates';

  /// Tenant Roommate tab. [/roommates] and [/roomie] redirect here.
  static const roommate = '/roommate';
  static const roommateSaved = '/roommate/requirements/saved';
  static const flatmateMutual = '/flatmate/mutual';
  static const flatmateRooms = '/flatmate/rooms';

  /// Find Your Roomie. Kept off the home shell so the home rebuild can land
  /// without this flow.
  static const roomie = '/roomie';
  static const roomiePreferences = '/roomie/preferences';
  static const roomieSaved = '/roomie/preferences/saved';
  static const roomieLifestyle = '/roomie/lifestyle';
  static const roomiePriorities = '/roomie/priorities';

  /// Set My Priorities. Tenant and host lists are chosen from the active role.
  static const priorities = '/priorities';
  static const prioritiesSaved = '/priorities/saved';

  /// Intelligent matchmaking. Separate from the mutual-match inbox at [matches].
  static const intelligentMatch = '/match';
  static const matchPriorities = '/match/priorities';
  static const matchPrioritiesSaved = '/match/priorities/saved';
  static const matchFeed = '/match/feed';
  static const matchSwipe = '/match/swipe';
  static const matchCommute = '/match/commute';
  static const matchCommuteSaved = '/match/commute/saved';
  static const matchSignalsReset = '/match/signals/reset';

  static String matchExplained(String id) => '/match/explained/$id';

  static String matchCard(String id) => '/match/card/$id';

  static String matchMutual(String id) => '/match/mutual/$id';

  static String matchChat(String id) => '/match/chat/$id';

  static String matchVisit(String id) => '/match/visit/$id';

  static String matchVisitDone(String id) => '/match/visit/$id/done';

  static String matchContact(String id) => '/match/contact/$id';

  static String matchContactDone(String id) => '/match/contact/$id/done';

  static String matchDocs(String id) => '/match/docs/$id';

  static String matchDocsDone(String id) => '/match/docs/$id/done';

  static String matchCommuteFor(String id) => '/match/commute/$id';

  static String roommatePerson(String id) => '/roommate/person/$id';

  static String roommateMatch(String id) => '/roommate/match/$id';

  static String roommateSent(String id) => '/roommate/sent/$id';

  static String roommateMaybe(String id) => '/roommate/maybe/$id';

  static String roomiePerson(String id) => '/roomie/person/$id';

  static String roomieMatch(String id) => '/roomie/match/$id';

  static String roomieChat(String id) => '/roomie/chat/$id';

  static String roomieExplore(String id) => '/roomie/explore/$id';

  static String flatmatePerson(String id) => '/flatmate/person/$id';
  static const matches = '/matches';
  static const chats = '/chats';
  static const saved = '/saved';
  static const seekers = '/seekers';

  static String seekerPreview(String id) => '/seekers/preview/$id';
  static const listings = '/listings';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const help = '/help';

  /// Home "Tools" switch (slice A) and Settings both open this grid.
  static const tools = '/tools';
  static const profile = '/profile';
  static const profileCreate = '/profile/create';
  static const profileMe = '/profile/me';
  static const profileInquiries = '/profile/inquiries';

  /// Circle role picker opened from Create Your Profile.
  static const profileRole = '/profile/role';
  static const tenantHome = '/tenant';
  static const rentReceipt = '/tools/receipt';
  static const rentSplit = '/tools/split';
  static const rentAgreement = '/tools/agreement';
  static const moveInChecklist = '/tools/checklist';
  static const depositTracker = '/tools/deposit';
  static const smartLiver = '/tools/smart-liver';
  static const smartMove = '/tools/smart-move';
  static const privacy = '/privacy';
  static const terms = '/terms';
  static const support = '/support';
  static const deleteAccount = '/delete-account';

  /// Reachable with no session. Play and the web app use these paths.
  static const publicLegal = <String>{privacy, terms, support, deleteAccount};
  static const tenantProfile = '/profile/tenant';
  static const tenantSetup = '/tenant/setup';
  static const tenantVisits = '/tenant/visits';
  static const tenantSearch = '/tenant/search';
  static const flowTenant = '/flow/tenant';

  /// Host flow entry. Agent C replaces the placeholder on this path.
  static const flowHost = '/flow/host';
  static const flowBroker = '/flow/broker';
  static const flowListing = '/flow/listing';
  static const hostProfile = '/profile/host';
  static const hostOnboard = '/host/onboard';
  static const requirement = '/requirements';
  static const hostHome = '/host';
  static const hostOptions = '/host/options';
  static const hostSeekers = '/host/seekers';

  /// "Top match profiles" for the host's saved preferred tenant profile.
  static const hostTopMatches = '/host/top-matches';

  /// Set My Priorities as a host (preferred tenant profile).
  static const hostPriorities = '/priorities?side=host';
  static const hostLeads = '/host/leads';
  static const hostVisits = '/host/visits';
  static const brokerRegister = '/broker/register';
  static const brokerSeekers = '/broker/seekers';
  static const brokerHome = '/broker';
  static const brokerBriefs = '/broker/briefs';
  static const brokerListings = '/broker/listings';
  static const brokerLeads = '/broker/leads';
  static const brokerChats = '/broker/chats';
  static const brokerVisits = '/broker/visits';

  static String brokerBrief(String id) => '/broker/briefs/$id';

  static String brokerListing(String id) => '/broker/listings/$id';

  static String brokerLead(String id) => '/broker/leads/$id';

  static String brokerVisit(String id) => '/broker/visits/$id';

  static const listingEditor = '/listings/edit';
  static const photoManager = '/listings/photos';
  static const listingPreview = '/listings/preview';
  static const forOwners = '/owners';
  static const ownerDashboard = '/owner';
  static const ownerOverview = '/owner/overview';

  static String listingStats(String id) => '/owner/stats/$id';
  static const report = '/safety/report';
  static const moderation = '/moderation';
  static const services = '/services';
  static const serviceRequest = '/services/request';
  static const serviceInfo = '/services/info';
  static const myServices = '/services/mine';
  static const plans = '/plans';
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

  /// Public demo inbox thread. Same screen as [chat], reachable without a session.
  static String inboxChat(
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
    final path = '$chats/$matchId';
    if (query.isEmpty) {
      return path;
    }
    return Uri(path: path, queryParameters: query).toString();
  }
}
