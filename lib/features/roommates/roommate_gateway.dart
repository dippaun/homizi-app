import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

class RoommateFailure implements Exception {
  const RoommateFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// People seeking roommates. Likes go through the existing interest gate.
abstract interface class RoommateGateway {
  Future<List<RoommateSeeker>> load(RoommateQuery query);

  Future<RoommateScore> breakdown(RoommateSeeker seeker);

  Future<String> like(RoommateSeeker seeker);

  Future<String> pass(RoommateSeeker seeker);
}
