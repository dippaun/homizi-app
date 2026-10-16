import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/l10n/hi_lookup.dart';

void main() {
  test('every Hindi sentence is filled in and keeps addresses out', () {
    expect(hiByEnglish.length, greaterThan(400));
    for (final entry in hiByEnglish.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      expect(entry.value.contains('@'), isFalse, reason: entry.key);
      expect(entry.value.contains('+91'), isFalse, reason: entry.key);
    }
    expect(
      hindiOf(
        'You matched. Contact stays hidden until they share theirs. This screen does not hold a phone number or an email address.',
      ),
      isNot(contains('until you both match')),
    );
    expect(
      hindiOf('How do I delete my account?'),
      isNot('How do I delete my account?'),
    );
    expect(hindiOf('Explore'), 'एक्सप्लोर');
    expect(hindiOf('Sign in'), 'साइन इन');
    expect(hindiOf('2 BHK'), '2 बीएचके');
    expect(hindiOf('Deposit ₹22,000'), 'जमा ₹22,000');
    expect(hindiOf('100% match'), '100% मेल');
    expect(hindiOf('About 6 km'), 'लगभग 6 किमी');
    expect(hindiOf('Slide 2 of 3'), 'स्लाइड 2 / 3');
    expect(hindiOf('Photo 1 of 3'), 'फ़ोटो 1 / 3');
    expect(hindiOf('Map preview'), 'नक्शे का पूर्वावलोकन');
    expect(
      hindiOf('Sunlit 2BHK in Koramangala'),
      isNot(contains('Koramangala')),
    );
  });
}
