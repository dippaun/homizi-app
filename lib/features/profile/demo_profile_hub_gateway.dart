import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';

/// Device-only activity used when no project is connected.
class DemoProfileHubGateway implements ProfileHubGateway {
  ProfileActivity activity = const ProfileActivity(
    savedCount: 2,
    viewedAvailable: true,
    viewedCount: 3,
    requestCount: 1,
    visitCount: 12,
    matchCount: 4,
    saved: [
      ActivityPlace(
        title: 'Sunlit 2BHK in Koramangala',
        locality: 'Koramangala',
        city: 'Bengaluru',
      ),
      ActivityPlace(
        title: '2 BHK near HSR Layout BDA',
        locality: 'HSR Layout',
        city: 'Bengaluru',
      ),
    ],
    viewed: [
      ActivityPlace(
        title: 'Studio near Indiranagar metro',
        locality: 'Indiranagar',
        city: 'Bengaluru',
      ),
      ActivityPlace(
        title: 'Room in a Bandra West flat',
        locality: 'Bandra West',
        city: 'Mumbai',
      ),
    ],
    requests: [
      ActivityRequest(
        city: 'Bengaluru',
        budgetMinInr: 18000,
        budgetMaxInr: 28000,
      ),
    ],
    visits: [
      ActivityVisit(
        status: 'requested',
        onIso: '2026-10-12',
        visitId: 'demo-visit-1',
        matchId: 'demo-match-lst_koramangala',
        listingId: 'lst_koramangala',
        listingTitle: 'Sunlit 2BHK in Koramangala',
      ),
      ActivityVisit(
        status: 'agreed',
        onIso: '2026-11-04',
        visitId: 'demo-visit-2',
        matchId: 'demo-match-lst_hsr',
        listingId: 'lst_hsr',
        listingTitle: '2 BHK near HSR Layout BDA',
      ),
      ActivityVisit(
        status: 'requested',
        onIso: '2026-11-06',
        visitId: 'demo-visit-3',
        listingId: 'lst_indiranagar',
        listingTitle: 'Studio near Indiranagar metro',
      ),
      ActivityVisit(
        status: 'agreed',
        onIso: '2026-11-08',
        listingId: 'lst_baner',
        listingTitle: 'Private room in Baner',
      ),
      ActivityVisit(
        status: 'requested',
        onIso: '2026-11-09',
        listingId: 'lst_kharadi',
        listingTitle: 'Furnished 3 BHK in Kharadi',
      ),
      ActivityVisit(
        status: 'requested',
        onIso: '2026-11-11',
        listingId: 'lst_kothrud',
        listingTitle: 'Shared room in Kothrud',
      ),
      ActivityVisit(
        status: 'agreed',
        onIso: '2026-11-13',
        listingId: 'lst_koramangala',
        listingTitle: 'Sunlit 2BHK in Koramangala',
      ),
      ActivityVisit(
        status: 'requested',
        onIso: '2026-11-15',
        listingId: 'lst_hsr',
        listingTitle: '2 BHK near HSR Layout BDA',
      ),
      ActivityVisit(
        status: 'requested',
        onIso: '2026-11-16',
        listingId: 'lst_indiranagar',
        listingTitle: 'Studio near Indiranagar metro',
      ),
      ActivityVisit(
        status: 'agreed',
        onIso: '2026-11-18',
        listingId: 'lst_baner',
        listingTitle: 'Private room in Baner',
      ),
      ActivityVisit(
        status: 'requested',
        onIso: '2026-11-20',
        listingId: 'lst_kharadi',
        listingTitle: 'Furnished 3 BHK in Kharadi',
      ),
      ActivityVisit(
        status: 'requested',
        onIso: '2026-11-22',
        listingId: 'lst_kothrud',
        listingTitle: 'Shared room in Kothrud',
      ),
    ],
    matches: [
      ActivityMatch(name: 'Rohan M.'),
      ActivityMatch(name: 'Ananya Iyer'),
      ActivityMatch(name: 'Meera Krishnan'),
      ActivityMatch(name: 'Kabir Singh'),
    ],
  );

  @override
  Future<ProfileActivity> loadActivity() async => activity;
}
