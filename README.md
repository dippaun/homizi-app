# HOMIZI

Foundation for a verified rental and flatmate discovery app for India. This repository is the starter Flutter client and the local Supabase schema. It does not talk to a hosted Supabase project, collect identity documents, or take payments.

The client runs in **demo mode** when `SUPABASE_URL` or `SUPABASE_ANON_KEY` is empty. Demo mode uses four fictional Bengaluru and Pune listings. Contact details are never on those cards. A phone or email is shown only by the same rule the database enforces: an active match, no block, and consent from the other person.

## Stack

- Flutter 3.47.7 (Dart 3.13) for Android and iOS
- Riverpod for state, go_router for a guarded shell
- Supabase Postgres, Auth, Storage, and row level security
- The contact gate, interest, and match steps are Postgres functions, not Edge Functions. Edge Functions stay reserved for a future OTP provider and webhooks.

Store application id placeholder: `in.homizi.app`. Android's namespace is `app.homizi` because `in` is not a valid Java package segment. Both are owner decisions.

## Run the app

Install Flutter 3.47.x (stable) and an Android SDK.

```bash
flutter pub get
flutter run
```

Empty defines keep demo mode: sign-in and profiles stay on the device. To use the local API, copy an example and set `SUPABASE_URL` to the project URL from `supabase status`. Set `SUPABASE_ANON_KEY` to `ANON_KEY` or `PUBLISHABLE_KEY` from `supabase status -o env`. Do not put `SERVICE_ROLE_KEY` or `SECRET_KEY` in the app.

```bash
cp config/env.dev.json.example config/env.dev.json
flutter run --dart-define-from-file=config/env.dev.json
```

`APP_ENV` is `dev`, `staging`, or `prod`. Dev and staging show the development code `000000` on the sign-in screen. Production refuses that code. No SMS or email is sent.

When Supabase is configured, that same code signs in with the local fixture password `local-dev-only` (or creates the auth user if they are new). Seed accounts such as `ananya@example.test` already use that password. A mobile number is stored on the private contact row, and the auth mailbox is `91…@phone.example.test`, which is not shown and is cleared from the private email field. One account can save both a tenant profile and a host profile. Mock verification calls `request_mock_verification` and can only reach `mock_pending`.

```bash
flutter analyze
flutter test
flutter build apk --debug
```

An iOS build needs a Mac: `flutter build ios --no-codesign`. See `.github/workflows/ios.yml`.

## Local database

Install the [Supabase CLI](https://supabase.com/docs/guides/cli) (this repo was verified with 2.120.0) and Docker.

```bash
supabase start
supabase db reset
supabase test db
```

`supabase/seed.sql` creates four fake users (`ananya`, `rohan`, `priya`, `kabir` at `example.test`). Their local password is `local-dev-only`. Phone numbers are `+910000000001` through `+910000000004`. That password is a fixture, not a production secret.

Migrations live in `supabase/migrations/`. Policy tests in `supabase/tests/` cover cross-user reads, direct writes to interests, matches, payments, and listing status, publish rules, and contact leakage.

Studio, when the full stack is up, is at `http://127.0.0.1:54323`. The local API is `http://127.0.0.1:54321`. The app takes the public anon or publishable key only.

## What this build includes

Screens for splash, consent, sign-in, role, tenant and host profiles, a requirement form, listing editor, photo slots, preview, explore, filters, listing detail, interest, matches, saved homes, report/block, settings, and help. Each main surface has loading, empty, and error states.

Chat, visits, notifications, and payments have tables and access rules where the data model needs them. They do not have product screens, and clients cannot write payments or subscriptions.

Sign-in and profiles use Supabase when the URL and public key are set, and stay in demo mode otherwise. Identity verification calls the mock function only. It never stores an Aadhaar number, and the client cannot set `mock_verified`.

Requirements and property listings also use Supabase when that pair is set. A row stays a draft until `publish_requirement` or `publish_listing` accepts it. The client never writes `status`, verification status, interests, matches, or payments. Photo slots are rows (`storage_path`, `sort_order`, `photo_type`); the primary slot is sort order 0. No image bytes are uploaded. Demo mode keeps the draft on the device and does not claim the server published it.

## Owner decisions still open

- Placeholder palette: seed teal `#1F6F6A`, clay `#C4553A`, ink `#1C2430`, sand `#F6F1EA`. Replace when the brand is approved.
- One account may hold both tenant and host. That is assumed, not approved.
- A pass after a match does not dissolve the match.
- Contact consent means the owner is sharing their own phone or email.
- Discovery requires a signed-in user. Anonymous clients cannot read listings.
- Compatibility weights (budget 40/15/0, city 25, locality 15, furnishing 10, property type 10) are a proposal. They do not use gender, religion, caste, age, or marital status.
- Store id `in.homizi.app`, with Android namespace `app.homizi`.

## Next

Wire discovery and the contact-gate UI to `create_interest`, `create_mutual_match`, and `get_contact_visibility`. Photo file upload stays deferred. Leave payments and real identity checks until those gates are approved.
