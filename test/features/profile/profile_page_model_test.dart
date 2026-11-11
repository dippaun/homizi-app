import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/domain/profile_contact.dart';
import 'package:homizi/features/profile/profile_page_model.dart';
import 'package:homizi/features/profile_create/public_profile.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';

void main() {
  ProfilePageInput input({
    ProfilePageRole role = ProfilePageRole.tenant,
    bool illustration = false,
    TenantProfile profile = const TenantProfile(),
    KycSnapshot kyc = KycSnapshot.notStarted,
    PublicProfile own = const PublicProfile(),
    ShownContact contact = const ShownContact(
      email: profileContactMissing,
      phone: profileContactMissing,
    ),
    UserBadges badges = const UserBadges(),
  }) {
    return ProfilePageInput(
      role: role,
      illustration: illustration,
      profile: profile,
      host: const HostProfile(),
      activity: ProfileActivity.empty,
      badges: badges,
      kyc: kyc,
      own: own,
      contact: contact,
      listings: const [],
    );
  }

  ProfileCheck check(ProfilePageModel model, String title) {
    for (final block in model.blocks) {
      for (final item in block.checks) {
        if (item.title == title) {
          return item;
        }
      }
    }
    fail('Missing $title');
  }

  test('illustration samples match the four spec people', () {
    expect(profileSample(ProfilePageRole.tenant).name, 'Priya Nair');
    expect(profileSample(ProfilePageRole.owner).name, 'Rohan Sharma');
    expect(profileSample(ProfilePageRole.broker).name, 'Neha Kulkarni');
    expect(profileSample(ProfilePageRole.roomie).name, 'Kunal Verma');
    expect(profileSample(ProfilePageRole.owner).darkHeader, isTrue);
    expect(profileSample(ProfilePageRole.broker).darkHeader, isTrue);
    expect(profileSample(ProfilePageRole.tenant).darkHeader, isFalse);
  });

  test(
    'a local identity flag does not mark Aadhaar or the selfie verified',
    () {
      final model = resolveProfilePage(
        input(
          profile: const TenantProfile(displayName: 'Ananya Iyer'),
          own: const PublicProfile(
            identityVerified: true,
            selfieVerified: true,
            mobileVerified: true,
            emailVerified: true,
          ),
          badges: const UserBadges(idVerifiedDemo: true),
        ),
      );

      expect(model.verified, isFalse);
      expect(check(model, 'Aadhaar').status, 'Not verified');
      expect(check(model, 'Aadhaar').detail, 'Not verified yet');
      expect(check(model, 'Selfie').status, 'Not verified');
      expect(check(model, 'Selfie').detail, isNot('Liveness check passed'));
    },
  );

  test('Digio verified Aadhaar and selfie are the only pass', () {
    const kyc = KycSnapshot(
      status: 'verified',
      aadhaarStatus: KycCheckState.verified,
      faceStatus: KycCheckState.verified,
      message: 'Digio passed',
    );
    final model = resolveProfilePage(
      input(
        profile: const TenantProfile(displayName: 'Ananya Iyer'),
        kyc: kyc,
      ),
    );

    expect(model.verified, isTrue);
    expect(check(model, 'Aadhaar').detail, 'Verified via Digio');
    expect(check(model, 'Selfie').detail, 'Liveness check passed');
  });

  test('a raw mobile on the profile is masked', () {
    final model = resolveProfilePage(
      input(
        profile: const TenantProfile(displayName: 'Kabir Shah'),
        contact: const ShownContact(
          email: profileContactMissing,
          phone: '+919845012321',
        ),
        badges: const UserBadges(phoneVerified: true),
      ),
    );
    final phone = check(model, 'Mobile number').detail;
    expect(phone, contains('2321'));
    expect(phone, isNot(contains('98450')));
    expect(containsFullIndianMobile(phone), isFalse);
  });

  test('an empty profile uses the spec copy and still hides Digio', () {
    final model = resolveProfilePage(input());
    expect(model.name, 'Priya Nair');
    expect(model.illustration, isFalse);
    expect(check(model, 'Aadhaar').status, 'Not verified');
    expect(model.verified, isFalse);
  });
}
