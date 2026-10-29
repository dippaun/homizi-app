import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/notifications/domain/notice_category.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/domain/profile_completion.dart';
import 'package:homizi/features/support/domain/faq_catalog.dart';

void main() {
  test('completion counts filled profile fields and skips contact', () {
    final empty = profileCompletion(
      const CompletionInput(
        displayName: '',
        occupation: '',
        bio: 'short',
        hasBudget: false,
        hasLocality: false,
        hasRole: false,
      ),
    );
    expect(empty.filled, 0);
    expect(empty.total, 6);

    final full = profileCompletion(
      const CompletionInput(
        displayName: 'Ananya Iyer',
        occupation: 'Product designer',
        bio: 'Looking for a quiet furnished room in Koramangala.',
        hasBudget: true,
        hasLocality: true,
        hasRole: true,
      ),
    );
    expect(full.filled, 6);
    expect(full.percent, 100);
    expect(profileInitials('Ananya Iyer'), 'AI');
    expect(profileInitials(''), 'H');
  });

  test('profile activity parses counts and hides a missing viewed list', () {
    final activity = profileActivityFromJson({
      'saved_count': 2,
      'viewed_available': false,
      'viewed_count': null,
      'request_count': 1,
      'visit_count': 1,
      'match_count': 1,
      'saved': [
        {
          'title': 'Sunlit 2BHK in Koramangala',
          'locality': 'Koramangala',
          'city': 'Bengaluru',
        },
      ],
      'viewed': <Object>[],
      'requests': [
        {'city': 'Bengaluru', 'budget_min_inr': 18000, 'budget_max_inr': 28000},
      ],
      'visits': [
        {'status': 'requested', 'on': '2026-10-12'},
      ],
      'matches': [
        {'name': 'Rohan M.'},
      ],
    });

    expect(activity.viewedAvailable, isFalse);
    expect(activity.saved.single.place, 'Koramangala, Bengaluru');
    expect(activity.requests.single.budgetMaxInr, 28000);
    expect(activity.matches.single.name, 'Rohan M.');
    expect(activity.visits.single.listingId, isNull);
  });

  test('a visit keeps the listing id when the payload has one', () {
    final activity = profileActivityFromJson({
      'saved_count': 0,
      'visit_count': 1,
      'visits': [
        {
          'status': 'agreed',
          'on': '2026-11-04',
          'id': 'visit-1',
          'match_id': 'match-1',
          'listing_id': 'lst_hsr',
          'title': '2 BHK near HSR Layout BDA',
        },
      ],
    });
    final visit = activity.visits.single;
    expect(visit.visitId, 'visit-1');
    expect(visit.matchId, 'match-1');
    expect(visit.listingId, 'lst_hsr');
    expect(visit.listingTitle, '2 BHK near HSR Layout BDA');
  });

  test('notification categories and help search', () {
    expect(categoryForType('match'), NoticeCategory.matches);
    expect(categoryForType('message'), NoticeCategory.chat);
    expect(categoryForType('visit_accepted'), NoticeCategory.visits);
    expect(categoryForType('listing_interest'), NoticeCategory.listings);
    expect(categoryForType('deposit_reminder'), NoticeCategory.system);

    final payments = searchFaqs(query: 'checkout', category: 'all');
    expect(payments, isNotEmpty);
    expect(payments.every((entry) => entry.category == 'payments'), isTrue);

    final hidden = searchFaqs(query: 'delete my account', category: 'payments');
    expect(hidden, isEmpty);

    final safety = searchFaqs(query: '', category: 'safety');
    expect(
      safety.map((entry) => entry.question),
      contains('How do I report someone?'),
    );
    expect(supportMessageError('call me'), isNotNull);
    expect(
      supportMessageError('Need help with a Koramangala visit please'),
      isNull,
    );
    expect(supportMessageError('mail me at ada@example.test today'), isNotNull);
  });
}
