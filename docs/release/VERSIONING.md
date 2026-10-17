# Version name and version code

`pubspec.yaml` is the local source of truth:

```yaml
version: 1.0.0+1
```

| Piece | Android field | Rule |
| --- | --- | --- |
| `1.0.0` | `versionName` | `MAJOR.MINOR.PATCH`. This is the version people see on Play. |
| `1` | `versionCode` | A positive integer. Every Play upload must use a higher code than the last upload of this application id. Never reuse a code. |

`android/app/build.gradle.kts` maps those Flutter values straight through. The current tree is `versionName` **1.0.0** and `versionCode` **1**. That pair is the local default. It is not a Play submission.

Override either value without editing the file:

```bash
flutter build appbundle --release --build-name 1.0.0 --build-number 2
flutter build apk --release --build-name 1.0.0 --build-number 2
```

## CI

`.github/workflows/distribute.yml` builds on `main` and on tags `v*`.

- `versionName` comes from `pubspec.yaml`, unless the ref is a tag `vMAJOR.MINOR.PATCH`. The tag name, without the leading `v`, becomes `versionName`.
- `versionCode` is `100000 + GITHUB_RUN_NUMBER` for that workflow. It stays above the local `+1` and increases on each run of the workflow.

Renaming the workflow resets `GITHUB_RUN_NUMBER`. Before a Play upload, confirm the code is still higher than any code already used on this application id.

The APK and the AAB from one job share the same name and code.
