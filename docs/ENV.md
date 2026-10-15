# Environment configuration

HOMIZI reads configuration from compile-time defines. There is no secrets file in the app, and an empty Supabase pair means demo mode.

## Values

| Define | Values | Notes |
| --- | --- | --- |
| `APP_ENV` | `dev`, `staging`, `prod` | Unknown names fail at startup. `dev` is the default. |
| `SUPABASE_URL` | Project URL, or empty | Local API is `http://127.0.0.1:54321` after `supabase start`. |
| `SUPABASE_ANON_KEY` | Public anon or publishable key, or empty | This is a client key. It is not a secret store. |
| `SUPABASE_PUBLISHABLE_KEY` | Public `sb_publishable_` key, or empty | Used when set. Same role as the anon key. `config/staging.json` sets this for Mumbai. |
| `POLICY_VERSION` | Text version, default `2026-10-11-draft` | Recorded when someone accepts the welcome consent. The legal text itself is not approved. |
| `SHOW_STATE_PREVIEW` | `true` only in a debug build | Hidden unless this define is set. Profile and release builds ignore it. |

No defines, or an empty URL or key, stays in demo mode.

```bash
flutter run
```

Staging uses the committed public client file. It does not contain a service role key or a database password.

```bash
flutter run --dart-define-from-file=config/staging.json
```

For the local API, copy an example and fill the public values. Do not commit that filled file.

```bash
cp config/env.dev.json.example config/env.dev.json
flutter run --dart-define-from-file=config/env.dev.json
```

Examples live at `config/env.dev.json.example`, `config/env.staging.json.example`, and `config/env.prod.json.example`. They ship with empty URL and key fields. The hosted steps are in [STAGING_SETUP.md](STAGING_SETUP.md).

## Flutter version

The owner’s machine runs Flutter 3.44.6 stable, which ships Dart 3.12.2. The SDK constraint is `>=3.12.2 <4.0.0`. `pubspec.lock` is resolved so that floor stays valid: `material_ui` is pinned at 1.2.0 and `cupertino_ui` at 1.0.2. Newer releases of those two packages require Flutter 3.47. CI still installs Flutter 3.47.7 and uses this same lockfile.

## What must stay out

- The service role key. The app never receives it.
- A production database password, an APNs key, or a Firebase server key.
- A real identity-provider secret or a payment secret.

`APP_ENV=prod` refuses the development code `000000`. Demo mode and local dev show that code and do not send SMS or email. Staging with `config/staging.json` emails a sign-in link to `in.homizi.app://login-callback` and refuses a mobile number. A 6-digit code still works when the email includes one. The local fixture password `local-dev-only` is for the seeded `example.test` accounts only. It is not used against the hosted project.

Demo mode (either Supabase value empty) keeps sign-in, profiles, listings, photos, chat, visits, and notifications on the device. It does not claim a server published a listing or a requirement.
