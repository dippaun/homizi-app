import 'package:homizi/features/moderation/domain/moderation_queue.dart';

class ModerationFailure implements Exception {
  const ModerationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class ModerationResult {
  const ModerationResult({required this.message});

  final String message;
}

/// Staff review. The client never writes report status, listing status,
/// or user status except through these calls.
abstract interface class ModerationGateway {
  Future<bool> isStaff();

  Future<List<ModerationReport>> listReports();

  Future<ModerationResult> reviewReport(String reportId, String status);

  Future<ModerationResult> hideListing(String propertyId);

  Future<ModerationResult> suspendUser(String userId);
}
