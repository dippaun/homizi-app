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
