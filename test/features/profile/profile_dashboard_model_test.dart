import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/profile_dashboard_model.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';

void main() {
  test('hidden views count as zero and completeness is computed', () {
    final stats = profileDashboardStats(
      const ProfileActivity(
        savedCount: 0,
        viewedAvailable: false,
        viewedCount: 40,
        requestCount: 0,
        visitCount: 0,
        matchCount: 0,
      ),
    );
    expect(stats.views, 0);
    expect(stats.matches, 0);

    final empty = profileWizardCompleteness(
      draft: const ProfileCreateDraft(),
      profile: const TenantProfile(),
      aadhaarVerified: false,
    );
    expect(empty.percent, lessThan(100));
    expect(empty.percent, isNot(92));
    expect(empty.line, isNot('Profile complete'));

    final ready = profileWizardCompleteness(
      draft: const ProfileCreateDraft(
        roles: ['tenant'],
        nickname: 'Rohan',
        surname: 'Sharma',
        birthYear: 2000,
        birthMonth: 12,
        birthDay: 12,
        gender: 'Man',
        occupation: 'Working professional',
        languages: ['English'],
        mobileVerified: true,
        emailVerified: true,
        selfieVerified: true,
        showPhotoToVerifiedUsers: true,
        sampleAvatar: 'assets/avatars/avatar_01.webp',
        about: 'Software engineer working in Ahmedabad and looking for a flat.',
        city: 'Ahmedabad',
        smoking: 'No',
        drinking: 'Occasional',
        food: 'Both',
        cooking: 'Cook myself',
        cleaning: 'Myself',
        budgetMin: 8000,
        budgetMax: 15000,
        localities: ['Bodakdev'],
        termsAccepted: true,
        privacyAccepted: true,
        consentAccepted: true,
      ),
      profile: const TenantProfile(),
      aadhaarVerified: false,
    );
    expect(ready.percent, 100);
    expect(ready.line, 'Profile complete');
    expect(ready.complete, isTrue);

    final missingLanguage = profileWizardCompleteness(
      draft: const ProfileCreateDraft(
        roles: ['tenant'],
        nickname: 'Rohan',
        surname: 'Sharma',
        birthYear: 2000,
        gender: 'Man',
        occupation: 'Working professional',
        mobileVerified: true,
        emailVerified: true,
        selfieVerified: true,
        smoking: 'No',
        drinking: 'No',
        food: 'Veg',
        cooking: 'Cook myself',
        cleaning: 'Myself',
        termsAccepted: true,
        privacyAccepted: true,
        consentAccepted: true,
      ),
      profile: const TenantProfile(),
      aadhaarVerified: false,
    );
    expect(missingLanguage.percent, lessThan(100));
    expect(missingLanguage.percent, isNot(65));
    expect(
      profileBirthLabel(
        const ProfileCreateDraft(birthDay: 12, birthMonth: 12, birthYear: 2000),
      ),
      '12 Dec 2000',
    );
    expect(profileSwitchTarget('tenant'), 'host');
    expect(profileSwitchTarget('host'), 'tenant');
    expect(profileRoleChip('broker'), 'Property Partner');
  });
}
