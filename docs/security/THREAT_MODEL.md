# Threat model

Date: 17 October 2026. Commit: `9914e7d`. This describes the system that is in the repository and on Mumbai staging. It is not a pen-test report. The evidence pass is [AUDIT_1017.md](AUDIT_1017.md).

## System

HOMIZI is a Flutter client (Android first, iOS project retained, web build on Netlify) talking to Supabase Postgres, Auth, and Storage. Match, contact, publish, chat, visit, and staff actions are SQL functions. Edge Functions are not used. Demo mode, when the URL or the public key is empty, keeps data on the device.

Staging project: `loraalfiuklespaldotd` (Mumbai). Web: https://homizi.netlify.app. Package id: `in.homizi.app`.

Production Supabase, Play Console, Firebase App Distribution, push, real identity verification, and payments are deferred.

## Assets

| Asset | Where it lives | Who should see it |
| --- | --- | --- |
| Phone and email | `private_contacts`, and Auth for the sign-in mailbox | The owner, and a match peer only after consent via `get_contact_visibility` |
| Street address | `property_private_details` | The host. Listing cards show locality and city |
| Listing photos | Private bucket `listing-photos` | The owner always. Another signed-in user after publish, per the storage policies |
| Session | Supabase Auth on device | That user |
| Reports | `reports` | The reporter and staff |
| Payments rows | `payments`, `subscriptions` | The owner may read. Clients cannot write. No checkout |
| Publishable client key | `config/staging.json` | Public by design. It is not a service-role key |

Gender, religion, caste, age, and marital status are not scoring inputs and are not columns used by `score_compatibility`.

## Actors

| Actor | Can |
| --- | --- |
| Anonymous | Call Auth health. Cannot read `properties`, `private_contacts`, `messages`, or `analytics_events` (staging returned `42501` on 17 October 2026). Cannot execute `publish_listing`, `get_contact_visibility`, `send_message`, `score_compatibility`, `delete_own_account`, `ensure_own_account`, or `staff_list_reports`. |
| Signed-in member | Own profile, own drafts, published listings, own interests. Cannot set listing status, verification, or payment rows. |
| Match peer | Thread and visit times for that match. Contact only after the other person shares it. |
| Staff | Queue, hide listing, suspend account, read funnel counts. Still cannot read `private_contacts` through the staff functions. |
| Suspended member | Blocked from sending messages and from new interests and reports by the suspend triggers. |
| Project owner (dashboard) | SQL editor and Auth settings. This is outside row level security. |

## Trust boundaries

1. The phone and the web bundle are untrusted. Hiding a field in Flutter is not the control. `discovery_parse_test.dart` drops address and contact fields from property rows, and the database grants are the control.
2. The publishable key is public. Security is row level security plus function grants. `AppConfig.parse` refuses `sb_secret_` and `service_role` in the client key.
3. Storage is a separate API. Listing photos are supposed to be a private bucket with owner paths `{userId}/{propertyId}/{fileId}.{ext}`. An anonymous storage lookup of `listing-photos` returned `404 NoSuchBucket` on 17 October 2026. Supabase hides private buckets from callers who cannot see them, so that response does not prove the bucket is missing and does not prove it exists.
4. Realtime on `messages` still passes through row level security. A block removes the row from the listener.
5. The SQL editor and the service role bypass row level security. Those credentials are not in git.

## What we are defending against

| Threat | Control in this build |
| --- | --- |
| Anonymous scraping of listings or contact | Grants revoked from `anon`. PD-05. Staging probe above. |
| Cross-user read of a draft, a street address, or a private phone | Policies in `supabase/migrations/20261011120100_homizi_access.sql`. Negative cases are named in `supabase/tests/01_rls_negative.sql`. |
| Contact leaked in chat, a notification, or analytics | `messages_no_contact`. Notification payloads are ids. Analytics rejects phone and email keys. |
| Client sets itself verified, published, or paid | Status columns are not client-writable. Publish and mock verification are functions. |
| Contact shown before consent | `get_contact_visibility`. Client tests in `contact_visibility_policy_test.dart`. |
| Upload into another user's folder, or a huge file | Owner prefix, JPEG/PNG/WebP, 5 MB. Client tests in `photo_upload_test.dart`. SQL file `05_listing_photo_storage.sql`. |
| Staff impersonation from the app | `is_staff()` and no client insert on `staff_roles`. |
| Secret committed | `tool/secret_scan.dart` in CI. Passed on 17 October 2026. |
| Account left behind on delete | `delete_own_account` removes the auth user, listings, and that user's `listing-photos` objects on the connected database. It does not call a payment, identity, or backup vendor, because those vendors are not connected. |

## Accepted for now

- Debug signing on release builds until an upload key exists.
- One interim moderator, and no `staff_roles` row until the owner inserts it.
- No production backup, because there is no production project.
- Push and payments are absent, so their threat cases are not implemented.
- The pgTAP suite was not re-run in this audit (no Docker). The test names are the intended controls. A passing local `supabase test db` is still required before S-02 is closed.

## Out of scope until the owner opens them

Real Aadhaar or face verification, payment webhooks, push tokens, a production region, Play Data safety submission, and a tested restore.
