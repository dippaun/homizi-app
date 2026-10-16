# HOMIZI

Foundation for a verified rental and flatmate discovery app for India. This repository is the starter Flutter client and the local Supabase schema. It does not talk to a hosted Supabase project, collect identity documents, or take payments.

The client runs in **demo mode** when `SUPABASE_URL` or `SUPABASE_ANON_KEY` is empty. Demo mode uses fictional homes in Bengaluru, Pune, Mumbai, Hyderabad, and Delhi NCR. Contact details are never on those cards. A phone or email is shown only by the same rule the database enforces: an active match, no block, and consent from the other person.

Guides: [environment](docs/ENV.md), [local Supabase](docs/SUPABASE.md), [push placeholders](docs/PUSH.md), [store copy draft](docs/STORE_LISTING.md), [privacy draft](docs/legal/PRIVACY.md), [terms draft](docs/legal/TERMS.md), [plan diff](docs/plan/PLAN_DIFF.md). The privacy notice and terms are marked for legal review and are not approved. The October execution plan is compared with this build in the plan diff.

## Stack

- Flutter 3.44.6 stable (Dart 3.12.2) resolves `pubspec.lock`. CI runs Flutter 3.47.7.
- Riverpod for state, go_router for a guarded shell
- Supabase Postgres, Auth, Storage, and row level security
- The contact gate, interest, and match steps are Postgres functions, not Edge Functions. Edge Functions stay reserved for a future OTP provider and webhooks.

Store application id placeholder: `in.homizi.app`. Android's namespace is `app.homizi` because `in` is not a valid Java package segment. Both are owner decisions.

## Run the app

Install Flutter 3.44.6 stable (the lockfile’s floor) or the CI version 3.47.7, plus an Android SDK. `material_ui` 1.2.0 and `cupertino_ui` 1.0.2 are pinned so resolution does not float onto Flutter 3.47-only releases.

```bash
flutter pub get
flutter run
```

Empty defines keep demo mode: sign-in and profiles stay on the device. Staging against the Mumbai project is `flutter run --dart-define-from-file=config/staging.json`. That file holds the public URL and publishable key only. See [staging setup](docs/STAGING_SETUP.md). To use the local API, copy an example and set `SUPABASE_URL` to the project URL from `supabase status`. Set `SUPABASE_ANON_KEY` or `SUPABASE_PUBLISHABLE_KEY` to `ANON_KEY` or `PUBLISHABLE_KEY` from `supabase status -o env`. Do not put `SERVICE_ROLE_KEY` or `SECRET_KEY` in the app.

```bash
cp config/env.dev.json.example config/env.dev.json
flutter run --dart-define-from-file=config/env.dev.json
```

`APP_ENV` is `dev`, `staging`, or `prod`. Dev and staging show the development code `000000` on the sign-in screen. Production refuses that code. No SMS or email is sent.

The Content / Loading / Empty / Error row on Explore, Discover, Matches, and Saved stays hidden. A debug build can show it with `--dart-define=SHOW_STATE_PREVIEW=true`. Profile and release builds ignore that flag.

English and Hindi catalogs are in `lib/l10n`. Settings switches the whole app between those languages, including buttons, help, and demo home titles. Regenerate with `flutter gen-l10n` after an edit to the ARB files. The lookup used on screen is `lib/l10n/hi_lookup.dart`, generated from `tool/hi_pairs_data.py`.

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

Migrations live in `supabase/migrations/`. Policy tests in `supabase/tests/` cover cross-user reads, direct writes to interests, matches, payments, and listing status, publish rules, contact leakage, and notification payloads.

Studio, when the full stack is up, is at `http://127.0.0.1:54323`. The local API is `http://127.0.0.1:54321`. The app takes the public anon or publishable key only.

## What this build includes

Screens for splash, consent, sign-in, role, tenant and host profiles, a requirement form, listing editor, photo slots, preview, explore, filters, listing detail, interest, matches, saved homes, notifications, report/block, settings, and help. Each main surface has loading, empty, and error states.

Payments have a table and access rules. They do not have a product screen, and clients cannot write payments or subscriptions.

Sign-in and profiles use Supabase when the URL and public key are set, and stay in demo mode otherwise. Identity verification calls the mock function only. It never stores an Aadhaar number, and the client cannot set `mock_verified`.

Requirements and property listings also use Supabase when that pair is set. A row stays a draft until `publish_requirement` or `publish_listing` accepts it. The client never writes `status`, verification status, interests, matches, or payments. Photo slots are rows (`storage_path`, `sort_order`, `photo_type`); the primary slot is sort order 0. Chosen JPEG, PNG, or WebP files upload into the private `listing-photos` bucket at `{userId}/{propertyId}/{fileId}.{ext}`. The original file name is not used. Moderation stays `pending`. Empty slots are records only. Demo mode keeps the file on the device and does not claim the server published the listing. Listing cards show locality and city, not a street address, phone, or email.

Explore and Discover load published homes when that pair is set, and the demo catalog otherwise. That offline catalog has forty homes and flatmate profiles across Bengaluru, Pune, Mumbai, Hyderabad, and Delhi NCR. Likes, passes, and saves call `create_interest`. A like then calls `create_mutual_match`. The contact panel shows a phone or email only when `get_contact_visibility` returns it. Sharing your own contact calls `grant_contact_consent`, and stopping calls `revoke_contact_consent`. Neither call returns a phone or an email. A hidden visibility response still drops both. A pass does not remove a match. Demo mode keeps those actions on the device and never shows a phone or an email.

Chat opens from a match. A new match gets a `conversations` row. `send_message` stores the text and refuses a phone number or an email address. The same check is a constraint on `messages`, so a direct insert cannot bypass it. Clients cannot set message status. When the app is connected to Supabase, the thread listens on Realtime for new rows in `messages`. Row level security still hides a message after a block, and a row that fails the contact check never arrives. Demo mode does not open that channel. It keeps the thread on the device and still refuses contact details. `request_visit` stores one to three start times and nothing else. The other person accepts or declines with `respond_visit`. The requester can cancel. Clients cannot set visit status themselves. Accepting a visit does not reveal a street address. A suspended account cannot send.

Notifications are in-app rows for a new match, a message, or a visit. A match notifies both people. A message notifies the other person only, and the body is not copied into the row. A visit request notifies the other person. Accepting or declining notifies the requester. Cancelling notifies the other person. The payload is `match_id` plus, when needed, `visit_id` or `conversation_id`. Clients cannot insert a notification or change its type or payload. Marking one read writes `read_at` only. The inbox shows a fixed sentence, never the raw payload, so a phone, an email, or a street address cannot appear there. Demo mode keeps those rows on the device and says the server was not updated.

## Owner decisions

Approved on 12 October 2026, with the brand palette updated on 14 October 2026. The record is [DECISIONS.md](DECISIONS.md): white field and the orange mark, one account for tenant and host, a pass does not unmatch, the drafted contact-consent wording, signed-in discovery, the compatibility weights, store id `in.homizi.app` with Android namespace `app.homizi`, and no phone or email in chat.

Reports and blocks are stored. A block stops messages and contact in both directions. A person in `staff_roles` can open Review reports, mark a report reviewing, resolved, or dismissed, pause a published listing, and suspend another account. Those writes go through staff functions. Clients still cannot update report status, listing status, or user status directly. No staff user is seeded, and no moderator is named. Demo mode does not open the queue. Account deletion on this device or the connected local server removes the profile, listings, photos, messages, and the private contact row.

Product counts go in `analytics_events` when Supabase is connected and the Settings switch is on. The row is an event name plus, at most, a listing id or a match id. Phone numbers, email addresses, and names are rejected. Settings can turn this off for the session. Staff can read the funnel views. Other accounts cannot. Error reports through Sentry stay off unless the build is compiled with `SENTRY_DSN`. That value is not committed.

## Still blocked

Real payments, real Aadhaar or identity checks, push provider credentials, a production Supabase project and production secrets, store submission, a named moderator, approved legal text, and production backups. Local deletion does not call those vendors. The staff queue is empty until someone is added to `staff_roles`.
