import 'package:homizi/features/profile/domain/profile_activity.dart';

class ProfileHubFailure implements Exception {
  const ProfileHubFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class ProfileHubGateway {
  Future<ProfileActivity> loadActivity();
}
