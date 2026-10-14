# Plan diff

The workbook was publicly readable. It was downloaded on 14 October 2026 from `https://docs.google.com/spreadsheets/d/1EUUmIiVkrz8ZTsjiLdGWlOWxN43_LpabrA4uRTHZlrc/export?format=xlsx` and saved as [homizi-execution-plan.xlsx](homizi-execution-plan.xlsx).

The sheet is an execution plan for a project that does not exist yet. Its dashboard counts 38 steps, with Done, Blocked, and Review required all at 0. This repository already has the MVP. The comparison below is against the code and [DECISIONS.md](../../DECISIONS.md), not against the sheet’s “Not started” column.

The sheet does not replace owner decisions that are already approved. Where a row still says Proposed or Not selected, that is the sheet being behind the 12 October and 14 October decisions.

## What the new plan changes

The workbook adds a release path the repo did not track as a checklist: USB install, Firebase App Distribution, Play internal testing, a closed test of 12 testers for 14 days for applicable new personal Play accounts, target API 36, and a separate iOS/TestFlight track. It also asks for specification documents (`PRODUCT_SPEC`, `TECH_STACK`, `DATA_MODEL`, `SECURITY_AND_PRIVACY`, `RELEASE_PLAN`) and a server-side compatibility score.

It does not add a new product feature such as payments, real identity verification, or a new city. It marks chat, visits, and notifications as optional (E-023). Those flows are already built and stay. It marks payments as deferred (E-024, D-06), which matches the still-blocked payments row.

## Conflicts with approved decisions

| Sheet | Sheet status | Already decided |
| --- | --- | --- |
| D-01 Framework, Flutter | Proposed | The app is Flutter. Not reopened. |
| D-02 Backend, Supabase | Proposed, not approved | Local schema, RLS, and demo mode exist. Production project, region, and secrets stay blocked. |
| D-03 Android-first MVP | Proposed | The client is Android-first and keeps an iOS project. |
| D-05 Contact privacy | Not selected | PD-04 is approved. Contact is shared per match and returned only by `get_contact_visibility`. |
| D-07 Package id | Pending | PD-07 is approved: `in.homizi.app`, Android namespace `app.homizi`. |
| E-021 “stop until policy is approved” | Not started | The approved contact copy is already in the app. |

D-04 verification, D-06 payments, D-08 region, D-09 store account type, and D-10 moderation match the still-blocked table. They stay blocked.

## Already in this build

| Step | Evidence |
| --- | --- |
| E-003 repo | This Git repository. No service-role key is committed. |
| E-004, E-005 app and quality | Feature folders, Riverpod, go_router, `flutter analyze`, `flutter test`, debug APK in CI. |
| E-009 schema | `supabase/migrations/`. |
| E-010 authorization | `supabase/tests/01_rls_negative.sql` and the contact tests. |
| E-011 design system | `HomiziTheme`, listing cards, empty, loading, and error states. PD-01 colors. |
| E-012 auth | Demo code `000000` only when `allowsDevOtp`. Supabase auth when a URL and public key are set. |
| E-013 profiles | Tenant and host profiles. Verification calls `request_mock_verification` only. |
| E-014 requirements | Requirement wizard, draft validation, `publish_requirement`. |
| E-015 listings | Listing wizard and preview. Cards show locality and city, not a street address. |
| E-016 photos | Minimum of 3, move up and down, primary slot, remove, JPEG/PNG/WebP and size checks, private `listing-photos` bucket. |
| E-017 publish | `publish_listing` rejects an incomplete listing. The client cannot set `status`. |
| E-018 feed | Explore, Discover, filters, rent sort, empty, loading, and error. Private contact columns are not selected. |
| E-020 interest and match | `create_interest` is idempotent, rate-limits 200 actions an hour, and checks blocks. A pass does not unmatch (PD-03). |
| E-021 contact gate | Hidden until match and consent. PD-04. |
| E-022 report and block | Reports are stored and cannot contain a phone or an email. Blocks hide contact. Nobody is assigned to review the queue. |
| E-023 chat, visits, inbox | Match-gated chat refuses a phone or an email. A visit is one to three times. In-app notices. Push delivery is not connected. |
| E-024 payments | `payments` and `subscriptions` exist. Clients cannot write them. No checkout screen. |
| E-025 CI | `.github/workflows/ci.yml` runs format, analyze, tests, secret scan, dependency scan, debug APK, and database tests. |
| R-03 target API | Flutter 3.44.6 and 3.47.7 both default `targetSdk` and `compileSdk` to 36. The app uses those defaults. |
| iOS project | `ios/` plus `.github/workflows/ios.yml` (`workflow_dispatch` on macOS). |

## New or changed, and built from this plan

These did not need a Play account, a Firebase project, a payment provider, a lawyer’s sign-off, or a real identity check.

| Item | Change |
| --- | --- |
| Specification set | [PRODUCT_SPEC.md](../PRODUCT_SPEC.md), [TECH_STACK.md](../TECH_STACK.md), [DATA_MODEL.md](../DATA_MODEL.md), [SECURITY_AND_PRIVACY.md](../SECURITY_AND_PRIVACY.md), [RELEASE_PLAN.md](../RELEASE_PLAN.md). They describe this build. They are not a new owner approval. |
| E-018 pagination | Explore shows eight homes at a time and a “Show more homes” control. Search still runs on the full filtered list, then the window is applied. |
| E-019 server score | `public.score_compatibility` uses the PD-06 weights. It does not take gender, religion, caste, age, or marital status. Demo mode still scores on the phone with the same rules. |
| L-04 / E-029 safe skip | `.github/workflows/distribute.yml` builds and uploads a debug APK only when `FIREBASE_APP_ID` and `FIREBASE_TOKEN` are set. Otherwise it records a skip and does not publish. |
| S-11 runbook | [ROLLBACK.md](../ROLLBACK.md) says what can be halted today and what still needs the owner. |

## Removed

The sheet removes nothing that is already shipped. Chat, visits, and in-app notifications stay even though E-023 calls them optional. No approved decision in DECISIONS.md was withdrawn.

## Still blocked

| Item | Why it stays blocked |
| --- | --- |
| E-001 signed product brief | The spec files describe the build. Approving a new brief is an owner action. |
| E-002, E-006, E-026 phone install and device regression | Needs the owner’s Android phone. |
| E-007, E-008, D-02, D-08 hosted backend | Needs an approved project, region, and secrets. |
| E-012 real OTP | Needs a provider. The development code is not an SMS integration. |
| E-013, D-04, S-04 real identity | Needs a provider, a lawful basis, and a privacy review. |
| E-022, D-10, S-07 staffed moderation | Reports are stored. No one is named to review them. |
| E-024, D-06, S-08 payments | Finance and store-policy approval. No checkout was added. |
| E-027 formal audit | Scans and policy tests exist. A reviewer has not signed an audit. |
| E-028, L-03 Firebase project | Needs the owner’s Firebase app. The workflow skips until secrets exist. |
| E-030, D-09, R-01 Play Console account | Owner account, and whether it is personal or an organization. |
| E-031, R-02, R-04 signed release AAB | Release builds are still debug-signed. Upload keys must not be committed. |
| E-032, R-05, R-06, S-10 store listing and data safety | Draft copy exists. Legal review and a real privacy URL are not done. |
| E-033 to E-036, R-07 to R-10, L-07, L-08 | Internal, closed, and production Play tracks need the owner and Google’s review. The 12-tester / 14-day rule is account-specific and cannot be completed here. |
| E-037 monitoring | Needs an operations owner. |
| E-038, L-09 TestFlight | Needs a Mac, signing, and an Apple Developer account. |
| S-06 deletion beyond this database | `delete_own_account` removes the local user, their listings, and their `listing-photos` objects. It does not call a payment, identity, analytics, or backup vendor. |
| S-09 production backups | Needs an operations owner and a hosted project. |
| S-11 halt a Play rollout | The runbook covers this repo. Halting a store rollout needs Play Console access. |
