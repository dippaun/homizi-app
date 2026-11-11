import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/routing/session_redirect.dart';
import 'package:homizi/features/host/host_intent.dart';
import 'package:homizi/features/host/host_onboarding.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/safety/domain/contact_visibility_policy.dart';
import 'package:homizi/features/session/session_state.dart';

void main() {
  test('one account can hold more than one host role', () {
    const draft = HostOnboardingDraft(
      roles: {HostRole.owner, HostRole.broker},
      fullName: 'Priya Shah',
      nickname: 'Asha',
      mobile: '9820098200',
      email: 'asha@example.com',
    );
    expect(draft.roles, containsAll([HostRole.owner, HostRole.broker]));
    expect(
      hostOnboardingErrors(draft: draft, step: 1, identityComplete: false),
      isEmpty,
    );
    expect(primaryHostCategory(draft.roles), 'owner');
    expect(primaryHostCategory({HostRole.broker, HostRole.roomie}), 'broker');
    expect(primaryHostCategory({HostRole.roomie}), 'flatmate');
    expect(primaryHostCategory({HostRole.company}), 'company');
  });

  test('an existing tenant must confirm the rental agreement', () {
    const blocked = HostOnboardingDraft(roles: {HostRole.roomie});
    expect(
      hostOnboardingErrors(draft: blocked, step: 1, identityComplete: false),
      contains('Confirm that your rental agreement permits sharing.'),
    );
    final allowed = blocked.copyWith(agreementPermitsShare: true);
    expect(
      hostOnboardingErrors(draft: allowed, step: 1, identityComplete: false),
      isEmpty,
    );
  });

  test('company registration is required only for a company role', () {
    const person = HostOnboardingDraft(
      roles: {HostRole.owner},
      fullName: 'Amit Mehta',
      nickname: 'Amit',
      mobile: '9811111111',
      email: 'amit@example.com',
      bio: 'I rent a room in Andheri.',
    );
    expect(
      hostOnboardingErrors(draft: person, step: 4, identityComplete: true),
      isEmpty,
    );
    final company = person.copyWith(roles: {HostRole.company});
    expect(
      hostOnboardingErrors(draft: company, step: 4, identityComplete: true),
      containsAll([
        'Enter the company name.',
        'Enter the company registration number.',
      ]),
    );
    final ready = company.copyWith(
      companyName: 'UrbanStay Homes',
      registrationNo: 'U74999MH2020PTC334455',
    );
    expect(
      hostOnboardingErrors(draft: ready, step: 4, identityComplete: true),
      isEmpty,
    );
    expect(
      hostOnboardingErrors(
        draft: ready.copyWith(registrationNo: 'no'),
        step: 4,
        identityComplete: true,
      ),
      contains('Enter a valid registration number.'),
    );
  });

  test('submitting property authorization cannot verify it', () {
    const draft = HostOnboardingDraft(roles: {HostRole.owner});
    expect(
      authorizationStatus(draft, PropertyAuthKind.ownerDocument),
      PropertyAuthStatus.notSubmitted,
    );
    final reviewed = submitAuthorization(draft, PropertyAuthKind.ownerDocument);
    expect(
      authorizationStatus(reviewed, PropertyAuthKind.ownerDocument),
      PropertyAuthStatus.underReview,
    );
    final again = submitAuthorization(reviewed, PropertyAuthKind.ownerDocument);
    expect(
      authorizationStatus(again, PropertyAuthKind.ownerDocument),
      PropertyAuthStatus.underReview,
    );
    final staff = draft.copyWith(
      authorizations: {
        PropertyAuthKind.ownerDocument: PropertyAuthStatus.verified,
      },
    );
    expect(
      authorizationStatus(
        submitAuthorization(staff, PropertyAuthKind.ownerDocument),
        PropertyAuthKind.ownerDocument,
      ),
      PropertyAuthStatus.verified,
    );
  });

  test('public host data hides the legal name and contact', () {
    const host = HostOnboardingDraft(
      roles: {HostRole.broker},
      fullName: 'Priya Shah',
      nickname: 'Asha',
      mobile: '9820098200',
      email: 'asha@example.com',
      registrationNo: 'U74999MH2020PTC334455',
      plan: HostPlan.premium,
    );
    final row = hostOnboardingPublicRow(host);
    expect(hostPublicRowHidesPrivateColumns(row), isTrue);
    expect(row.values, isNot(contains('Priya Shah')));
    expect(row.values, isNot(contains('9820098200')));
    expect(row.values, isNot(contains('asha@example.com')));
    expect(row.values, isNot(contains(host.registrationNo)));
    expect(splitLegalName(host.fullName).first, 'Priya');

    const profile = ProfileCreateDraft(
      nickname: 'Asha',
      mobile: '9820098200',
      email: 'asha@example.com',
      mobileVerified: true,
      emailVerified: true,
      aadhaarVerified: true,
      selfieVerified: true,
    );
    final hidden = hostOnboardingPrivacy(host: host, profile: profile);
    expect(hidden.publicName, 'Asha');
    expect(hidden.phone, isNull);
    expect(hidden.email, isNull);
    expect(hidden.showsPhoto, isFalse);
    expect(hidden.identityBadges, contains('Mobile Verified'));

    final granted = hostPrivacyView(
      nickname: host.nickname,
      profile: profile,
      contact: const ContactVisibilityDecision.granted(
        phone: '9820098200',
        email: 'asha@example.com',
      ),
    );
    expect(granted.phone, '9820098200');
    expect(granted.showsPhoto, isFalse);
  });

  test('host onboarding stays open with no session', () {
    expect(hostResumePath(RoutePaths.hostOnboard), RoutePaths.hostOnboard);
    for (final phase in SessionPhase.values) {
      expect(
        sessionRedirect(
          phase: phase,
          location: RoutePaths.hostOnboard,
          hasConsent: false,
          demoSkipLogin: true,
        ),
        isNull,
        reason: '$phase',
      );
    }
  });

  test('staging SQL keeps identity and property checks apart', () {
    final sql = File('docs/staging_apply_HOST_1022.sql').readAsStringSync();
    expect(sql, contains('reset role'));
    expect(sql, contains('on conflict (version) do update'));
    expect(sql, isNot(contains(r'\i ')));
    expect(sql, contains('host_authorizations'));
    expect(sql, contains('under_review'));
    expect(sql, contains('revoke select (legal_full_name)'));
    expect(sql, contains('apply_host_onboarding'));
    expect(sql, isNot(contains('p_phone')));
    expect(sql, isNot(contains('p_email')));
    expect(sql, isNot(contains('p_aadhaar')));
    expect(sql.toLowerCase(), isNot(contains('aadhaar_number')));
    expect(sql, isNot(contains('sb_secret_')));
    expect(sql, isNot(contains('service_role_key')));
  });
}
