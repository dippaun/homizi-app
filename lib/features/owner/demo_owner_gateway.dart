import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_rules.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// In-memory owner tools for demo mode. Nothing is uploaded.
class DemoOwnerGateway implements OwnerGateway {
  DemoOwnerGateway(this._memory);

  final DemoListingMemory _memory;

  @override
  Future<List<OwnerListing>> myListings() async {
    final rows = [for (final home in _memory.homes.values) home]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [for (final home in rows) demoOwnerListing(home)];
  }

  @override
  Future<ListingStats> stats(String propertyId) async {
    final home = _memory.byId(propertyId);
    if (home == null) {
      throw const OwnerFailure('You can only manage your own listing.');
    }
    final days = home.days.isEmpty ? demoViewSeries(1) : home.days;
    return ListingStats(
      propertyId: propertyId,
      days: days,
      saves: home.saves,
      interests: home.interests,
      visitRequests: home.visitRequests,
    );
  }

  @override
  Future<String> act(String propertyId, String action) async {
    final home = _memory.byId(propertyId);
    if (home == null) {
      throw const OwnerFailure('You can only manage your own listing.');
    }
    switch (action) {
      case 'pause':
        if (!canPauseListing(home.status)) {
          throw const OwnerFailure(
            'That action is not available for this listing.',
          );
        }
        home.status = 'paused';
      case 'resume':
        if (!canResumeListing(home.status)) {
          throw const OwnerFailure(
            'That action is not available for this listing.',
          );
        }
        home.status = 'published';
        final until = home.publishedUntil;
        if (until == null || until.isBefore(DateTime.now())) {
          home.publishedUntil = DateTime.now().add(const Duration(days: 30));
        }
      case 'mark_rented':
        if (!canMarkRented(home.status)) {
          throw const OwnerFailure(
            'That action is not available for this listing.',
          );
        }
        home.status = 'rented';
      case 'renew':
        if (!canRenewListing(home.status)) {
          throw const OwnerFailure(
            'That action is not available for this listing.',
          );
        }
        final base = home.publishedUntil ?? DateTime.now();
        final start = base.isBefore(DateTime.now()) ? DateTime.now() : base;
        home.publishedUntil = start.add(const Duration(days: 30));
        if (home.status == 'expired') {
          home.status = 'published';
        }
      case 'submit_review':
        if (home.status == 'in_review') {
          break;
        }
        if (!canSubmitForReview(home.status)) {
          throw const OwnerFailure(
            'That action is not available for this listing.',
          );
        }
        final blockers = home.draft.persistBlockers();
        if (blockers.isNotEmpty || (home.draft.rentInr ?? 0) <= 0) {
          throw const OwnerFailure(
            'Add a title, a city, a locality, and the rent first.',
          );
        }
        home.status = 'in_review';
      case 'delete_draft':
        if (!canDeleteDraft(home.status)) {
          throw const OwnerFailure('Only a draft can be deleted.');
        }
        _memory.homes.remove(propertyId);
      default:
        throw const OwnerFailure(
          'That action is not available for this listing.',
        );
    }
    home.updatedAt = DateTime.now();
    return ownerActionMessage(action);
  }

  @override
  Future<ListingDraft?> loadOwnedDraft(String id) async {
    return _memory.byId(id)?.draft;
  }

  @override
  Future<void> recordView(String propertyId) async {
    final home = _memory.byId(propertyId);
    if (home == null || home.status != 'published') {
      return;
    }
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final next = [...home.days];
    final index = next.indexWhere((item) => item.day == day);
    if (index == -1) {
      next.add(DayCount(day: day, views: 1));
    } else {
      final current = next[index];
      next[index] = DayCount(day: day, views: current.views + 1);
    }
    home.days = next;
  }

  @override
  Future<int?> replyHours(String hostUserId) async {
    for (final home in _memory.homes.values) {
      if (home.replyHours != null) {
        return home.replyHours;
      }
    }
    if (hostUserId.isEmpty) {
      return null;
    }
    return 2;
  }

  @override
  Future<UserBadges> badgesFor(String userId) async {
    if (userId.isEmpty) {
      return const UserBadges();
    }
    return const UserBadges(
      phoneVerified: true,
      emailVerified: true,
      profileComplete: true,
    );
  }

  @override
  Future<UserBadges> myBadges() async => _memory.myBadges;

  @override
  Future<UserBadges> setDemoIdVerified({required bool enabled}) async {
    _memory.idVerifiedDemo = enabled;
    return _memory.myBadges;
  }
}
