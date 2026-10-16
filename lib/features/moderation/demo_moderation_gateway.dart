import 'package:homizi/features/moderation/domain/moderation_queue.dart';
import 'package:homizi/features/moderation/moderation_gateway.dart';

/// Demo mode has no staff queue. Reports stay on the device safety gateway.
class DemoModerationGateway implements ModerationGateway {
  @override
  Future<bool> isStaff() async => false;

  @override
  Future<List<ModerationReport>> listReports() async => const [];

  @override
  Future<ModerationResult> reviewReport(String reportId, String status) {
    throw const ModerationFailure('Demo mode does not open the staff queue.');
  }

  @override
  Future<ModerationResult> hideListing(String propertyId) {
    throw const ModerationFailure('Demo mode does not open the staff queue.');
  }

  @override
  Future<ModerationResult> suspendUser(String userId) {
    throw const ModerationFailure('Demo mode does not open the staff queue.');
  }
}
