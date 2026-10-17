# Security audit 17 October 2026

Scope: gates S-01 through S-11 in the execution plan, checked against commit `9914e7d` (`9914e7d3829156473318cd6cbb1ad42dedaa81e1`) and the Mumbai staging project described in `docs/STAGING_SETUP.md`.

This audit does not clear the app for Play. No critical vulnerability was confirmed in the scans below. Several launch gates stay open because their tests were not executed or their owner decisions are still deferred.

The threat model is [THREAT_MODEL.md](THREAT_MODEL.md). The halt procedure is [../ops/INCIDENT_ROLLBACK_RUNBOOK.md](../ops/INCIDENT_ROLLBACK_RUNBOOK.md). The moderation process is [../ops/MODERATION_SOP.md](../ops/MODERATION_SOP.md).

## Commands that ran

Working directory `/workspace`. Flutter SDK 3.47.7 (Dart 3.13.5) at `/tmp/flutter`, framework revision `abaf9c5237`.

| Command | Result |
| --- | --- |
| `dart run tool/secret_scan.dart` | `secret scan passed` (exit 0) |
| `dart run tool/dependency_scan.dart` | `dependency scan passed (113 locked hosted packages)` (exit 0) |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 182 files (0 changed)` (exit 0) |
| `flutter analyze` | `No issues found! (ran in 14.1s)` (exit 0) |
| `flutter test --reporter compact` | `All tests passed!` at 00:34, 140 tests (exit 0) |
| `flutter doctor -v` | Flutter and Chrome ok. Android SDK not found. Linux desktop toolchain incomplete. |
| `git --version` | `git version 2.43.0` |
| OSV `https://api.osv.dev/v1/querybatch` for every locked Pub package | 113 queries, 0 advisories returned |

A Python walk of the same secret rules as `lib/core/security/secret_rules.dart` (private keys, `sk_live_` / `rk_live_`, `AKIA` access keys, JWTs, assigned `service_role_key` / `secret_key`) scanned 295 files and reported 0 hits. The Dart tool skips `lib/core/security/secret_rules.dart` and `test/core/security/secret_rules_test.dart` because those files contain the patterns on purpose.

`tool/dependency_scan.dart` checks that `pubspec.lock` has no git or path sources. It does not call a vulnerability feed. The OSV query is the advisory check added for this audit. Zero OSV rows means those versions had no matching Pub advisory in OSV on this date. It does not prove every package is free of unpublished issues. `flutter pub get` reported 17 newer versions that the current constraints refuse. That is currency, not a CVE.

## Database tests

Docker is not installed (`docker` is absent, `/var/run/docker.sock` is absent). `supabase test db` was not run. The suite on disk is:

| File | What it asserts |
| --- | --- |
| `supabase/tests/01_rls_negative.sql` | Cross-user contact and address denial, draft hidden, client cannot set verification |
| `supabase/tests/02_interest_match_contact.sql` | Idempotent likes, one match, consent, stranger denial, block |
| `supabase/tests/03_profile_session.sql` | Both roles, mock verification stops at `mock_pending` |
| `supabase/tests/04_listings_requirements.sql` | Publish rules, status not client-writable |
| `supabase/tests/05_listing_photo_storage.sql` | Private bucket, 5 MB, jpeg, owner path |
| `supabase/tests/06_chat_visits.sql` | Phone and email refused in messages and visits |
| `supabase/tests/07_notifications.sql` | Payload is ids only |
| `supabase/tests/08_safety_deletion.sql` | Report text, blocks, `delete_own_account` |
| `supabase/tests/09_score_compatibility.sql` | Weights, no religion in the payload |
| `supabase/tests/10_realtime_moderation_analytics.sql` | Members cannot staff-act; staff can |

CI (`.github/workflows/ci.yml`) runs `supabase test db` after `supabase db reset`. This audit did not see a CI log, so those jobs are configured, not re-proven here.

## Staging probes (17 October 2026)

No service-role key was used. The client key is the publishable key already in `config/staging.json`.

| Call | Result |
| --- | --- |
| `GET https://homizi.netlify.app` | HTTP 200, HTML title HOMIZI, server Netlify |
| `GET /auth/v1/health` on `loraalfiuklespaldotd` | GoTrue v2.197.0 |
| `GET /rest/v1/properties` as the publishable key | `42501` permission denied for table properties |
| `GET /rest/v1/private_contacts` | `42501` |
| `GET /rest/v1/messages` | `42501` |
| `GET /rest/v1/analytics_events` | `42501` |
| `POST /rest/v1/rpc/publish_listing` with a nil id | `42501` permission denied for function |
| `POST /rest/v1/rpc/get_contact_visibility` | `42501` |
| `POST /rest/v1/rpc/send_message` | `42501` |
| `POST /rest/v1/rpc/score_compatibility` with the PD-06 arguments | `42501` |
| `POST /rest/v1/rpc/delete_own_account` | `42501` |
| `POST /rest/v1/rpc/ensure_own_account` | `42501` |
| `POST /rest/v1/rpc/staff_list_reports` | `42501` |
| `GET /storage/v1/bucket/listing-photos` | `404` `NoSuchBucket` |

`42501` means the table or function is on the hosted database and `anon` cannot use it. The storage 404 is ambiguous: a private bucket is hidden from a caller who cannot see it.

## Gate by gate

### S-01 Secrets — Done

The Dart secret scan passed. `.gitignore` ignores `.env`, `.env.*`, and `config/local*.json`, and ignores `supabase/.temp/`. `AppConfig.parse` throws if the client key is an `sb_secret_` key or contains `service_role`. Test: `staging file is the public Mumbai client and not a secret`. Release signing still uses the debug keystore, and that keystore is not committed. The debug key is not a production upload key (see S-11 and the release plan).

### S-02 Authorization — In progress

Negative tests are written (`01_rls_negative.sql` and the later files). Staging anonymous reads and the security functions returned `42501`. The pgTAP suite did not run. Cross-user cases with two signed-in sessions were not replayed against Mumbai. This gate is not closed.

### S-03 Contact privacy — In progress

Client tests passed: `a stranger never receives contact fields`, `a match without consent returns no contact fields`, `a hidden visibility payload cannot leak a phone or email`, `listing detail does not render contact details`, `contact text matches the server check and stays out of visit slots`. `get_contact_visibility` exists on staging and is denied to anonymous clients. The SQL leakage script `02_interest_match_contact.sql` was not executed. UI hiding is not treated as the control.

### S-04 Identity data — Done for the current deferral

No Aadhaar column and no face capture. Mock verification stops at `mock_pending`. The owner has deferred a real provider (D-04). Collecting real identity data stays blocked until that review exists.

### S-05 Uploads — In progress

Client tests passed: owner path, pending moderation, oversized and unsupported files refused (`photo_upload_test.dart`, `photo_manager_screen_test.dart`). SQL file `05_listing_photo_storage.sql` was not executed. The hosted bucket was not confirmed (storage 404 above).

### S-06 Account deletion — In progress

`delete_own_account` is on staging and denied to anonymous clients. `08_safety_deletion.sql` expects deletion of the auth user and the private contact row, and expects the other account to remain. That script was not executed. The function deletes listing-photo objects on the connected database. It does not call a payment, identity, analytics, or backup vendor. Those vendors are not connected. Legal retention text is still a draft.

### S-07 Moderation — In progress

Reports and blocks are implemented and the client tests passed (`safety_rules_test.dart`, `moderation_screen_test.dart`). The interim moderator is deep ([../ops/MODERATION_SOP.md](../ops/MODERATION_SOP.md)). `staff_roles` has no row, so the owner cannot open the queue yet. `10_realtime_moderation_analytics.sql` was not executed.

### S-08 Payments — Blocked

Payments are deferred (D-06). There is no webhook and no checkout. Clients cannot write `payments` or `subscriptions`. The gate's webhook tests do not exist because the feature is deferred. Do not treat an empty table as a passed payment review.

### S-09 Backups — Blocked

No production project and no restore rehearsal. Staging must not be wiped with `supabase db reset`.

### S-10 Store declarations — Review required

`docs/legal/PRIVACY.md` and `docs/legal/TERMS.md` are marked draft for legal review. `legal_draft_test.dart` passed and keeps that mark. `docs/STORE_LISTING.md` is not a submission. No Data safety form has been filled from the shipped SDK list. Sentry is a dependency and stays off without `SENTRY_DSN`.

### S-11 Release rollback — Done as a document

[../ops/INCIDENT_ROLLBACK_RUNBOOK.md](../ops/INCIDENT_ROLLBACK_RUNBOOK.md) says how to stay on demo mode, stop Firebase uploads by removing secrets, halt a future Play rollout, and ship a forward migration. There is no production rollout to halt today. The runbook has not been rehearsed in Play Console.

## Findings

| ID | Severity | Finding |
| --- | --- | --- |
| F-1 | High before launch | The row-level security suite was not executed in this audit. S-02 and S-03 stay open until `supabase test db` passes. |
| F-2 | High before launch | `android/app/build.gradle.kts` signs release builds with the debug key. An upload key is still required, and it must stay out of git. |
| F-3 | High before launch | No production backup or tested restore (S-09). |
| F-4 | Medium | Interim moderator is named and is not in `staff_roles`, so reports cannot be triaged in the app. |
| F-5 | Medium | Privacy, terms, and Data safety are drafts (S-10). |
| F-6 | Low | Hosted `listing-photos` was not proven. The anonymous storage call returned 404. |
| F-7 | Info | Secret scan, lockfile source check, and OSV batch returned clean on this date. |

No finding here is a confirmed live data leak. The anonymous staging denials are evidence the core grants are applied. They are not a substitute for the two-user negative tests.
