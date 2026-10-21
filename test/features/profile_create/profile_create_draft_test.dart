import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';

void main() {
  test('age range follows the profiles check', () {
    expect(ageRangeForAge(18), '18-24');
    expect(ageRangeForAge(24), '18-24');
    expect(ageRangeForAge(26), '25-30');
    expect(ageRangeForAge(31), '31-35');
    expect(ageRangeForAge(40), '36-45');
    expect(ageRangeForAge(46), '45+');
    expect(ageRangeForAge(17), isNull);
    expect(ageRangeForAge(101), isNull);
    expect(validateAge(''), 'Enter your age.');
    expect(validateAge('17'), isNotNull);
    expect(validateAge('26'), isNull);
  });

  test('basic fields and contacts are validated', () {
    expect(validatePersonName('A', 'Enter your first name.'), isNotNull);
    expect(validatePersonName('Priya', 'Enter your first name.'), isNull);
    expect(validatePersonName('Asha', 'Enter a nickname.'), isNull);
    expect(validateCompany(''), isNull);
    expect(validateCompany('Homizi'), isNull);
    expect(validateCompany('x' * 121), isNotNull);
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

  test('public profile row keeps the nickname and hides the legal name', () {
    const draft = ProfileCreateDraft(
      firstName: 'Priya',
      lastName: 'Shah',
      nickname: 'Asha',
      age: 26,
      gender: 'Woman',
      companyName: 'Homizi',
      occupation: 'Student',
      mobile: '9876543210',
      mobileVerified: true,
      email: 'asha@example.com',
      emailVerified: true,
      aadhaarLast4: '2341',
      aadhaarVerified: true,
      selfieVerified: true,
      sampleAvatar: profileSampleAvatar,
    );
    final columns = profileCreateColumns(draft);
    final row = columns.toProfileRow();
    expect(profileRowHidesPrivateColumns(row), isTrue);
    expect(row['display_name'], 'Asha');
    expect(row['nickname'], 'Asha');
    expect(row['occupation'], 'Student');
    expect(row['age'], 26);
    expect(row['age_range'], '25-30');
    expect(row['company_name'], 'Homizi');
    expect(row['mobile_verified'], isTrue);
    expect(row['email_verified'], isTrue);
    expect(row['identity_verified'], isTrue);
    expect(row['selfie_verified'], isTrue);
    expect(row['show_photo_to_verified'], isFalse);
    expect(row.containsKey('avatar_path'), isFalse);
    expect(row.containsKey('first_name'), isFalse);
    expect(row.containsKey('last_name'), isFalse);
    expect(row.containsKey('selfie_path'), isFalse);
    expect(row.containsKey('phone'), isFalse);
    expect(row.containsKey('email'), isFalse);
    expect(row.containsKey('aadhaar'), isFalse);
    expect(columns.firstName, 'Priya');
    expect(columns.lastName, 'Shah');
    expect(columns.selfiePath, profileSampleAvatar);

    final args = columns.toVerificationArgs();
    expect(args['p_first_name'], 'Priya');
    expect(args['p_nickname'], 'Asha');
    expect(args.containsKey('p_aadhaar'), isFalse);
    expect(args.containsKey('aadhaar'), isFalse);

    final shown = profileCreateColumns(
      const ProfileCreateDraft(
        nickname: 'Asha',
        showPhotoToVerifiedUsers: true,
        sampleAvatar: profileSampleAvatar,
      ),
    ).toProfileRow();
    expect(shown['avatar_path'], profileSampleAvatar);
    expect(shown['show_photo_to_verified'], isTrue);
    expect(profileRowHidesPrivateColumns(shown), isTrue);
  });
}
