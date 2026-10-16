import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';

void main() {
  const matchId = '88888888-8888-4888-8888-888888888801';

  test('a read patch writes only read_at', () {
    final patch = notificationReadPatch(DateTime.utc(2026, 10, 11, 12));
    expect(patch.keys.toList(), ['read_at']);
    expect(patch['read_at'], '2026-10-11T12:00:00.000Z');
  });

  test('payload sanitizing keeps ids and drops contact', () {
    final clean = sanitizeNoticePayload({
      'match_id': matchId,
      'visit_id': '77777777-7777-4777-8777-777777777701',
      'phone': '9876543210',
      'email': 'ada@example.test',
      'address_line': '12 MG Road',
      'aadhaar': '123412341234',
      'landmark': 'near the park',
      'latitude': '18.5204',
      'longitude': '73.8567',
      'title': 'Call 9876543210',
    });
    expect(clean.keys.toSet(), {'match_id', 'visit_id'});
    expect(clean['match_id'], matchId);
    expect(clean.containsValue('9876543210'), isFalse);
  });

  test('a ten-digit value is dropped and a digit-heavy uuid is kept', () {
    final clean = sanitizeNoticePayload({
      'match_id': '9876543210',
      'visit_id': matchId,
    });
    expect(clean.containsKey('match_id'), isFalse);
    expect(clean['visit_id'], matchId);
  });

  test('a contact-looking type is not repeated', () {
    expect(noticeSentence('9876543210'), 'Something changed on a match.');
    expect(noticeSentence('ada@example.test').contains('@'), isFalse);
    expect(noticeSentence('message'), 'New message on a match.');
    expect(noticeSentence('visit_accepted'), 'A visit was accepted.');
    expect(noticeSentence('listing_interest'), 'Someone liked a listing.');
  });

  test('a like keeps the property id and drops contact', () {
    const propertyId = 'd1000001-0000-4000-8000-000000000001';
    final notice = noticeFromRow({
      'id': 'notice-like',
      'type': 'listing_interest',
      'payload_minimal': {
        'property_id': propertyId,
        'phone': '9876543210',
        'email': 'ada@example.test',
      },
      'created_at': '2026-10-16T04:00:00Z',
    });
    expect(notice?.propertyId, propertyId);
    expect(notice?.matchId, isNull);
    expect(noticeSentence(notice!.type).contains('@'), isFalse);
  });

  test('a poisoned row does not keep contact fields', () {
    final notice = noticeFromRow({
      'id': 'notice-1',
      'type': 'message',
      'payload_minimal': {
        'phone': '9876543210',
        'address_line': '12 MG Road',
        'email': 'ada@example.test',
        'match_id': '9876543210',
      },
      'created_at': '2026-10-11T12:00:00Z',
      'read_at': null,
    });
    expect(notice, isNotNull);
    expect(notice!.matchId, isNull);
    expect(notice.propertyId, isNull);
    expect(notice.unread, isTrue);
    expect(noticeSentence(notice.type), 'New message on a match.');
  });
}
