import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';

/// Device-only activity used when no project is connected.
class DemoProfileHubGateway implements ProfileHubGateway {
  ProfileActivity activity = const ProfileActivity(
    savedCount: 2,
    viewedAvailable: true,
    viewedCount: 3,
    requestCount: 1,
    visitCount: 1,
    matchCount: 1,
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
    visits: [ActivityVisit(status: 'requested', onIso: '2026-10-12')],
    matches: [ActivityMatch(name: 'Rohan M.')],
  );

  @override
  Future<ProfileActivity> loadActivity() async => activity;
}
