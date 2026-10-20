import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/roommates/demo_catalog.dart';
import 'package:homizi/features/roommates/domain/roommate_compatibility.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';

class DemoRoommateGateway implements RoommateGateway {
  final Set<String> _liked = {};

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
    _liked.add(seeker.id);
    if (seeker.likesYou) {
      return DiscoveryCopy.demoLikeMatched;
    }
    return DiscoveryCopy.demoLike;
  }

  @override
  Future<String> pass(RoommateSeeker seeker) async {
    _liked.remove(seeker.id);
    return DiscoveryCopy.demoPass;
  }

  @override
  Future<List<RoommateSeeker>> mutual() async {
    final rows = await load(const RoommateQuery());
    return [
      for (final seeker in rows)
        if (seeker.likesYou || _liked.contains(seeker.id)) seeker,
    ];
  }

  @override
  Future<RoommateSeeker?> byId(String id) async {
    final rows = await load(const RoommateQuery());
    for (final seeker in rows) {
      if (seeker.id == id) {
        return seeker;
      }
    }
    return null;
  }
}
