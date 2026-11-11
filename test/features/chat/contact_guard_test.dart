import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/chat/demo_inbox.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/chat/domain/demo_reply.dart';

void main() {
  test('phone numbers, emails, and direct links are blocked', () {
    const blocked = <String>[
      'call 9876543210',
      'call +91 98765 43210',
      '98765-43210',
      '98765.43210',
      '98765/43210',
      '9 8 7 6 5 4 3 2 1 0',
      '98 then 76 then 543210',
      'nine 8 seven 6 five 4 3 2 1 0',
      'nine eight seven six five four three two one zero',
      'double nine eight seven six five four three two one',
      'my number is oh nine eight seven six five four three two one',
      'plus nine one nine eight seven six five four three two one zero',
      '+1 202 555 0143',
      '080 4123 4567',
      '0091 98765 43210',
      'write ada@example.test',
      'priya [at] gmail [dot] com',
      'priya at gmail dot com',
      'my email is priya at example dot com',
      'https://wa.me/919876543210',
      'wa.me/919876543210',
      'https://api.whatsapp.com/send?phone=919876543210',
      'https://t.me/homizi',
      'chat on telegram.me/homizi',
      'Rs 9876543210',
      '9,876,543,210',
    ];
    for (final sample in blocked) {
      expect(containsContactText(sample), isTrue, reason: sample);
    }
  });

  test('rents, dates, home types, floors, and pincodes are not phones', () {
    const allowed = <String>[
      'See you at 11',
      'Rent is 18000',
      'Rent is ₹18,000',
      'Rs. 18,000 for the month',
      'INR 1,80,000 deposit',
      'budget 15000 to 25000',
      '18000 and deposit 50000',
      'a 2BHK on the 4th floor',
      '2 BHK',
      '1RK near the metro',
      'floor 12',
      'Floor 3 of 7',
      'pin 560034',
      'pincode 560001',
      '560001 560038',
      '600001 near 600002',
      'available from 12/11/2026',
      'move in on 2026-11-12',
      'free from 1 Dec',
      'available 15 Nov 2026',
      'meet at 11:30',
      'after 4 pm',
      'The 2BHK is free from 1 Dec. Rent is ₹18,000.',
      'Pin code 560034 is the area, not a door number.',
      'Yes. Saturday morning works for a visit.',
      'one room for one person',
      'oh, the balcony is nice',
      'apartment.me is not a link I meant',
      'whatsapp is not how we talk here',
    ];
    for (final sample in allowed) {
      expect(containsContactText(sample), isFalse, reason: sample);
    }
  });

  test('demo threads and replies stay inside the same rules', () {
    for (final seed in demoInboxSeeds(DateTime(2026, 11, 11, 9))) {
      for (final message in seed.messages) {
        expect(
          containsContactText(message.body),
          isFalse,
          reason: message.body,
        );
      }
    }
    const prompts = <String>[
      'Is the room still available?',
      'What is the rent for the 2BHK?',
      'Saturday morning works for a visit.',
      'See you at 11',
      'Thanks, I will think about it.',
    ];
    for (final prompt in prompts) {
      final reply = demoReplyFor(prompt);
      expect(containsContactText(reply), isFalse, reason: reply);
      expect(reply, isNot(prompt));
    }
  });
}
