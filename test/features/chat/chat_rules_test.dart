import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';

void main() {
  test(
    'contact text matches the server check and stays out of visit slots',
    () {
      expect(containsContactText('See you at 11'), isFalse);
      expect(containsContactText('Rent is 18000'), isFalse);
      expect(containsContactText('call 9876543210'), isTrue);
      expect(containsContactText('call +91 98765 43210'), isTrue);
      expect(containsContactText('write ada@example.test'), isTrue);
      expect(
        displayMessageBody('call 9876543210'),
        isNot(contains('9876543210')),
      );
      final hidden = chatMessageFromRealtime({
        'id': 'msg-1',
        'sender_id': 'host',
        'body': 'call 9876543210',
        'status': 'sent',
        'created_at': '2026-10-16T04:00:00Z',
      }, 'self');
      expect(hidden, isNotNull);
      expect(hidden!.body, isNot(contains('9876543210')));
      expect(
        chatMessageFromRealtime({
          'id': 'msg-2',
          'sender_id': 'host',
          'body': 'See you at 11',
          'status': 'hidden',
        }, 'self'),
        isNull,
      );

      final slots = visitSlotPayload([DateTime.utc(2026, 11, 2, 5, 30)]);
      expect(slots.single.keys, ['starts_at']);
      expect(slots.single['starts_at'], '2026-11-02T05:30:00.000Z');
      expect(
        publicThreadFields({
          'ok': true,
          'phone': '+919800000000',
          'email': 'ada@example.test',
          'address_line': '12 Demo Lane',
          'status': 'requested',
        }),
        {'ok': true, 'status': 'requested'},
      );
    },
  );
}
