# HOMIZI status on 17 October 2026

Audit of the owner's execution workbook against `main` at `9914e7d` (`9914e7d3829156473318cd6cbb1ad42dedaa81e1`, 16 October 2026, "Show seed homes and save tenant preferences"). The workbook had initialized every pipeline row as Not started. Statuses below replace that with evidence from the tree and from commands run in this audit.

The updated workbook is [homizi-execution-plan.xlsx](homizi-execution-plan.xlsx). Decisions are in [../DECISIONS.md](../DECISIONS.md). The security write-up is [../security/AUDIT_1017.md](../security/AUDIT_1017.md).

## How a status was chosen

| Status | Meaning in this audit |
| --- | --- |
| Done | The definition of done is met by a file, a commit, a named test that passed, or a command output captured on 17 October 2026. |
| In progress | Part of the work is in the repo or on staging, and the definition of done is still open. |
| Blocked | An owner account, a deferred decision, or a missing external system stops the rest. |
| Review required | A person still has to approve the artifact (legal, security sign-off, or an owner decision). |
| Not started | No artifact toward that task was found. |

Parallel work on listings, account lifecycle, and legal pages was left untouched. This audit does not claim those branches.

## Commands

| Check | Output |
| --- | --- |
| `flutter --version` | Flutter 3.47.7, Dart 3.13.5, framework `abaf9c5237` |
| `git --version` | git version 2.43.0 |
| `dart format --set-exit-if-changed .` | 182 files, 0 changed, exit 0 |
| `flutter analyze` | No issues found (14.1s), exit 0 |
| `flutter test` | All tests passed, 140 tests, about 34s, exit 0 |
| `dart run tool/secret_scan.dart` | `secret scan passed`, exit 0 |
| `dart run tool/dependency_scan.dart` | `dependency scan passed (113 locked hosted packages)`, exit 0 |
| OSV querybatch | 113 locked Pub packages, 0 advisories |
| `flutter doctor -v` | Android SDK missing on this machine. Chrome and the Flutter SDK are fine. |
| `supabase test db` | Not run. Docker is not installed and `/var/run/docker.sock` is absent. |

Flutter's own Gradle defaults in that SDK set `compileSdkVersionInt = 36` and `targetSdkVersion = '36'`. The app uses those defaults. `minSdk` in `android/app/build.gradle.kts` is 26.

## Hosted staging

Checked 17 October 2026 with the publishable key in `config/staging.json`. No service-role key was used.

- https://homizi.netlify.app returned HTTP 200, title HOMIZI, server Netlify (commit `3a6afe6`, `netlify.toml`).
- Auth health on `loraalfiuklespaldotd` returned GoTrue v2.197.0.
- Anonymous reads of `properties`, `private_contacts`, `messages`, and `analytics_events` returned `42501`.
- Anonymous calls to `publish_listing`, `get_contact_visibility`, `send_message`, `score_compatibility`, `delete_own_account`, `ensure_own_account`, and `staff_list_reports` returned `42501`.
- `GET /storage/v1/bucket/listing-photos` returned `404 NoSuchBucket`. That does not prove the private bucket is missing.

## Counts

### Remaining pipeline (R-001 to R-070)

| Status | Count |
| --- | --- |
| Done | 26 |
| In progress | 27 |
| Blocked | 8 |
| Review required | 3 |
| Not started | 6 |
| Total | 70 |

### Execution pipeline (E-001 to E-038)

| Status | Count |
| --- | --- |
| Done | 11 |
| In progress | 15 |
| Blocked | 6 |
| Review required | 2 |
| Not started | 4 |
| Total | 38 |

### Play checklist (R-01 to R-11)

Done 0, In progress 4, Blocked 2, Review required 1, Not started 4.

### Security gates (S-01 to S-11)

Done 3 (S-01, S-04, S-11), In progress 5, Blocked 2 (S-08, S-09), Review required 1 (S-10), Not started 0.

### Decisions (D-01 to D-10)

Approved: D-01, D-02, D-03, D-05, D-07. Deferred: D-04, D-06. Interim: D-10 (owner deep). Pending: D-08, D-09.

## Top blockers

1. Nobody has recorded a run on a physical Android phone, so the first install milestone (R-020, E-006) is blocked on the owner's device.
2. This audit machine has no Android SDK, so it did not launch an emulator and did not build an APK. CI is configured to build `app-debug.apk`. There is no saved emulator screenshot or API-level log in the repo (R-019).
3. The database policy suite was not executed. Docker is missing. Anonymous denials on Mumbai are real, and they are not the two-user negative tests (S-02, R-027, R-050).
4. Firebase App Distribution has no `FIREBASE_APP_ID` or `FIREBASE_TOKEN`. The workflow skips and publishes nothing (R-054, R-055).
5. Play Console, the upload key, and store submission are deferred to the end. The Play account type is unknown, which also blocks the 12-tester / 14-day rule (D-09, R-057, R-063, R-065).
6. Production Supabase, its region, backups, real identity checks, payments, and push stay deferred (D-04, D-06, D-08, S-08, S-09).
7. Privacy and terms are drafts waiting on legal review (R-059, S-10).
8. Deep is the interim moderator on paper. `staff_roles` has no row, so the queue cannot be opened until that id is inserted from the SQL editor (S-07).

## Remaining pipeline

| ID | Status | Evidence |
| --- | --- | --- |
| R-001 | Done | `docs/PRODUCT_SPEC.md` (`dc65c8e`) has the MVP slice and the deferred list. Owner decisions: root `DECISIONS.md` and `docs/DECISIONS.md`. |
| R-002 | Review required | Catalog cities are Bengaluru, Pune, Mumbai, Hyderabad, and Delhi NCR. Languages are English and Hindi (`lib/l10n`). No dated decision names one pilot city, support hours, and an operating owner. |
| R-003 | Done | PD-02. `lib/features/roles/role_selection_screen.dart`. SQL label `one account can record both roles` in `03_profile_session.sql`. Broker, company, and flatmate are not account roles. Staff is `staff_roles`. |
| R-004 | Done | PD-04 and PD-08. `lib/features/safety/domain/contact_visibility_policy.dart`. Tests named under R-044 passed on the client. |
| R-005 | Done | Chat, visits, and in-app notices are in `docs/PRODUCT_SPEC.md`. Payments, real ID, and push are deferred in `docs/DECISIONS.md`. |
| R-006 | In progress | Behaviors are in `docs/PRODUCT_SPEC.md` and the passing Flutter tests. There is no single signed acceptance checklist, and other agents are still changing product flows. |
| R-007 | Done | `flutter --version` printed Flutter 3.47.7. CI pins the same version in `.github/workflows/ci.yml`. |
| R-008 | In progress | CI uses `android-actions/setup-android@v3` and Java 17. `flutter doctor` on this machine: Android SDK not found. |
| R-009 | Done | `git version 2.43.0`. Remote `main` at `9914e7d`. |
| R-010 | In progress | Doctor report is in the audit. Android toolchain is the remaining blocker on this machine. iOS toolchain was not expected on Linux. |
| R-011 | Done | Repository exists and this clone tracks `origin/main`. Branch protection was not inspected. |
| R-012 | Done | `docs/PRODUCT_SPEC.md`, `TECH_STACK.md`, `DATA_MODEL.md`, `SECURITY_AND_PRIVACY.md`, `RELEASE_PLAN.md`, and `docs/DECISIONS.md`. |
| R-013 | In progress | `android/` and `ios/` exist. Application id `in.homizi.app` (`3f096e4`). No emulator launch was recorded, and this machine has no Android SDK. |
| R-014 | Done | `.gitignore`, `config/env.*.json.example`, secret scan passed. `app_config_test.dart`: empty Supabase values stay in demo mode. |
| R-015 | Done | `docs/TECH_STACK.md`: Riverpod and go_router. `pubspec.yaml` pins `flutter_riverpod` and `go_router`. |
| R-016 | Done | `lib/features/` and `lib/core/`. README describes the architecture. |
| R-017 | Done | `analysis_options.yaml`. Format exit 0. `flutter analyze`: no issues. |
| R-018 | Done | `flutter test`: 140 passed. CI runs `flutter test`. |
| R-019 | Not started | No emulator screenshot, device name, or API-level log is in the repo. |
| R-020 | Blocked | Needs the owner's Android phone. No device id or screenshot. |
| R-021 | In progress | CI and `distribute.yml` name `build/app/outputs/flutter-apk/app-debug.apk`. This audit did not build it (no Android SDK). No phone install is recorded. |
| R-022 | In progress | Supabase is approved (D-02). Mumbai staging is live. Production region is D-08 and is still pending. |
| R-023 | Done | Staging project responds. Production is explicitly a different, deferred project (`docs/STAGING_SETUP.md`). |
| R-024 | Done | Secret scan passed. Service-role client keys are refused in `lib/core/config/app_config.dart`. |
| R-025 | Done | `docs/DATA_MODEL.md` and `supabase/migrations/20261011120000_homizi_schema.sql` (`455837e`) plus later migrations. |
| R-026 | In progress | Migrations, `supabase/seed.sql`, and `docs/staging_seed.sql` exist. A clean `supabase db reset` was not run here. Staging already has the functions probed above. |
| R-027 | In progress | Policy SQL and `supabase/tests/01_rls_negative.sql` exist. Suite not executed. Staging anon denials are partial evidence. |
| R-028 | In progress | Bucket policies in `20261011120100_homizi_access.sql` and `05_listing_photo_storage.sql`. Client upload tests passed. Hosted bucket not confirmed. |
| R-029 | Done | PD-01, 14 October 2026. `test/core/theme/contrast_test.dart` passed. |
| R-030 | Done | Empty, loading, and error states: `shell_screens_test.dart` passed. Brand: `brand_theme_test.dart` passed. |
| R-031 | Done | `session_redirect_test.dart` passed (welcome, login guard, role leaves auth screens). |
| R-032 | In progress | Email OTP is documented in `docs/EMAIL_OTP_SETUP.md`. GoTrue health succeeded. This audit did not send or enter a real email code. SMS is off. |
| R-033 | In progress | `session_controller_test.dart` passed, including prod refusal of the development code and the staging email path. A live expired OTP was not sent to GoTrue. |
| R-034 | Done | `profile_records_test.dart` and `tenant_profile_test.dart` passed. Mock verification only. |
| R-035 | Done | Deferred on purpose (D-04). Written deferral is the decision. No provider is selected. |
| R-036 | Done | `requirement_draft_test.dart` passed (inverted budget, past move-in, complete requirement). |
| R-037 | Done | Listing wizard. `inventory_screens_test.dart`: `the listing wizard blocks a short title` passed. |
| R-038 | In progress | `photo_upload_test.dart` passed (owner path, type and size refusal, pending moderation). SQL storage tests were not run. |
| R-039 | In progress | `publish_listing` exists on staging and is denied to anon. `04_listings_requirements.sql` was not executed. Demo publish does not claim the server accepted the listing (`inventory_screens_test.dart`). |
| R-040 | In progress | `feed_page_test.dart`, `listing_filters_test.dart`, and shell loading/empty/error tests passed. The definition of done asks for a device, and no phone run is recorded. |
| R-041 | In progress | `listing detail does not render contact details` and `public listing JSON has no contact or street address` passed. Server negative tests were not run. |
| R-042 | Done | PD-06. `supabase/migrations/20261014170000_score_compatibility.sql` (`768dca8`). `compatibility_test.dart` passed (`a matching home scores 100`). Staging function exists and anon is denied. |
| R-043 | In progress | `create_interest` is idempotent, rate-limits 200 actions an hour, and checks blocks (`20261011120100_homizi_access.sql`). Pass does not delete `matches`. Client test `a pass leaves the match` passed. `02_interest_match_contact.sql` was not executed. |
| R-044 | In progress | Client contact tests passed (see S-03). SQL leakage file not executed. Critical gate stays open until that run. |
| R-045 | In progress | Report and block client tests passed. SOP names deep. `staff_roles` is empty. SQL file `08` and `10` were not executed. |
| R-046 | In progress | Chat and visits are in the product. `chat_rules_test.dart` and `chat_screen_test.dart` passed. `06_chat_visits.sql` was not executed. |
| R-047 | In progress | In-app inbox tests passed (`inbox_notice_test.dart`, `notifications_screen_test.dart`). Push is deferred (`docs/PUSH.md`). No Android push test. |
| R-048 | Done | Deferral is the decision (D-06). No checkout. |
| R-049 | Done | `flutter test` passed: domain, validation, scoring, routes, and main UI states. |
| R-050 | In progress | `supabase/tests/*.sql` and the CI database job exist. `supabase test db` did not run. |
| R-051 | In progress | Contrast tests and `help and settings stay usable with larger text` passed. No screen-reader pass and no signed accessibility review. |
| R-052 | Blocked | Needs a physical phone. No regression log. |
| R-053 | Review required | [../security/AUDIT_1017.md](../security/AUDIT_1017.md). Open high-before-launch items: unrun RLS suite, debug signing, no production backup. |
| R-054 | Blocked | `distribute.yml` skips until Firebase secrets exist. No Firebase app was found in the repo. |
| R-055 | Blocked | Depends on R-054 and a phone install. |
| R-056 | In progress | Local format, analyze, test, and scans passed. CI workflow exists (`4ac55e7` and later edits). No Actions run URL was available here. Distribution link does not exist. |
| R-057 | Blocked | Play Console is deferred to the end. No account evidence. |
| R-058 | In progress | Package id is set (D-07). Release `signingConfig` is the debug config in `android/app/build.gradle.kts`. |
| R-059 | Review required | `docs/legal/PRIVACY.md` and `TERMS.md` say draft for legal review. `legal_draft_test.dart` passed. No stable policy URL. Legal pages were not edited in this pass. |
| R-060 | In progress | `docs/STORE_LISTING.md` is a draft. No screenshots, content rating, or Data safety form. |
| R-061 | Not started | No signed AAB. Version `1.0.0+1`. |
| R-062 | Not started | No Play internal track. |
| R-063 | Blocked | Account type unknown. The 14-day tester wait cannot be done in git. |
| R-064 | Not started | No go/no-go signature. |
| R-065 | Blocked | Store submission is deferred. |
| R-066 | In progress | Sentry stays off without `SENTRY_DSN` (`error_reporting_test.dart` passed). Runbook: `docs/ops/INCIDENT_ROLLBACK_RUNBOOK.md`. No live crash alerts. |
| R-067 | Not started | No public launch. |
| R-068 | In progress | `ios/` and `.github/workflows/ios.yml` (`workflow_dispatch`, `flutter build ios --no-codesign`). No successful macOS run is recorded. |
| R-069 | Blocked | Needs an Apple Developer account and signing. TestFlight has not started. |
| R-070 | Not started | No App Store submission. |

## Execution pipeline

| ID | Status | Evidence |
| --- | --- | --- |
| E-001 | Done | Same evidence as R-001. |
| E-002 | In progress | Git and Flutter 3.47.7 work here. Android SDK does not. |
| E-003 | Done | Repository and `.gitignore`. Secret scan passed. |
| E-004 | In progress | Flutter project with Android and iOS. Emulator launch not recorded. |
| E-005 | Done | Feature folders, Riverpod, go_router, format, analyze, and the first tests through the full 140. |
| E-006 | Blocked | Physical phone. |
| E-007 | Done | D-02 recorded in `docs/DECISIONS.md` with the owner and the date. |
| E-008 | Done | Staging reachable. Secrets pattern in R-014 and R-024. |
| E-009 | In progress | Migrations are versioned. Clean replay not run (no Docker). |
| E-010 | In progress | Negative SQL tests exist and were not executed. |
| E-011 | Done | PD-01 and passing contrast and brand widget tests. |
| E-012 | In progress | Same as R-032 and R-033. |
| E-013 | Done | Profile widget and record tests passed. Mock verification only. |
| E-014 | Done | `requirement_draft_test.dart` passed. |
| E-015 | Done | Listing wizard validation test passed. |
| E-016 | In progress | Client photo tests passed. Server storage tests did not run. |
| E-017 | In progress | Same as R-039. |
| E-018 | In progress | Feed tests passed. Not verified on a phone. |
| E-019 | Done | Same as R-042. |
| E-020 | In progress | Same as R-043. |
| E-021 | In progress | Policy is approved. Unauthorized SQL cases were not re-run. |
| E-022 | In progress | Same as R-045. |
| E-023 | In progress | Chat, visits, and in-app notices are implemented. SQL integration tests were not run. Push is deferred. |
| E-024 | Done | Written deferral. No checkout. |
| E-025 | In progress | Flutter suite green. Database suite and a CI URL were not captured. |
| E-026 | Blocked | Physical device regression. |
| E-027 | Review required | This audit. Open items in `docs/security/AUDIT_1017.md`. |
| E-028 | Blocked | Firebase project secrets absent. |
| E-029 | In progress | `distribute.yml` builds and uploads only when secrets exist, and skips otherwise (commit `17d237f`). |
| E-030 | Blocked | Play Console account. |
| E-031 | Not started | No signed AAB. |
| E-032 | Review required | Draft listing and legal text. Declarations not filed. |
| E-033 | Not started | No internal Play install. |
| E-034 | Blocked | Account-specific closed test. |
| E-035 | Not started | No written go/no-go. |
| E-036 | Blocked | Submission deferred. |
| E-037 | Not started | No launch to monitor. |
| E-038 | In progress | iOS project and unsigned macOS workflow. No TestFlight build. |

## Play checklist

| ID | Status | Evidence |
| --- | --- | --- |
| R-01 | Blocked | No Play Console account in the repo. Deferred to the end. |
| R-02 | In progress | Id `in.homizi.app` is set. Upload key is not. Release uses the debug signing config. |
| R-03 | In progress | Flutter 3.47.7 defaults target and compile SDK to 36. Not verified on a built app bundle. Recheck at submission. |
| R-04 | Not started | No `flutter build appbundle` artifact. |
| R-05 | In progress | `docs/STORE_LISTING.md` draft only. |
| R-06 | Review required | Legal drafts. `legal_draft_test.dart` passed. |
| R-07 | Not started | No testing track. |
| R-08 | Not started | No physical-device QA log. |
| R-09 | Not started | No owner sign-off on an artifact. |
| R-10 | Blocked | Submission deferred. |
| R-11 | In progress | Runbook written. Crash monitoring is off without a DSN. |

## Security gates

| ID | Status | Evidence |
| --- | --- | --- |
| S-01 | Done | Secret scan passed. See `docs/security/AUDIT_1017.md`. |
| S-02 | In progress | Tests written. Suite not run. Staging anon `42501`. |
| S-03 | In progress | Client tests passed. SQL leakage file not run. |
| S-04 | Done | Deferral holds. No Aadhaar column. Mock only. |
| S-05 | In progress | Client upload tests passed. SQL and hosted bucket not confirmed. |
| S-06 | In progress | Function present on staging. End-to-end deletion test not run. |
| S-07 | In progress | SOP names deep. `staff_roles` empty. |
| S-08 | Blocked | Payments deferred. No webhooks. |
| S-09 | Blocked | No production backup test. |
| S-10 | Review required | Drafts. Legal review open. |
| S-11 | Done | `docs/ops/INCIDENT_ROLLBACK_RUNBOOK.md`. No production rollout exists to halt. |
