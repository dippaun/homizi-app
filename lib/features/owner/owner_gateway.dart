import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/trust/user_badges.dart';

class OwnerFailure implements Exception {
  const OwnerFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owner dashboard, stats, mock badges, and reply time.
/// Status changes go through the server. Clients do not write listing status.
abstract interface class OwnerGateway {
  Future<List<OwnerListing>> myListings();

  Future<ListingStats> stats(String propertyId);

  /// pause, resume, mark_rented, renew, submit_review, delete_draft.
  Future<String> act(String propertyId, String action);

  Future<ListingDraft?> loadOwnedDraft(String id);

  Future<void> recordView(String propertyId);

  Future<int?> replyHours(String hostUserId);

  Future<UserBadges> badgesFor(String userId);

  Future<UserBadges> myBadges();

  /// Staging and demo only. Sets the mock ID badge. No document is sent.
  Future<UserBadges> setDemoIdVerified({required bool enabled});
}
