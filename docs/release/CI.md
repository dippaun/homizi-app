# CI

The workflows under `.github/workflows/` are GitHub Actions files.

| Workflow | When it runs | What it does |
| --- | --- | --- |
| `ci.yml` | Pull requests, pushes to `main`, tags `v*` | `dart format`, `flutter analyze`, `flutter test`, secret scan, dependency scan, and the local Supabase policy tests. |
| `distribute.yml` | Pushes to `main`, tags `v*`, and manual `workflow_dispatch` | Release APK and AAB artifacts. Firebase App Distribution only if `FIREBASE_APP_ID` and `FIREBASE_TOKEN` exist. Netlify only if `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID` exist. |
| `ios.yml` | Manual | `flutter build ios --no-codesign` on macOS. Linux runners cannot build iOS. |

Flutter is pinned to **3.44.9** in each of those workflows.

## Cursor Origin does not run these files

This repository is hosted on Cursor Origin:

`origin.cursor.com/git/deep-paun-dev/homizi-app`

Origin stores `.github/workflows`. A push to Origin `main` does not start GitHub Actions. There is no Actions runner attached to that remote.

## Run them on a GitHub mirror

1. Create a private GitHub repository and mirror this Origin repo to it (`git push --mirror`, or a one-way push of `main` and tags).
2. In the GitHub repo, open Settings → Secrets and variables → Actions.
3. Add secrets by name only. Do not put the values in git, in a workflow file, or in a log.

| Secret | Required for | If it is missing |
| --- | --- | --- |
| `FIREBASE_APP_ID` | Firebase App Distribution | The Firebase job skips and publishes nothing. |
| `FIREBASE_TOKEN` | Firebase App Distribution | Same skip. Both must be set. |
| `NETLIFY_AUTH_TOKEN` | Netlify production deploy | The Netlify job skips and deploys nothing. |
| `NETLIFY_SITE_ID` | Netlify production deploy | Same skip. The value for the HOMIZI site is `6996ebdd-3786-4add-b348-00c5de0725e1`. A different non-empty id fails the job before a deploy. |
| `HOMIZI_UPLOAD_KEYSTORE_BASE64` | Play-signed CI builds | Omitted: the release build uses the debug keystore and logs the warning in `docs/release/SIGNING.md`. |
| `HOMIZI_UPLOAD_STORE_PASSWORD` | With the keystore | If the keystore secret is set and this is missing, the job fails without printing values. |
| `HOMIZI_UPLOAD_KEY_ALIAS` | With the keystore | Same. |
| `HOMIZI_UPLOAD_KEY_PASSWORD` | With the keystore | Same. |

4. Pull requests on the GitHub mirror run `ci.yml`. Pushes to GitHub `main`, and tags such as `v1.0.0`, run `ci.yml` and `distribute.yml`.
5. You can also open the GitHub Actions tab and run **Release artifacts** with `workflow_dispatch`.

The workflows pass secrets only as environment variables. The scripts use `set +x` and do not echo those variables. A missing publish secret is a skip, not a stack trace that contains the value.

`tool/deploy_web.sh` is the same Netlify deploy for a laptop. It exits if either Netlify variable is empty, and it does not print them.

## What a green job is not

A green check job is not a Play release. An APK signed with the debug keystore is not an upload. Firebase distribution and a Netlify deploy stay off until the owner stores the secrets on the GitHub mirror.
