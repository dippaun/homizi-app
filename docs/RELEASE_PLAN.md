# Release plan

Nothing in this file is a go-ahead to publish. Store submission stays blocked until there is a signed release, reviewed declarations, and an explicit owner approval. Draft store sentences are in [STORE_LISTING.md](STORE_LISTING.md).

## Path the sheet describes

1. Install on a phone with USB debugging, or install `app-debug.apk` by hand. CI already builds that APK. The owner runs it on a device.
2. Repeatable tester installs go through Firebase App Distribution. `.github/workflows/distribute.yml` uploads only when `FIREBASE_APP_ID` and `FIREBASE_TOKEN` are set on the repository. Until then the job skips and does not publish.
3. Play Console needs the owner’s account. The application id is `in.homizi.app`. Release signing is not configured; the release build type still uses the debug key so a local `flutter run --release` can start. Do not commit an upload key.
4. Target API is 36 via the Flutter 3.44.6 and 3.47.7 defaults. Recheck Google’s target-API page before a real submission.
5. Internal testing, then a closed test if the Play account’s current rules require it. The sheet cites a rule for personal accounts created after 13 November 2023: at least 12 opted-in testers for 14 continuous days before applying for production access. That wait cannot be done in this repository.
6. Production submit, staged rollout, and monitoring are owner actions after the release gate.
7. iOS stays in the tree. TestFlight needs a Mac and an Apple Developer account. `.github/workflows/ios.yml` is a manual macOS compile without codesign.

## Not release evidence

A green CI run, a debug APK, and demo mode on an emulator are not a Play submission. The legal drafts are not a privacy-policy URL.
