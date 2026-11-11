import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/profile/domain/profile_contact.dart';

void main() {
  test('an Indian mobile is masked to the last four digits', () {
    final shown = shownContact('+91 98450 12321');

    expect(shown.phone, '+91 ••••• 2321');
    expect(shown.email, profileContactMissing);
    expect(containsFullIndianMobile(shown.phone), isFalse);
    expect(shown.phone.contains('98450'), isFalse);
  });

  test('a synthetic phone mailbox is not shown as an email', () {
    final shown = shownContact('919845012321@phone.example.test');

    expect(shown.email, profileContactMissing);
    expect(shown.phone, '+91 ••••• 2321');
    expect(shown.email.contains('@'), isFalse);
    expect(containsFullIndianMobile(shown.phone), isFalse);
  });

  test('an email stays on the email row and does not invent a phone', () {
    final shown = shownContact('ananya@example.test');

    expect(shown.email, 'ananya@example.test');
    expect(shown.phone, profileContactMissing);
  });

  test(
    'the empty offline profile uses a sample contact, not a live number',
    () {
      final facts = profileHeaderFacts(
        profile: const TenantProfile(),
        sessionContact: 'qa+tenant@homizi.in',
        nickname: '',
        offlineDemo: true,
      );

      expect(facts.usingShowcase, isTrue);
      expect(facts.displayName, 'Ananya Iyer');
      expect(facts.occupation, 'Product designer');
      expect(facts.handle, 'ananya');
      expect(facts.email, profileShowcaseEmail);
      expect(facts.phone, profileShowcasePhone);
      expect(containsFullIndianMobile(facts.phone), isFalse);
      expect(
        preferenceLine(facts.preferences),
        'Koramangala, HSR Layout · ₹18,000 – ₹28,000 · Private room',
      );
    },
  );

  test('a saved name is not replaced by the showcase', () {
    final facts = profileHeaderFacts(
      profile: const TenantProfile(
        displayName: 'Meera Iyer',
        occupation: 'Architect',
        preferences: TenantPreferences(localities: ['Bandra West']),
      ),
      sessionContact: 'meera@example.test',
      nickname: 'meera',
      offlineDemo: true,
    );

    expect(facts.usingShowcase, isFalse);
    expect(facts.displayName, 'Meera Iyer');
    expect(facts.handle, 'meera');

    final unnamed = profileHeaderFacts(
      profile: const TenantProfile(displayName: 'Meera Iyer'),
      sessionContact: 'meera@example.test',
      nickname: '',
      offlineDemo: true,
    );
    expect(unnamed.handle, profileContactMissing);
    expect(facts.email, 'meera@example.test');
    expect(facts.phone, profileContactMissing);
    expect(preferenceLine(facts.preferences), 'Bandra West');
  });

  test('a connected empty profile stays empty', () {
    final facts = profileHeaderFacts(
      profile: const TenantProfile(),
      sessionContact: 'qa+tenant@homizi.in',
      nickname: '',
      offlineDemo: false,
    );

    expect(facts.usingShowcase, isFalse);
    expect(facts.displayName, 'Your profile');
    expect(facts.email, 'qa+tenant@homizi.in');
    expect(facts.phone, profileContactMissing);
  });
}
