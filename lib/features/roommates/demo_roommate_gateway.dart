import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/roommates/demo_catalog.dart';
import 'package:homizi/features/roommates/domain/roommate_compatibility.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';

class DemoRoommateGateway implements RoommateGateway {
  @override
  Future<List<RoommateSeeker>> load(RoommateQuery query) async {
    final rows = [
      for (final seeker in demoRoommateSeekers)
        if (roommateMatchesQuery(seeker, query))
          seeker.copyWith(
            score: roommateCompatibilityScore(demoViewerTraits, seeker.traits),
          ),
    ]..sort(compareRoommateSeekers);
    return rows;
  }

  @override
  Future<RoommateScore> breakdown(RoommateSeeker seeker) async {
    return roommateCompatibility(demoViewerTraits, seeker.traits);
  }

  @override
  Future<String> like(RoommateSeeker seeker) async {
    if (seeker.likesYou) {
      return DiscoveryCopy.demoLikeMatched;
    }
    return DiscoveryCopy.demoLike;
  }

  @override
  Future<String> pass(RoommateSeeker seeker) async {
    return DiscoveryCopy.demoPass;
  }
}
