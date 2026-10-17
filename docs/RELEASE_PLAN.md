# Release plan

Status on 17 October 2026, against commit `9914e7d`. This file is the path from the current build to a store release. It is not a go-ahead to publish. Store submission stays deferred until there is a signed release, reviewed declarations, and an explicit owner approval.

The readable task audit is [plan/STATUS_1017.md](plan/STATUS_1017.md). Draft store sentences are in [STORE_LISTING.md](STORE_LISTING.md). They are marked not for submission.

## What is already true

- The client is Flutter. Android application id and iOS bundle id are `in.homizi.app`. Android namespace is `app.homizi`.
- Flutter 3.47.7 sets `compileSdk` and `targetSdk` to 36 (`packages/flutter_tools/lib/src/android/gradle_utils.dart` in that SDK: `compileSdkVersionInt = 36`, `targetSdkVersion = '36'`). The app uses `flutter.targetSdkVersion`. The app `minSdk` is 26 because `sentry_flutter` 10 requires Android 8. Recheck Google's target-API page before a real submission. The policy cited by the plan, as checked for this workbook in October 2026, asks new apps and updates to target API 36 from 31 August 2026.
- `dart format --set-exit-if-changed`, `flutter analyze` (no issues), and `flutter test` (140 tests, all passed) succeeded in the 17 October audit. `.github/workflows/ci.yml` runs those checks plus the secret scan, the dependency scan, a debug APK, and `supabase test db`.
- Mumbai staging project `loraalfiuklespaldotd` is live. The installable web app answers at https://homizi.netlify.app (`netlify.toml`, commit `3a6afe6`). That site is a web build, not a Play listing.
- Chat, visits, and in-app notices are in the product. Push is deferred ([PUSH.md](PUSH.md)).

## Path still in front of the owner

1. Install on a phone. USB debugging, then `flutter devices` and `flutter run -d DEVICE_ID`, or install `build/app/outputs/flutter-apk/app-debug.apk` by hand. CI is set up to build that APK. This audit machine has no Android SDK, so it did not produce an APK and did not launch an emulator. No physical-device log is in the repo.
2. Repeatable tester installs go through Firebase App Distribution. `.github/workflows/distribute.yml` uploads a debug APK only when `FIREBASE_APP_ID` and `FIREBASE_TOKEN` are set. Until then the job skips and does not publish.
3. Play Console needs the owner's account, and a decision on whether that account is personal or an organization (D-09). The application id is already `in.homizi.app`.
4. Release signing is still the debug keystore (`android/app/build.gradle.kts`). Create an upload key outside git, back it up, and build `flutter build appbundle`. Do not commit the keystore or its passwords.
5. Internal testing on Play, then a closed test if the account's current rules require it. The workbook cites the rule for personal accounts created after 13 November 2023: at least 12 opted-in testers for 14 continuous days before applying for production access. That wait cannot be done in this repository.
6. Privacy policy, terms, support, account deletion, and Data safety must match the shipped build and sit on stable HTTPS URLs. The drafts in `docs/legal/` are marked for legal review. `test/docs/legal_draft_test.dart` keeps that mark.
7. Production submit, staged rollout, and crash monitoring are owner actions after the release gate. The halt steps are in [ops/INCIDENT_ROLLBACK_RUNBOOK.md](ops/INCIDENT_ROLLBACK_RUNBOOK.md).
8. iOS stays in the tree. `.github/workflows/ios.yml` is a manual macOS job that runs `flutter build ios --no-codesign`. TestFlight needs a Mac, signing, and an Apple Developer account.

## Not release evidence

A green local test run, a debug APK, demo mode, the Netlify web app, and the Mumbai staging project are not a Play submission. The legal drafts are not a privacy-policy URL. Version in `pubspec.yaml` is `1.0.0+1` and has not been tied to a signed app bundle.
