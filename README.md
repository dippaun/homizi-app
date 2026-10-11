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

Empty defines keep demo mode. To point at a **local** Supabase API later, copy an example and pass it at build time. Do not put a service-role key in these files.

```bash
cp config/env.dev.json.example config/env.dev.json
flutter run --dart-define-from-file=config/env.dev.json
```

`APP_ENV` is `dev`, `staging`, or `prod`. Dev and staging show the development OTP `000000` on the sign-in screen. Production refuses that code. No SMS or email is sent in this build.

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

Migrations live in `supabase/migrations/`. Policy tests in `supabase/tests/` cover cross-user reads, direct writes to interests, matches, and payments, and contact leakage.

Studio, when the full stack is up, is at `http://127.0.0.1:54323`. The local API is `http://127.0.0.1:54321`. Use the anon key from `supabase status`, never the service role, in the Flutter defines.

## What this build includes

Screens for splash, consent, sign-in, role, tenant and host profiles, a requirement form, listing editor, photo slots, preview, explore, filters, listing detail, interest, matches, saved homes, report/block, settings, and help. Each main surface has loading, empty, and error states.

Chat, visits, notifications, and payments have tables and access rules where the data model needs them. They do not have product screens, and clients cannot write payments or subscriptions.

Identity verification is a mock gateway. It can move a profile to `mock_pending`. It never stores an Aadhaar number, and the client cannot set `mock_verified`.

## Owner decisions still open

- Placeholder palette: seed teal `#1F6F6A`, clay `#C4553A`, ink `#1C2430`, sand `#F6F1EA`. Replace when the brand is approved.
- One account may hold both tenant and host. That is assumed, not approved.
- A pass after a match does not dissolve the match.
- Contact consent means the owner is sharing their own phone or email.
- Discovery requires a signed-in user. Anonymous clients cannot read listings.
- Compatibility weights (budget 40/15/0, city 25, locality 15, furnishing 10, property type 10) are a proposal. They do not use gender, religion, caste, age, or marital status.
- Store id `in.homizi.app`, with Android namespace `app.homizi`.

## Next

Wire auth and profiles to Supabase, then requirements and listings, photo upload, discovery, and the contact-gate UI against `create_interest`, `create_mutual_match`, and `get_contact_visibility`. Leave payments and real identity checks until those gates are approved.
