import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_rules.dart';
import 'package:homizi/features/trust/user_badges.dart';

void main() {
  test('chips, actions, and reply labels stay owner-only words', () {
    expect(ownerChipLabel('published'), 'Draft');
    expect(ownerChipLabel('live'), 'Live');
    expect(ownerChipLabel('in_review'), 'In review');
    expect(canPauseListing('published'), isTrue);
    expect(canPauseListing('draft'), isFalse);
    expect(canResumeListing('paused'), isTrue);
    expect(canResumeListing('expired'), isTrue);
    expect(canMarkRented('published'), isTrue);
    expect(canMarkRented('draft'), isFalse);
    expect(canDeleteDraft('draft'), isTrue);
    expect(canDeleteDraft('in_review'), isFalse);
    expect(canRenewListing('expired'), isTrue);
    expect(replyWithinLabel(0), 'Usually replies within 1 h');
    expect(replyWithinLabel(6), 'Usually replies within 6 h');
    expect(ownerActionMessage('renew'), contains('30 days'));
    expect(ownerActionError('not_owner'), contains('own listing'));
  });

  test('stats payload keeps a 30 day series and ignores contact keys', () {
    final stats = listingStatsFromJson({
      'property_id': 'p1',
      'days': [
        {'day': '2026-10-01', 'views': 2},
        {'day': '2026-10-02', 'views': 0},
      ],
      'saves': 4,
      'interests': 1,
      'visit_requests': 3,
      'phone': '+910000000000',
      'email': 'hidden@example.test',
    });
    expect(stats.days, hasLength(2));
    expect(stats.viewsFor(7), 2);
    expect(stats.saves, 4);
    expect(stats.visitRequests, 3);
    expect(trailingDays(stats.days, 1).single.views, 0);
  });

  test('badge rows are booleans and the demo switch is not production', () {
    final badges = UserBadges.fromRow({
      'phone_verified': true,
      'email_verified': 'false',
      'profile_complete': false,
      'id_verified_demo': true,
      'phone': '+910000000000',
    });
    expect(badges.phoneVerified, isTrue);
    expect(badges.emailVerified, isFalse);
    expect(badges.idVerifiedDemo, isTrue);
    expect(badges.any, isTrue);

    const prod = AppConfig(
      environment: AppEnvironment.prod,
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'public-anon',
      policyVersion: '2026-10-11-draft',
    );
    const demo = AppConfig(
      environment: AppEnvironment.dev,
      supabaseUrl: '',
      supabaseAnonKey: '',
      policyVersion: '2026-10-11-draft',
    );
    const staging = AppConfig(
      environment: AppEnvironment.staging,
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'public-anon',
      policyVersion: '2026-10-11-draft',
    );
    expect(prod.showsDemoIdBadge, isFalse);
    expect(demo.showsDemoIdBadge, isTrue);
    expect(staging.showsDemoIdBadge, isTrue);
  });

  test('owner listing json maps the live chip', () {
    final listing = ownerListingFromJson({
      'id': 'home',
      'title': '2BHK in Koramangala',
      'locality': 'Koramangala',
      'city': 'Bengaluru',
      'rent_inr': 28000,
      'status': 'published',
      'chip': 'live',
      'views': 9,
      'saves': 2,
      'interests': 1,
      'visit_requests': 0,
    });
    expect(listing.chip, 'live');
    expect(listing.place, 'Koramangala, Bengaluru');
    expect(listing.views, 9);
  });
}
