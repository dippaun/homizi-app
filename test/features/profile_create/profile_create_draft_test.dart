import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';

void main() {
  final today = DateTime(2026, 10, 21);

  test('age range follows the profiles check', () {
    expect(ageRangeForBirthYear(2008, today: today), '18-24');
    expect(ageRangeForBirthYear(2000, today: today), '25-30');
    expect(ageRangeForBirthYear(1994, today: today), '31-35');
    expect(ageRangeForBirthYear(1985, today: today), '36-45');
    expect(ageRangeForBirthYear(1970, today: today), '45+');
    expect(validateBirthYear(2009, today: today), isNotNull);
    expect(validateBirthYear(null, today: today), 'Choose your year of birth.');
  });

  test('basic fields and contacts are validated', () {
    expect(validateFullName('A'), isNotNull);
    expect(validateFullName('Asha Mehta'), isNull);
    expect(validateGender('Woman'), isNull);
    expect(validateGender(null), isNotNull);
    expect(validateOccupation('Student'), isNull);
    expect(validateOccupation('Teacher'), isNotNull);
    expect(validateIndianMobile('9876543210'), isNull);
    expect(validateIndianMobile('12345'), isNotNull);
    expect(validateEmailAddress('asha@example.com'), isNull);
    expect(validateEmailAddress('asha'), isNotNull);
    expect(validateAadhaarDigits('234123412341'), isNull);
    expect(validateAadhaarDigits('111111111111'), isNotNull);
    expect(profileOtpMatches('000000'), isTrue);
    expect(profileOtpMatches('123456'), isFalse);
  });

  test('aadhaar field masks every group except the last four', () {
    expect(maskAadhaar('2341'), '2341');
    expect(maskAadhaar('23412'), 'X 3412');
    expect(maskAadhaar('234123412341'), 'XXXX XXXX 2341');

    final pasted = applyAadhaarEdit(
      digits: '',
      previousShown: '',
      nextText: '234123412341',
    );
    expect(pasted.digits, '234123412341');
    expect(pasted.shown, 'XXXX XXXX 2341');

    final typed = applyAadhaarEdit(
      digits: '2341',
      previousShown: '2341',
      nextText: '23415',
    );
    expect(typed.digits, '23415');
    expect(typed.shown, 'X 3415');

    final deleted = applyAadhaarEdit(
      digits: typed.digits,
      previousShown: typed.shown,
      nextText: 'X 341',
    );
    expect(deleted.digits, '2341');
  });

  test('profile row omits phone, email, date of birth, and Aadhaar', () {
    const draft = ProfileCreateDraft(
      fullName: 'Asha Mehta',
      birthYear: 2000,
      gender: 'Woman',
      occupation: 'Student',
      mobile: '9876543210',
      email: 'asha@example.com',
      aadhaarLast4: '2341',
      aadhaarVerified: true,
      sampleAvatar: profileSampleAvatar,
    );
    final row = profileCreateColumns(draft, today: today).toProfileRow();
    expect(row.keys.toSet(), profileCreateWritableColumns);
    expect(row['display_name'], 'Asha Mehta');
    expect(row['occupation'], 'Student');
    expect(row['age_range'], '25-30');
    expect(row['avatar_path'], profileSampleAvatar);
    expect(row.containsKey('phone'), isFalse);
    expect(row.containsKey('email'), isFalse);
    expect(row.containsKey('date_of_birth'), isFalse);
    expect(row.containsKey('aadhaar'), isFalse);
    expect(row.containsKey('gender'), isFalse);
  });
}
