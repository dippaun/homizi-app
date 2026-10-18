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
| `SENTRY_DSN` | Empty, or a DSN for one build | Empty means error reporting stays off. Do not commit a DSN. |
| `STAGING_TEST_PASSWORD` | Throwaway staging password, or empty | Read only when `APP_ENV` is `staging`. Signs in `test@homizi.in` when the code is `000000`. Production drops the value. `config/staging.json` commits `REDACTED_STAGING_PASSWORD` for that one mailbox. It is not a production secret. |

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
- A Sentry DSN. Leave `SENTRY_DSN` empty in committed files.

`APP_ENV=prod` refuses the development code `000000`. Demo mode and local dev show that code and do not send SMS or email. Staging with `config/staging.json` emails a 6-digit code (`signInWithOtp` with no `emailRedirectTo`, then `verifyOTP` type `email`) and refuses a mobile number. A link in that email is only a fallback. `STAGING_PASSWORD_AUTH=true` in that file also allows an email and password on staging. Production ignores the flag. The same file commits `STAGING_TEST_PASSWORD` (`REDACTED_STAGING_PASSWORD`) for the throwaway mailbox `test@homizi.in` and for a fresh `qa+…@homizi.in` mailbox. That code `000000` uses `signInWithPassword` on staging only, then `ensure_own_account`. A `qa+` mailbox is created first by `staging_create_test_user` when it is missing. Production ignores that path even if the define is set. See [EMAIL_OTP_SETUP.md](EMAIL_OTP_SETUP.md) and [TEST_ACCOUNTS.md](TEST_ACCOUNTS.md). The local fixture password `local-dev-only` is for the seeded `example.test` accounts only. It is not used against the hosted project.

Demo mode (either Supabase value empty) keeps sign-in, profiles, listings, photos, chat, visits, and notifications on the device. It does not claim a server published a listing or a requirement.

Optional dart-defines, all empty in committed files: `OSM_TILE_URL`, `OSM_USER_AGENT`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_VAPID_KEY`, `RAZORPAY_KEY_ID`. An empty Razorpay key uses the demo gateway. A live Razorpay key is refused. Map tiles default to OpenStreetMap. Setup steps are in `docs/PUSH_SETUP.md`, `docs/PAYMENTS_SETUP.md`, and `docs/KYC_ESTAMP_SETUP.md`. Edge secrets (`FCM_SERVICE_ACCOUNT`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `DIGIO_CLIENT_ID`, `DIGIO_CLIENT_SECRET`, `RESEND_API_KEY`) stay in Supabase, not in the app.
