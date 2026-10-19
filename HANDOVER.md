# HOMIZI handover

Status for a new developer. Written 19 Oct 2026 from the owner's assistant notes, then checked against this repository and `git fetch`.

Owner: deep paun (solo, deeppaun123@gmail.com). Product: HOMIZI, a verified rental, flatmate, host, and broker app for India. HOMIZI serves tenants, roommate finders, hosts, and brokers.

Design: Material 3 only, white background, one orange accent `#F75620`, premium spacing, realistic Indian content. Never use NoBroker branding, text, or images. NoBroker Play Store screenshots were used only as a feature checklist.

Repo: https://cursor.com/codebase/deep-paun-dev/homizi-app

`main` at the time of this file: `40621141327298cf0a42bf1d4c81ba7e73daa5d6` ("Add staging qa+ mailboxes so each update can start onboarding fresh.").

## Tech stack and repo layout

Verified in the tree on that commit:

| Layer | What the repo uses |
| --- | --- |
| Client | Flutter / Dart. `pubspec.yaml` is `1.0.0+1`, SDK `>=3.12.2 <4.0.0`. |
| CI Flutter | `.github/workflows/ci.yml` pins Flutter **3.44.9** and Supabase CLI **2.120.0**. `README.md` still mentions 3.47.7; the workflow file is the pin. |
| UI | Material 3, seed `#F75620`, Plus Jakarta Sans (`docs/TECH_STACK.md`). |
| State | Riverpod and go_router. |
| Backend | Supabase Postgres, Auth, Storage, RLS. Migrations in `supabase/migrations/`. |
| Android | `minSdk` 26. `compileSdk` / `targetSdk` follow the Flutter default (API 36 on 3.44). Namespace `app.homizi`. Store id placeholder `in.homizi.app`. |
| Languages | English and Hindi (`lib/l10n`, `lib/core/l10n/translate.dart`). |

Layout:

- `lib/` Flutter app. Features live under `lib/features/` (account, discovery, explore, home, listings, requirements, roles, profile, settings, shell, and the rest).
- `supabase/migrations/` schema. `supabase/tests/` pgTAP (18 files, `01` through `13`, plus `B13`, `C13`, `D13`, `H17`, `M19`).
- `supabase/functions/` Edge Function source. Eight functions plus `_shared`: `send-push`, `create-razorpay-order`, `razorpay-webhook`, `start-kyc`, `kyc-webhook`, `create-esign`, `esign-webhook`, `notify-service-lead`.
- `docs/` setup and product notes. `docs/staging_apply_*.sql` is what gets pasted into the hosted SQL editor.
- `web/` PWA shell. `netlify.toml` publishes `build/web`.
- `test/` Flutter tests. `tool/` scans and the web service-worker installer.

Key docs: `docs/ENV.md`, `docs/STAGING_SETUP.md`, `docs/SUPABASE.md`, `docs/TECH_STACK.md`, `docs/TEST_ACCOUNTS.md`, `docs/EMAIL_OTP_SETUP.md`, `docs/DATA_MODEL.md`, `docs/SECURITY_AND_PRIVACY.md`, `docs/PRODUCT_SPEC.md`, `docs/DECISIONS.md`, `docs/KYC_ESTAMP_SETUP.md`, `docs/PAYMENTS_SETUP.md`, `docs/PUSH_SETUP.md`, `docs/PUSH.md`, `docs/DEMO_MEDIA.md`, `docs/RELEASE_PLAN.md`, `docs/STORE_LISTING.md`, `docs/ROLLBACK.md`, `docs/release/WEB.md`, `docs/release/ANDROID.md`, `docs/release/SIGNING.md`, `docs/legal/PRIVACY.md`, `docs/legal/TERMS.md`, `docs/plan/PLAN_DIFF.md`.

`docs/staging_apply_*.sql` on `main`:

- `docs/staging_apply.sql`
- `docs/staging_apply_next.sql`
- `docs/staging_apply_fix_1016.sql`
- `docs/staging_apply_A_1017b.sql`
- `docs/staging_apply_B_1017.sql`
- `docs/staging_apply_B_1017b.sql`
- `docs/staging_apply_C_1017.sql`
- `docs/staging_apply_C_1017b.sql`
- `docs/staging_apply_D_1017b.sql`
- `docs/staging_apply_E_1017c.sql`
- `docs/staging_apply_F_1017c.sql`
- `docs/staging_apply_H_1017.sql`
- `docs/staging_apply_J_1019.sql` (role column only; the later broker migration is not in this file)
- `docs/staging_apply_M_1019.sql`

## Environments and how to run/deploy

Staging Supabase project ref: `loraalfiuklespaldotd` (Mumbai). Schema is applied by pasting `docs/staging_apply_*.sql` into the dashboard SQL editor. Do not `supabase db reset` the hosted project. Do not `supabase config push`.

The owner's assistant reports these pastes already returned Success: `staging_apply.sql`, `staging_apply_next.sql`, `C_1017`, `B_1017`, `B_1017b`, `C_1017b`, `A_1017b`, `D_1017b`, `E_1017c`, `F_1017c`, `H_1017`, `M_1019`. That list does not include `staging_apply_J_1019.sql`, `staging_apply_fix_1016.sql`, or any K/L file.

Web app (installable PWA): https://homizi.netlify.app (Netlify site `6996ebdd-3786-4add-b348-00c5de0725e1`). Deploy is manual: `flutter build web --release`, then `tool/install_web_sw.py` (see `docs/release/WEB.md`), zip `build/web`, POST the zip to the Netlify deploys API. The last deploy the assistant recorded is commit `7b4d8b8` (Home hub). `28d35f4` (role column) and `4062114` (qa+ test logins) are on `main` and are not on that Netlify deploy.

Local demo (no project):

```bash
flutter pub get
flutter run
```

Staging app (public URL and publishable key only; the file is committed):

```bash
flutter run --dart-define-from-file=config/staging.json
```

Local database:

```bash
supabase start
supabase db reset
supabase test db
```

Checks CI runs on `main`: `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `dart run tool/secret_scan.dart`, `dart run tool/dependency_scan.dart`, then `supabase test db`.

Android: a debug-signed APK `1.0.0` was built 17 Oct 2026 from `b842b31` (`b842b31c6caf174c04dcf47154f7037b6a7d9c23`, on `main`). There is no release upload key. The owner's Windows PC has a `homizi` command that opens VS Code, the emulator, and the app.

A normal `flutter test` on this `main` registers **247** tests. `test/` declares 280 `test` / `testWidgets` calls; 33 of those sit behind screenshot gates (`HOMIZI_CAPTURE_DIR`, `HOMIZI_STORE_SHOTS`) and are not registered unless that directory is set. The owner's assistant recorded the 247 as passing at `4062114`. This handover did not re-run the suite. pgTAP is the 18 files under `supabase/tests/`. The assistant reports the database job, including `supabase/tests/H17_kyc_live.sql`, has not run in CI.

## Test logins

Staging only. The sign-in code is `000000`. That code is not an emailed OTP.

- `test@homizi.in` / `000000` — existing shared tester. Does not create a new user.
- `qa+<suffix>@homizi.in` / `000000` — creates a new empty account when the mailbox is missing (suffix 1–32 of `a-z`, `0-9`, `-`). Examples: `qa+build-1019@homizi.in`. The SQL for this path is applied (`docs/staging_apply_M_1019.sql`). The app behavior needs a web redeploy from `main` before it works on https://homizi.netlify.app.
- Any other mailbox uses the 6-digit code from email.

The throwaway password those two mailboxes use is `STAGING_TEST_PASSWORD` in `config/staging.json`. It is not repeated in this file. Production builds ignore that path. Local Docker seed users (`ananya@example.test` and the other `example.test` accounts) use the fixture password `local-dev-only` from `README.md`. Details: `docs/TEST_ACCOUNTS.md`.

## Done

On `main` (`4062114`):

- Foundation: 6-digit email OTP, profiles, tenant requirements, listings, swipe-to-match, mutual-match contact gate, realtime chat, report/block, account deletion, staff moderation queue, analytics opt-out, Sentry scaffold, CI secret and dependency scans.
- Slices A–D (17 Oct): home search, locality and house-rule filters, saved searches; owner listing wizard, dashboard, stats; profile hub and rent tools (receipts, split, deposit tracker, checklist) and help centre; OpenStreetMap maps, Firebase push (code), Razorpay payments (code), Digio e-stamp/KYC (code), packers and movers / home-services lead forms.
- E: Ahmedabad localities, profile photos (avatars bucket), full-screen swipe tab with no like/pass buttons.
- F: 27 licensed demo WebP photos, 3–6 photos per demo home, seed data with at least one listing per filter (an SQL assertion fails if a filter is empty).
- G: Material 3 range sliders for budget, rent, area, and floor.
- H: live-only Aadhaar and face verification through Digio production (`start-kyc` / `kyc-webhook`). No demo KYC. The screen says verification is coming soon until the `DIGIO_*` production secrets are set. Only the webhook can set verified, and only the last 4 digits are stored.
- I: Home hub as the first of five bottom tabs (Home, Explore, Swipe, Matches, Saved) with photo cards.
- J, the shared contract only: `profiles.primary_role` (`roommate`, `tenant`, `host`, `broker`) and `currentRoleProvider` in `lib/features/roles/role_provider.dart` (`28d35f4`). Migration `supabase/migrations/20261018120000_profiles_primary_role.sql`. Paste file `docs/staging_apply_J_1019.sql` is in the repo. The assistant's applied-SQL list does not include it.
- M: staging `qa+` fresh accounts (`4062114`). Branch `cursor/staging-fresh-tester-34e2` is this same commit and is an ancestor of `main`.

The owner's assistant reports draft PRs #1–#21 already fast-forwarded onto `main` and safe to close. The remote still has the old `cursor/*` branches; fast-forwarding `main` did not delete them.

## In progress

Three WIP branches. None of them contain `4062114`. Each merge-base with `main` is `28d35f40d4b9af8108a79e05738cc86aa01f7b93`. Rebase onto current `main` before merging. None are tested green here, none are deployed, and none are merged.

Recommended merge order: **J, then K, then L**. K and L both edit Home and Explore. L also edits the bottom nav (`lib/features/shell/home_shell.dart`). J, K, and L each add a `20261018` migration after the contract migration `20261018120000` that is already on `main`.

Timestamp order inside `supabase/migrations/` is not the same as that merge order. A fresh database applies filenames in order: J `20261018120100`, then L `20261018130000`, then K `20261018130100`, then M `20261019101900` (already on `main`). After a git merge of K before L, `supabase db reset` still runs L's file before K's file.

### J — `cursor/roles-onboarding-broker-da40`

`a9bf2866256a9633b55af0aa5d9855ce4b0f56b3` — "WIP: role picker, detailed requirements, host options, and broker flow." One commit on top of the contract. 33 files, +4335 / −366 versus the merge-base.

In the tree, unverified (no format, analyze, or test run on this commit):

- Four-card role picker (Roommate, Rental, Host, Broker), reachable after sign-in and from profile.
- Multi-step rental and roommate requirements (city and localities, budget slider, move-in, lease, BHK/room type, furnishing, parking, floor, lift, pets, food, smoking, drinking, gender and occupancy, profession, work and commute, guests, amenities, about-me, discoverable opt-in). Roommate steps add sleep, cleanliness, social style, work-from-home, cooking, languages, hobbies, and a flatmate note.
- Host screen with "See what seekers need" and "Post your property".
- Broker registration (name, agency, optional RERA, cities, localities, phone, years), Broker chip, brokerage terms on the listing wizard, and a matching-seekers screen.
- `docs/MATCHING.md` and `public.requirement_listing_match` / `public.seekers_for_my_listings` in `supabase/migrations/20261018120100_roles_requirements_brokers.sql`, plus a seed of 3 brokers and 17 seeker briefs (one opted out).
- Dart demo mirror of the score and an in-memory seeker list.

Missing on this branch:

- `docs/staging_apply_J_1019.sql` was not updated. `git grep 20261018120100` on the branch hits `docs/MATCHING.md` only, not the paste file. `test/docs/staging_apply_next_test.dart` was changed to expect that version inside the J paste file, so that test fails until the migration body is copied in.
- No pgTAP file for broker visibility or "nobody edits another person's requirement".
- No widget tests for the role picker, the new requirement steps, the host options, broker registration, or matching seekers. `test/widget/inventory_screens_test.dart` only loops Continue until Publish.
- No `flutter` format / analyze / full test run, no screenshots, no `homizi-web.zip`, not merged.

### K — `cursor/listing-match-cards-5454`

`5eccfa3456f35f531de566e61db385b3b7252af8` — "Record the listing-match seed in the staging apply check." Parent: `67561da` "Show listing match scores and redesign the home card." 25 files, +2409 / −253 versus the merge-base.

K's own report, checked against the diff:

Done on the branch:

- Local match scoring and a 0–100 badge with a breakdown on the card and the detail (`lib/features/discovery/domain/listing_match.dart`, `match_breakdown_sheet.dart`).
- `lib/features/discovery/listing_match_remote.dart` calls `requirement_listing_match` when that function exists.
- Home and Explore sorted by match, with "Best matches for you".
- Card redesign (photo carousel, verified badges, match chip, rent/deposit, BHK, amenities, owner/broker chip) in `listing_card.dart`.
- Recent searches and recent areas removed from Home; recents only in the focused search bar.
- Settings consolidated on the Profile settings page (`settings_screen.dart`).
- `supabase/migrations/20261018130100_listing_match_seed.sql` and `docs/staging_apply_K_1019.sql`. The staging test on this branch expects version `20261018130100` in the K file. **Not applied** to staging.

Not green. K's last run: **228 passed / 10 failed**. Failures K named: duplicate hero tags on Home/Explore; old finders still looking for card text `2 BHK`, `Furnished`, `About 6 km`, and the title; Andheri missing from the first match-sorted page; the staff settings test cannot find `open-moderation`.

Missing: a green suite, web zip, screenshots, merge to `main`. This handover did not re-run K's suite.

### L — `cursor/roommate-matching-nav-6945`

`8003710dd1994da9b902219c0b6330b06d7d25af` — "WIP: roommate match tab, compatibility SQL, and per-role nav." One commit. 26 files, +4244 / −150 versus the merge-base.

Done on the branch, unverified:

- `supabase/migrations/20261018130000_roommate_matching.sql` with `roommate_compatibility`, the breakdown, `list_roommate_seekers`, and a seed (L reports 22 seekers).
- Dart score mirror `lib/features/roommates/domain/roommate_compatibility.dart`.
- Roommates list and swipe, breakdown sheet, per-role bottom nav driven by `currentRoleProvider` (`lib/features/shell/role_nav.dart`, `home_shell.dart`).
- Saved heart on Home, Explore, and Profile. Seekers placeholder screen.
- `docs/MATCHING.md` (L's copy; J also adds a `docs/MATCHING.md`. They will conflict).
- `test/features/roommates/roommate_compatibility_test.dart`.

Missing, confirmed by the file list (`git diff --stat` does not contain them):

- `docs/staging_apply_L_1019.sql` is absent.
- `test/docs/staging_apply_next_test.dart` is unchanged on L, so every `20261018*` migration, including `20261018130000`, is still assigned to the J paste file.
- No RLS / pgTAP tests.
- No widget tests for the Roommates tab, the breakdown, or the role nav (`test/widget/home_hub_test.dart` is the only widget file in the diff).
- No `flutter analyze`, no full test run, no screenshots, no web zip, not merged.

## Not done / blocked on the owner

1. Digio production business account, then `DIGIO_CLIENT_ID`, `DIGIO_CLIENT_SECRET`, `DIGIO_KYC_TEMPLATE`, `DIGIO_WEBHOOK_SECRET`. See `docs/KYC_ESTAMP_SETUP.md`.
2. Razorpay merchant KYC and live keys. `docs/PAYMENTS_SETUP.md`. The code is in test mode.
3. Firebase project, then `FCM_SERVICE_ACCOUNT` and `PUSH_WEBHOOK_SECRET`. `docs/PUSH_SETUP.md`.
4. A Supabase access token so these Edge Functions can be deployed: `send-push`, `create-razorpay-order`, `razorpay-webhook`, `start-kyc`, `kyc-webhook`, `create-esign`, `esign-webhook`, `notify-service-lead`. Source is in the repo. None are deployed.
5. Gmail app password for custom SMTP, so OTP mail comes from HOMIZI instead of "Supabase Auth". `docs/EMAIL_OTP_SETUP.md`.
6. Android upload signing key and a Google Play Console account. Left until the end on purpose. `docs/release/SIGNING.md`.
7. Legal review of the draft privacy, terms, and deletion pages (`docs/legal/`).
8. A production Supabase project. Only staging exists.
9. Add the owner to `staff_roles` (admin) for the moderation queue.

## Next in pipeline

1. Finish and merge **J, then K, then L**. Rebase each onto `main` first (they all lack `4062114`). Run the full suite. Paste their staging SQL. Redeploy Netlify.
2. Redeploy Netlify from `main` so the `qa+` test logins work on the public site. The SQL is already applied; the web build is still `7b4d8b8`.
3. Close stale draft PRs #1–#21. Get CI running on `main`, including `supabase test db` and `supabase/tests/H17_kyc_live.sql`.
4. Deploy the Edge Functions once the access token and vendor keys exist. Then turn on push, payments, and KYC.
5. Custom SMTP, release signing key, a new APK/AAB, Play Console internal testing.
6. Keep the 70-task plan sheet updated: https://docs.google.com/spreadsheets/d/1nACdTKA0FSYgupqV6-ujzgFw_19wcQTUCLiRWZKR_sU/edit

## Known issues

- https://homizi.netlify.app is behind `main` by `28d35f4` and `4062114`.
- `docs/staging_apply_J_1019.sql` is in the repo and is not on the assistant's "already pasted" list. Pasting it is what adds `profiles.primary_role` on staging.
- J's WIP commit changes the staging-apply test to require `20261018120100` inside `docs/staging_apply_J_1019.sql` without adding that body.
- J and L both create `docs/MATCHING.md` with different contents.
- K and L both edit `lib/features/home/home_screen.dart` and `lib/features/discovery/explore_screen.dart`. L also replaces the bottom nav. Expect conflicts if they merge in an order other than J, then K, then L, and still expect conflicts on Home even in that order.
- K is red: 228 passed / 10 failed on K's last run (hero tags, card-text finders, Andheri off the first match page, `open-moderation`).
- L's migration sorts before K's (`20261018130000` then `20261018130100`) even when K is merged first.
- `README.md` still says the app does not talk to a hosted project and quotes Flutter 3.47.7. Staging is live, and CI pins 3.44.9.
- Identity verification stays on "coming soon" until Digio production secrets exist. Payments stay on the test gateway until a test key id (`rzp_test_…`) is supplied at build time, and live keys stay refused. Push does not register a device token until the Firebase dart-defines exist.

## Secrets policy

Do not put production secrets in git, in this handover, or in chat. `tool/secret_scan.dart` runs in CI.

Names only. Values stay in the Supabase dashboard, the vendor dashboards, or the owner's machine:

- Digio: `DIGIO_CLIENT_ID`, `DIGIO_CLIENT_SECRET`, `DIGIO_KYC_TEMPLATE`, `DIGIO_WEBHOOK_SECRET`, `DIGIO_TEMPLATE_DIGILOCKER`, `DIGIO_TEMPLATE_AADHAAR_OFFLINE`, `DIGIO_ENV`, `DIGIO_BASE_URL`
- Razorpay: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`
- Push: `FCM_SERVICE_ACCOUNT`, `PUSH_WEBHOOK_SECRET`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_VAPID_KEY`
- Observability: `SENTRY_DSN`
- Mail: Gmail app password / custom SMTP password; `RESEND_API_KEY` (named in `docs/ENV.md`, not set)
- Supabase: service role key, secret key, database password, and the access token used to deploy Edge Functions
- Staging mailbox: `STAGING_TEST_PASSWORD` (committed for the staging build only; production drops it). Testers type `000000`. The password string is intentionally not copied here.
- Maps: `OSM_TILE_URL`, `OSM_USER_AGENT`

`config/staging.json` may contain the public project URL, the publishable client key, and `STAGING_TEST_PASSWORD`. It must not contain a service role key or a database password. Local `config/env.dev.json` is gitignored; copy it from `config/env.dev.json.example`.
