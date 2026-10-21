import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/public_profile.dart';

void main() {
  testWidgets('a public card shows the nickname and only finished badges', (
    tester,
  ) async {
    const profile = PublicProfile(
      nickname: 'Asha',
      legalFirstName: 'Priya',
      legalLastName: 'Shah',
      photoRef: profileSampleAvatar,
      viewerVerified: true,
      mobileVerified: true,
    );
    await tester.pumpWidget(_card(profile));

    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Priya'), findsNothing);
    expect(find.text('Shah'), findsNothing);
    expect(find.byKey(const Key('public-profile-initials')), findsOneWidget);
    expect(find.byKey(const Key('public-profile-photo')), findsNothing);
    expect(find.byKey(const Key('badge-Mobile Verified')), findsOneWidget);
    expect(find.text('Email Verified'), findsNothing);
    expect(find.text('Identity Verified'), findsNothing);
    expect(find.text('Selfie Verified'), findsNothing);
  });

  testWidgets('the photo stays hidden until the viewer is verified', (
    tester,
  ) async {
    const hidden = PublicProfile(
      nickname: 'Asha',
      legalFirstName: 'Priya',
      photoRef: profileSampleAvatar,
      showPhotoToVerifiedUsers: true,
      mobileVerified: true,
      emailVerified: true,
      identityVerified: true,
      selfieVerified: true,
    );
    await tester.pumpWidget(_card(hidden));
    expect(find.byKey(const Key('public-profile-initials')), findsOneWidget);
    expect(find.byKey(const Key('public-profile-photo')), findsNothing);
    expect(find.text('Priya'), findsNothing);
    expect(find.byKey(const Key('badge-Identity Verified')), findsOneWidget);
    expect(find.byKey(const Key('badge-Selfie Verified')), findsOneWidget);

    await tester.pumpWidget(_card(hidden.copyWith(viewerVerified: true)));
    expect(find.byKey(const Key('public-profile-photo')), findsOneWidget);
    expect(find.byKey(const Key('public-profile-initials')), findsNothing);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Priya'), findsNothing);
  });
}

Widget _card(PublicProfile profile) {
  return MaterialApp(
    home: Scaffold(body: PublicProfileCard(profile: profile)),
  );
}
