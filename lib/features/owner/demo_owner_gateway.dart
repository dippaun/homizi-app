import 'package:homizi/features/interest/demo_tenants.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_rules.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// In-memory owner tools for demo mode. Nothing is uploaded.
class DemoOwnerGateway implements OwnerGateway {
  DemoOwnerGateway(this._memory) {
    _leads.addAll(demoOwnerLeads());
  }

  final DemoListingMemory _memory;
  final _leads = <OwnerLead>[];

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
    if (enabled) {
      throw const OwnerFailure('Verification cannot be changed here.');
    }
    throw const OwnerFailure('Verification cannot be changed here.');
  }

  @override
  Future<List<InterestedTenant>> interestedTenants(String propertyId) async {
    if (_memory.byId(propertyId) == null) {
      throw const OwnerFailure('You can only manage your own listing.');
    }
    return [
      for (final card in demoTenantCards.take(3))
        InterestedTenant(
          userId: card.userId,
          displayName: card.name,
          occupation: card.occupation,
          about: card.about,
          avatarUrl: card.photoRef,
          ageRange: card.ageRange,
          budgetMinInr: card.budgetMinInr,
          budgetMaxInr: card.budgetMaxInr,
          moveInIso: card.moveInIso,
          lifestyle: card.lifestyle,
        ),
    ];
  }

  @override
  Future<List<OwnerLead>> leads(String propertyId) async {
    if (_memory.byId(propertyId) == null) {
      throw const OwnerFailure('You can only manage your own listing.');
    }
    return [
      for (final lead in _leads)
        if (lead.propertyId == propertyId) lead,
    ];
  }

  @override
  Future<OwnerLead> setLeadStatus(String leadId, String status) async {
    if (!isOwnerLeadStatus(status)) {
      throw OwnerFailure(ownerActionError('invalid'));
    }
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index == -1) {
      throw OwnerFailure(ownerActionError('not_found'));
    }
    final lead = _leads[index];
    if (_memory.byId(lead.propertyId) == null) {
      throw OwnerFailure(ownerActionError('not_owner'));
    }
    if (lead.status == status) {
      return lead;
    }
    final now = DateTime.now();
    final firstRepliedAt =
        lead.firstRepliedAt ?? (status == 'replied' ? now : null);
    final updated = lead.copyWith(
      status: status,
      firstRepliedAt: firstRepliedAt,
      keepFirstRepliedAt: false,
      responseMinutes: _responseMinutes(lead.createdAt, firstRepliedAt),
      keepResponseMinutes: false,
      audit: [
        ...lead.audit,
        OwnerLeadAudit(
          actorId: 'demo-owner',
          fromStatus: lead.status,
          toStatus: status,
          changedAt: now,
        ),
      ],
    );
    _leads[index] = updated;
    return updated;
  }
}

int? _responseMinutes(DateTime createdAt, DateTime? firstRepliedAt) {
  if (firstRepliedAt == null) {
    return null;
  }
  final minutes = firstRepliedAt.difference(createdAt).inMinutes;
  if (minutes < 0) {
    return 0;
  }
  return minutes;
}

/// Sample inbox for the Koramangala demo home. No phone or email.
List<OwnerLead> demoOwnerLeads() {
  final now = DateTime.now();
  return [
    OwnerLead(
      id: 'demo-lead-meera',
      propertyId: 'demo-own-koramangala',
      kind: 'interest',
      status: 'new',
      personUserId: 'demo-tenant-meera',
      displayName: 'Meera K.',
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    OwnerLead(
      id: 'demo-lead-arjun',
      propertyId: 'demo-own-koramangala',
      kind: 'visit',
      status: 'new',
      personUserId: 'demo-tenant-arjun',
      displayName: 'Arjun P.',
      createdAt: now.subtract(const Duration(hours: 1)),
    ),
    OwnerLead(
      id: 'demo-lead-anika',
      propertyId: 'demo-own-whitefield',
      kind: 'interest',
      status: 'new',
      personUserId: 'demo-tenant-anika',
      displayName: 'Anika R.',
      createdAt: now.subtract(const Duration(hours: 5)),
    ),
    OwnerLead(
      id: 'demo-lead-rahul',
      propertyId: 'demo-own-whitefield',
      kind: 'visit',
      status: 'replied',
      personUserId: 'demo-tenant-rahul',
      displayName: 'Rahul V.',
      createdAt: now.subtract(const Duration(hours: 8)),
    ),
    OwnerLead(
      id: 'demo-lead-omar',
      propertyId: 'demo-own-bandra',
      kind: 'visit',
      status: 'new',
      personUserId: 'demo-tenant-omar',
      displayName: 'Omar F.',
      createdAt: now.subtract(const Duration(hours: 6)),
    ),
    OwnerLead(
      id: 'demo-lead-kabir',
      propertyId: 'demo-own-bandra',
      kind: 'interest',
      status: 'new',
      personUserId: 'demo-tenant-kabir',
      displayName: 'Kabir R.',
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    OwnerLead(
      id: 'demo-lead-leela',
      propertyId: 'demo-own-kothrud',
      kind: 'visit',
      status: 'new',
      personUserId: 'demo-tenant-leela',
      displayName: 'Leela M.',
      createdAt: now.subtract(const Duration(hours: 4)),
    ),
    OwnerLead(
      id: 'demo-lead-neha',
      propertyId: 'demo-own-kharadi',
      kind: 'interest',
      status: 'new',
      personUserId: 'demo-tenant-neha',
      displayName: 'Neha S.',
      createdAt: now.subtract(const Duration(hours: 9)),
    ),
    OwnerLead(
      id: 'demo-lead-nisha',
      propertyId: 'demo-own-vastrapur',
      kind: 'visit',
      status: 'new',
      personUserId: 'demo-tenant-nisha',
      displayName: 'Nisha P.',
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    OwnerLead(
      id: 'demo-lead-isha',
      propertyId: 'demo-own-navrangpura',
      kind: 'interest',
      status: 'new',
      personUserId: 'demo-tenant-isha',
      displayName: 'Isha D.',
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    OwnerLead(
      id: 'demo-lead-diya',
      propertyId: 'demo-own-dwarka',
      kind: 'visit',
      status: 'new',
      personUserId: 'demo-tenant-diya',
      displayName: 'Diya K.',
      createdAt: now.subtract(const Duration(hours: 7)),
    ),
    OwnerLead(
      id: 'demo-lead-vivek',
      propertyId: 'demo-own-jubilee',
      kind: 'interest',
      status: 'new',
      personUserId: 'demo-tenant-vivek',
      displayName: 'Vivek N.',
      createdAt: now.subtract(const Duration(hours: 11)),
    ),
  ];
}
