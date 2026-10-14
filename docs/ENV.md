# Environment configuration

HOMIZI reads configuration from compile-time defines. There is no secrets file in the app, and an empty Supabase pair means demo mode.

## Values

| Define | Values | Notes |
| --- | --- | --- |
| `APP_ENV` | `dev`, `staging`, `prod` | Unknown names fail at startup. `dev` is the default. |
| `SUPABASE_URL` | Project URL, or empty | Local API is `http://127.0.0.1:54321` after `supabase start`. |
| `SUPABASE_ANON_KEY` | Public anon or publishable key, or empty | This is a client key. It is not a secret store. |
| `POLICY_VERSION` | Text version, default `2026-10-11-draft` | Recorded when someone accepts the welcome consent. The legal text itself is not approved. |
| `SHOW_STATE_PREVIEW` | `true` only in a debug build | Hidden unless this define is set. Profile and release builds ignore it. |

Copy an example and fill the public values locally. Do not commit the filled file.

```bash
cp config/env.dev.json.example config/env.dev.json
flutter run --dart-define-from-file=config/env.dev.json
```

Examples live at `config/env.dev.json.example`, `config/env.staging.json.example`, and `config/env.prod.json.example`. They ship with empty URL and key fields.

## Flutter version

The owner’s machine runs Flutter 3.44.6 stable, which ships Dart 3.12.2. The SDK constraint is `>=3.12.2 <4.0.0`. `pubspec.lock` is resolved so that floor stays valid: `material_ui` is pinned at 1.2.0 and `cupertino_ui` at 1.0.2. Newer releases of those two packages require Flutter 3.47. CI still installs Flutter 3.47.7 and uses this same lockfile.

## What must stay out

- The service role key. The app never receives it.
- A production database password, an APNs key, or a Firebase server key.
- A real identity-provider secret or a payment secret.

`APP_ENV=prod` refuses the development code `000000`. Dev and staging show that code on the sign-in screen and do not send SMS or email. The local fixture password `local-dev-only` is for the seeded `example.test` accounts only.

Demo mode (either Supabase value empty) keeps sign-in, profiles, listings, photos, chat, visits, and notifications on the device. It does not claim a server published a listing or a requirement.
