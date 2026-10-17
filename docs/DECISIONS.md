# Decisions

D-01 through D-10 as of 17 October 2026. The owner (deep) restated these for the execution-plan audit. The 12 October and 14 October product record stays in the repository root file `DECISIONS.md` as PD-01 through PD-08. This file is the pipeline register.

## Decided

### D-01 Framework — Approved

Flutter and Dart, one codebase for Android and iOS. Evidence: `pubspec.yaml`, `lib/`, `android/`, and `ios/`. The owner approved this on 12 October 2026 and restated it on 17 October 2026.

### D-02 Backend — Approved

Supabase with PostgreSQL, Auth, Storage, and row level security. Evidence: `supabase/migrations/`, `config/staging.json`, and `docs/STAGING_SETUP.md`. On 17 October 2026 the Mumbai staging project `loraalfiuklespaldotd` answered on Auth (GoTrue v2.197.0) and PostgREST.

A production Supabase project is still deferred. That deferral is D-08. It does not reopen the provider choice.

### D-03 Launch scope — Approved

Android first. The iOS project stays in the tree. Chat, visits, and in-app notices are in this build. Payments, real identity verification, push delivery, production Supabase, and store submission are deferred. Play Console comes at the end.

### D-04 Verification — Deferred

Mock verification only. `request_mock_verification` stops at `mock_pending` (`supabase/tests/03_profile_session.sql`). The schema has no Aadhaar column (`docs/DATA_MODEL.md`). A provider, a lawful basis, consent, retention, and a privacy review are still pending.

### D-05 Contact privacy — Approved

Recorded on 12 October 2026 as PD-04 and PD-08, and restated on 17 October 2026.

- A person shares their own phone, email, or both, for one match. The other person's contact is returned only by `get_contact_visibility`.
- Share and stop-share call `grant_contact_consent` and `revoke_contact_consent`.
- A chat message cannot contain a phone number or an email address. The same check is in `lib/features/chat/domain/chat_rules.dart` and the `messages_no_contact` constraint.
- A visit is one to three start times. Accepting a visit does not reveal a street address.
- A pass does not remove a match (PD-03). `create_interest` does not delete `matches`. The client test is `demo match keeps contact hidden and a pass leaves the match`.

### D-06 Payments — Deferred

No checkout. `subscriptions` and `payments` exist and clients cannot write them (`docs/DATA_MODEL.md`). Finance, store policy, refunds, and tax review are pending.

### D-07 Package ID — Approved

Android application id and iOS bundle id `in.homizi.app`. The Android namespace is `app.homizi` because `in` is not a valid Java package segment. Evidence: `android/app/build.gradle.kts` (commit `3f096e4`) and `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj`.

### D-10 Moderation — Interim

On 17 October 2026 the owner (deep) is the interim moderator. The working process is [ops/MODERATION_SOP.md](ops/MODERATION_SOP.md). `public.staff_roles` has select-for-self row level security and no insert grant for clients, and no staff row is seeded. The queue stays closed until that user id is inserted from the Supabase SQL editor. A public-launch roster beyond this interim assignment is still pending.

## Pending

### D-08 Production region — Pending

Mumbai is the staging project. It is not an approval of the production region. Latency, privacy, and the contract for a production project are still open.

### D-09 Store account type — Pending

Play Console is at the end of the pipeline. The owner has not said whether the Play account is a personal account or an organization. That choice changes the closed-test rule for personal accounts created after 13 November 2023 (at least 12 opted-in testers for 14 continuous days before a production-access request). Apple account ownership is also unset.

## Already recorded as PD items

These stay in the root `DECISIONS.md` and are in force:

| ID | Decision |
| --- | --- |
| PD-01 | White field, orange `#F75620`, Plus Jakarta Sans. Approved 14 October 2026. |
| PD-02 | One account may be tenant, host, or both. |
| PD-03 | A pass does not unmatch. |
| PD-05 | Discovery requires a signed-in session. Anonymous clients cannot read listings. |
| PD-06 | Compatibility weights: budget 40 inside the range, 15 when close, 0 when outside; city 25; locality 15; furnishing 10; property type 10. Gender, religion, caste, age, and marital status are not inputs. |
