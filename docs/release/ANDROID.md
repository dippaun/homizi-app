# Android release build

Checked against Google's target-API policy page as cited in the plan (API 36+ for new apps and updates from 31 Aug 2026). Re-check that page before a real submission.

| Setting | Value |
| --- | --- |
| Application id | `in.homizi.app` |
| Namespace | `app.homizi` |
| compileSdk | **36** |
| targetSdk | **36** |
| minSdk | **26** (Android 8). `sentry_flutter` 10.1.0 requires it. |
| versionName / versionCode | `docs/release/VERSIONING.md` |
| R8 | `isMinifyEnabled` and `isShrinkResources` on the release build type. Rules in `android/app/proguard-rules.pro`. |
| Signing | `docs/release/SIGNING.md` |

`sentry_flutter` is pinned at 10.1.0 so the Android build uses the Flutter 3.44 Kotlin toolchain. The 8.x plugin set Kotlin language 1.6 and failed to compile. A release APK and an app bundle built with Flutter 3.44 are the check that this pin still compiles.

## Commands

These are the commands the release workflow runs, without the CI version override:

```bash
flutter build apk --release
flutter build appbundle --release
```

Artifacts:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/mapping/release/mapping.txt` when R8 writes one

Keep the mapping file with the exact build you upload. Do not commit it.

The release manifest declares `android.permission.INTERNET` so a release build can reach Supabase. The merged permission list for a given build is in `docs/store/PERMISSIONS.md`.

Flutter for these commands is the 3.44 line. CI pins **3.44.9**.
