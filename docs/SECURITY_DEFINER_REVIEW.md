# SECURITY DEFINER review

Reviewed 11 Nov 2026 from `supabase/migrations/` only. Nothing was applied, and the database was not queried. Lint names below are the Supabase advisor checks [0028](https://supabase.com/docs/guides/observability/advisors?lint=0028_anon_security_definer_function_executable) (anon can execute) and [0029](https://supabase.com/docs/guides/observability/advisors?lint=0029_authenticated_security_definer_function_executable) (signed-in users can execute).

`SECURITY DEFINER` runs as the function owner, so it bypasses row level security. PostgREST exposes a `public` function at `/rest/v1/rpc/<name>` when `anon` or `authenticated` can execute it. A grant to `PUBLIC` counts for both roles. Revoking one role and leaving `PUBLIC` in place does not close the lint.

## How EXECUTE was decided

Postgres grants `EXECUTE` to `PUBLIC` on a new function. Each later `GRANT` and `REVOKE` in the migrations was applied in filename order. `CREATE OR REPLACE` keeps the existing grants. The early `revoke all on all functions in schema public` and `grant all on all functions in schema public to service_role` apply only to functions that already existed in that file.

The table lists `anon`, `authenticated`, and `service_role` only when the migration text gives them `EXECUTE`. "Owner only" means those three roles are revoked and `PUBLIC` is revoked. The owner can always execute. A hosted project that also auto-grants `service_role` may have that role on more functions than this table shows. This review did not check the live catalog.

Every function below has `search_path` set, so the mutable-search_path lint does not apply. None of them put `pg_temp` last (`public, pg_temp`). That is optional hardening. It is not in the draft, because it does not clear 0028 or 0029.

`20261111130000_chat_contact_guard.sql` is not applied on staging. It replaces `contains_contact_text` and does not add a `SECURITY DEFINER` function. `public.user_badges` is a security-definer view, not a function, so it is outside this table (see `docs/QA_MATRIX.md`, QA-12).

## Counts

| Set | Count |
| --- | --- |
| `SECURITY DEFINER` functions in the migrations | 89 |
| In `public` | 85 |
| In `tests` (not an API schema) | 4 |
| `public` functions `anon` or `authenticated` can still execute | 56 |
| Of those, `anon` can execute | 3 |
| Already revoked from `anon` and `authenticated` | 29 in `public`, plus 3 in `tests` |
| Fine as written | 85 |
| Need a fix | 4 |

The advisor's "about 59" matches the finding rows, not a second set of functions. 0028 flags 3 functions. 0029 flags 55 in `public` plus `tests.get_supabase_uid`. 3 + 55 + 1 = 59 findings. Two of the anon functions are also in the authenticated count, so the unique functions are 57 (56 in `public`, one test helper).

## Highest risk

1. **`public.staging_create_test_user(text)` — High.** `anon` can execute it, and the body inserts into `auth.users`. The email must match `qa+…@homizi.in` or `testN@homizi.in`, `staging_flags.test_accounts_enabled` must be on, and the password comes from `private.staging_secrets`. Daily cap is 50. The staging app calls this before login (`test5@homizi.in`). Do not revoke it on staging. Do not create this grant on a production project.
2. **`public.get_precise_address(uuid)` — Medium, wrong scope.** A signed-in caller who is not the host gets the street line and coordinates when they have any accepted or completed visit with that host. The check is not limited to the property id passed in. One accepted visit can reveal another listing from the same host.
3. **`public.set_demo_id_badge(boolean)` — Medium.** Any signed-in user can set their own `profiles.verification_status` to `mock_verified`. It refuses only when the database setting `app.environment` is exactly `prod`. If that setting is unset, the call succeeds. It does not write a document number. pgTAP calls it.
4. **`public.open_conversation_for_match()` — Low, but it is the one safe fix.** Trigger on `public.matches`. `PUBLIC` can still execute it, so 0028 and 0029 both fire. The body inserts a conversation for `NEW.id`. Called as an RPC, `NEW` is null and the insert fails the not-null check. Revoke it. The trigger keeps working.

Locked functions with a high blast radius, not callable by `anon` or `authenticated` from the migration grants: `homizi_seed_auth_user` (inserts `auth.users`), `staging_purge_test_users` (deletes test users), `apply_kyc_checks` and `apply_verification_result` (set verification), `apply_esign_result` (sets agreement status). The KYC and e-sign functions also raise if `auth.role()` is `anon` or `authenticated`. Leave their grants as they are.

## Draft

`docs/staging_proposed_SECDEF_1111.sql` revokes `EXECUTE` on `open_conversation_for_match` from `PUBLIC`, `anon`, and `authenticated`. It does not change bodies, security mode, or `search_path`. It needs an explicit yes before anyone runs it. It has not been applied.

Moving `is_staff`, `is_blocked_with`, and `viewer_can_read_lifestyle` into a non-exposed schema would clear 0029 for those helpers. Policies call them today, so that move is not in the draft.

## Functions that need a fix

| Function | Needs definer | search_path | EXECUTE | Risk | Recommended fix |
| --- | --- | --- | --- | --- | --- |
| `public.get_precise_address(uuid)` | Yes. Reads `property_private_details`, which the client cannot select. | `public` | authenticated | Medium | Later, with tests: require an accepted visit for that property, not any visit with the host. Not in the draft. |
| `public.open_conversation_for_match()` | Yes. The trigger inserts into `conversations`. | `public` | PUBLIC, so anon and authenticated | Low | Revoke `EXECUTE` from `PUBLIC`, `anon`, and `authenticated`. In the draft. |
| `public.set_demo_id_badge(boolean)` | Yes. Clients cannot set `verification_status`. | `public` | authenticated | Medium | Also require an explicit staging flag. Absence of `app.environment = prod` is a weak guard. Not in the draft. |
| `public.staging_create_test_user(text)` | Yes. Inserts `auth.users` and reads `private.staging_secrets`. | `public, auth, extensions` | anon | High | Keep on staging. Do not grant this on production. Not in the draft. |

## Functions that are fine

"Fine" means the definer bit is needed, `search_path` is set, `EXECUTE` matches the caller the function was written for, and the body checks that caller. 0028 or 0029 will keep firing on the signed-in RPCs and on the three RLS helpers. That warning is accepted.

| Function | What it does | Needs definer | search_path | EXECUTE | Risk | Recommended fix |
| --- | --- | --- | --- | --- | --- | --- |
| `public._has_like_toward_user(uuid, uuid)` | Internal check that one user has an active like toward another. | Yes. Reads `interests` inside other definer functions. | `public` | service_role | Low | None. Keep it off `anon` and `authenticated`. |
| `public._link_visit_property(public.matches)` | Picks the property a visit should point at. | Yes. Called only from other definer functions. | `public` | owner only | Low | None. |
| `public._roommate_compatibility_detail(uuid, uuid)` | Score breakdown used by the public roommate RPCs. | Yes. Reads both seekers' requirement rows. | `public` | owner only | Low | None. |
| `public._try_mutual_match(uuid, uuid)` | Inserts a match when both sides have an active like. | Yes. Clients cannot insert `matches`. | `public` | service_role | Low | None. |
| `public.apply_esign_result(uuid, text, text)` | Edge function writes the e-sign status. Refuses `anon` and `authenticated` inside the body. | Yes. Clients cannot update agreement status. | `public` | service_role | Low | None. |
| `public.apply_host_onboarding(...)` | Saves the signed-in host's roles and authorization requests. No phone, email, or Aadhaar argument is stored. | Yes. Writes onboarding rows the client cannot write. | `public` | authenticated | Low | None. |
| `public.apply_kyc_checks(uuid, text, text, text, text, text)` | Webhook path sets Aadhaar and face status. Refuses `anon` and `authenticated`. Rejects a raw 12-digit number. | Yes. Clients cannot set verified. | `public` | service_role | Low | None. |
| `public.apply_verification_result(uuid, text, text, text, text, text)` | Older server-only verification write. Same role refusal as `apply_kyc_checks`. | Yes. Clients cannot set verified. | `public` | service_role | Low | None. |
| `public.clear_recently_viewed()` | Deletes the signed-in user's recent listing views. | Yes. The client cannot delete those rows. | `public` | authenticated | Low | None. |
| `public.complete_demo_payment(uuid, boolean)` | Marks the caller's own demo payment succeeded or failed. | Yes. Clients cannot update `payments`. | `public` | authenticated, service_role | Low | None. |
| `public.create_agreement(uuid, text, text, integer, uuid)` | Creates a draft agreement for a match the caller is in. | Yes. Clients cannot insert agreements. | `public` | authenticated, service_role | Low | None. |
| `public.create_demo_payment(uuid, text, integer, text)` | Inserts a demo payment for the caller. Does not call a live gateway. | Yes. Clients cannot insert payments. | `public` | authenticated, service_role | Low | None. |
| `public.create_interest(interest_target_type, uuid, interest_action)` | Records the caller's like, pass, or save, and may open a match. | Yes. Clients cannot write `interests`. | `public` | authenticated, service_role | Low | None. |
| `public.create_mutual_match(uuid)` | Opens a match for two active likes. Checks `auth.uid()`. | Yes. Clients cannot insert `matches`. | `public` | authenticated, service_role | Low | None. |
| `public.delete_my_verification()` | Deletes the caller's identity-verification row. | Yes. That table is not client-writable. | `public` | authenticated, service_role | Low | None. |
| `public.delete_own_account()` | Deletes the caller's storage objects, related rows, and `auth.users`. Returns no phone, email, or address. | Yes. Clients cannot delete `auth.users`. | `public` | authenticated | Medium | None. The delete is limited to `auth.uid()`. |
| `public.demo_sign_agreement(uuid, text)` | Demo signature for a party on the caller's agreement. | Yes. Clients cannot update agreements. | `public` | authenticated, service_role | Low | None. |
| `public.enqueue_notification(uuid, text, jsonb)` | Inserts one notification if the recipient allows that kind. | Yes. Clients cannot insert notifications. | `public` | owner only | Low | None. |
| `public.ensure_own_account()` | Inserts the caller's user, profile, contact email, and empty tenant preferences. | Yes. The auth trigger's tables are not client-insertable in every case. | `public` | authenticated | Low | None. |
| `public.get_contact_visibility(uuid)` | Returns phone or email only for an active match when the other person consented and nobody blocked. Otherwise omits both. | Yes. Reads `private_contacts`. | `public` | authenticated, service_role | Medium | None. The match and consent checks are the gate. |
| `public.get_listing_view_counts(uuid[])` | View totals for published listings. No viewer id in the result. | Yes. `listing_views` is not readable as a full count under RLS. | `public` | anon, authenticated | Low | None. The anon grant is intentional. |
| `public.get_my_listing_stats(uuid)` | Owner-only totals for one listing. Other accounts get `not_owner`. | Yes. Reads interests and visits the owner cannot see through RLS. | `public` | authenticated | Low | None. |
| `public.get_visit_address(uuid)` | Returns `address_line` only to a match participant after the visit is accepted or completed, and not for locality-only listings. | Yes. Reads `property_private_details`. | `public` | authenticated | Medium | None. This gate is tied to the visit id. |
| `public.grant_contact_consent(uuid, contact_scope)` | Caller grants phone and/or email on a match they belong to. | Yes. Clients cannot insert consents. | `public` | authenticated, service_role | Low | None. |
| `public.handle_new_auth_user()` | Auth insert trigger. Copies id, profile, email, and empty preferences. | Yes. `auth.users` trigger must write app tables. | `public` | service_role | Low | None. Already revoked from `anon` and `authenticated`. |
| `public.homizi_seed_auth_user(uuid, text)` | Migration helper that inserts one seed auth user and identity. | Yes. Writes `auth.users`. | `public, auth, extensions` | owner only | Low exposure | None. Do not grant it to `anon` or `authenticated`. |
| `public.is_blocked_with(uuid)` | True when either side has blocked the other. Used by policies and RPCs. | Yes. RLS would otherwise recurse through `blocks`. | `public` | authenticated, service_role | Low | None. A later move to a private schema can clear 0029. |
| `public.is_staff()` | True when `auth.uid()` is in `staff_roles`. | Yes. Policies must read `staff_roles` without opening that table. | `public` | authenticated, service_role | Low | None. Same private-schema follow-up as `is_blocked_with`. |
| `public.list_my_listings()` | The caller's own listings. | Yes. Returns owner fields hidden from the public listing policy. | `public` | authenticated | Low | None. |
| `public.list_owner_leads(uuid)` | Leads for a listing the caller hosts. | Yes. Lead rows are not client-readable across owners. | `public` | authenticated, service_role | Low | None. |
| `public.list_property_interests(uuid)` | People interested in a listing the caller hosts. | Yes. Reads other users' interest rows. | `public` | authenticated | Low | None. |
| `public.list_roommate_seekers(...)` | Discoverable roommate cards for the signed-in user. No phone or email. Skips blocked users and `discoverable = false`. | Yes. Joins profiles, badges, and interests the caller cannot fully select. | `public` | authenticated | Low | None. |
| `public.listing_publish_issue(text, text, text, integer, uuid)` | Returns why a listing is not ready to publish. | Yes. Used by the publish trigger and RPC. | `public` | owner only | Low | None. |
| `public.listing_visit_count(uuid, uuid)` | Visit count for one owner and listing. | Yes. Internal helper for owner stats. | `public` | owner only | Low | None. |
| `public.notification_allowed(uuid, text)` | Whether that user allows a notification kind. | Yes. Reads another user's preference row. | `public` | owner only | Low | None. |
| `public.notify_on_interest()` | Trigger. Queues a notification for a new interest. | Yes. Inserts a notification for the other user. | `public` | owner only | Low | None. |
| `public.notify_on_match()` | Trigger. Queues a match notification. | Yes. Same reason. | `public` | owner only | Low | None. |
| `public.notify_on_message()` | Trigger. Queues a message notification. | Yes. Same reason. | `public` | owner only | Low | None. |
| `public.notify_on_visit()` | Trigger. Queues a visit notification. | Yes. Same reason. | `public` | owner only | Low | None. |
| `public.notify_push_on_notification()` | Trigger. Asks the push path to send. | Yes. Reads device tokens. | `public` | owner only | Low | None. |
| `public.notify_saved_searches_on_publish()` | Trigger. Notifies saved searches that match a new listing. | Yes. Reads other users' saved searches. | `public` | owner only | Low | None. |
| `public.notify_service_lead()` | Trigger. Notifies staff of a service lead. | Yes. Writes a notification the client cannot insert. | `public` | owner only | Low | None. |
| `public.open_conversation(uuid)` | Opens the caller's conversation for a match they belong to. | Yes. Clients cannot insert conversations. | `public` | authenticated | Low | None. |
| `public.owner_lead_json(uuid)` | JSON for one owner lead. Used by the lead triggers. | Yes. Internal. | `public` | owner only | Low | None. |
| `public.owner_reply_hours(uuid)` | Rounded mean hours until that host replied. Message text is not returned. Any signed-in user may pass a host id. | Yes. Reads messages RLS would hide. | `public` | authenticated | Low | None. The result is one integer. |
| `public.profile_activity()` | Counts of the caller's own activity. | Yes. Aggregates tables the profile screen does not select directly. | `public` | authenticated | Low | None. |
| `public.properties_guard_publish()` | Trigger. Blocks a direct status update to `published` when the listing is incomplete. | Yes. Must see columns the client update policy does not. | `public` | owner only | Low | None. |
| `public.property_matches_saved_search(uuid, uuid)` | Whether one listing matches one saved search. | Yes. Internal to the publish notifier. | `public` | owner only | Low | None. |
| `public.propose_visit_time(uuid, jsonb)` | Replaces proposed times on a visit the caller is part of. Does not return an address. | Yes. Clients cannot update visits. | `public` | authenticated | Low | None. |
| `public.publish_listing(uuid)` | Publishes the caller's listing when the guard passes. | Yes. Status is not a free client update. | `public` | authenticated, service_role | Low | None. |
| `public.publish_requirement(uuid)` | Publishes the caller's requirement when it is complete. | Yes. Same reason. | `public` | authenticated, service_role | Low | None. |
| `public.push_allowed(uuid, text)` | `send-push` checks this with the service role before sending. | Yes. Reads another user's push preference. | `public` | service_role | Low | None. |
| `public.read_own_host_legal_name()` | Legal name for the signed-in host only. Null when signed out. | Yes. That column is not in the client select policy. | `public` | authenticated | Low | None. |
| `public.record_kyc_consent(text)` | Stores the caller's consent version. Does not set verified. | Yes. Writes `identity_verifications`. | `public` | authenticated, service_role | Low | None. |
| `public.record_listing_view(uuid)` | Records that the signed-in user viewed a published listing today. | Yes. Clients cannot insert `listing_views`. | `public` | authenticated | Low | None. |
| `public.reject_if_actor_suspended()` | Trigger. Blocks writes from a suspended account. | Yes. Must read `users.status` for the actor. | `public` | owner only | Low | None. |
| `public.remind_own_deposit(uuid)` | Marks the caller's own deposit reminder. | Yes. Writes a row the client cannot update that way. | `public` | authenticated | Low | None. |
| `public.request_listing_photos(uuid)` | Asks the host for photos on a listing the caller can see. | Yes. Inserts a request row. | `public` | authenticated | Low | None. |
| `public.request_mock_verification()` | Sets the caller's status to `mock_pending` only. | Yes. Clients cannot set `verification_status`. | `public` | authenticated, service_role | Low | None. |
| `public.request_visit(uuid, jsonb)` | Creates a visit on the caller's match. Does not return an address. | Yes. Clients cannot insert visits. | `public` | authenticated | Low | None. |
| `public.respond_visit(uuid, text)` | Accept, decline, cancel, or complete a visit the caller is part of. | Yes. Clients cannot update visits. | `public` | authenticated | Low | None. |
| `public.revoke_contact_consent(uuid)` | Revokes the caller's own consent on a match. | Yes. Clients cannot update consents. | `public` | authenticated, service_role | Low | None. |
| `public.roommate_compatibility(uuid, uuid)` | Integer score. Caller must be one of the two users, or staff. | Yes. Reads both requirement rows. | `public` | authenticated | Low | None. |
| `public.roommate_compatibility_breakdown(uuid, uuid)` | Same gate as the integer score, with the row breakdown. The app calls this. | Yes. Same reason. | `public` | authenticated | Low | None. |
| `public.roommate_lifestyle(uuid)` | Lifestyle answers for yourself, or for someone else only when you are premium and verified. | Yes. The select policy uses the same rule and would recurse. | `public` | authenticated | Low | None. |
| `public.saved_search_new_count(uuid)` | New-match count for a saved search owned by the caller. Returns 0 otherwise. | Yes. Reads listings beyond the caller's own rows. | `public` | authenticated | Low | None. |
| `public.send_agreement(uuid)` | Moves the caller's agreement to sent. | Yes. Clients cannot update agreement status. | `public` | authenticated, service_role | Low | None. |
| `public.send_message(uuid, text)` | Inserts a message when the caller is in the conversation and the body has no phone or email. | Yes. Clients cannot insert messages. | `public` | authenticated | Low | None. |
| `public.set_my_listing_status(uuid, text)` | Owner pause, rented, or draft change. Cannot jump a guarded listing to published. | Yes. Status is not a free client update. | `public` | authenticated | Low | None. |
| `public.set_owner_lead_status(uuid, text)` | Sets a lead status for a listing the caller hosts. | Yes. Lead rows are not client-updatable. | `public` | authenticated, service_role | Low | None. |
| `public.staff_hide_listing(uuid)` | Staff pauses a published listing. Returns `not_staff` otherwise. Writes an audit row. | Yes. Clients cannot change another host's status. | `public` | authenticated | Medium | None. The `is_staff()` check is the gate. |
| `public.staff_list_reports()` | Open and reviewing reports for staff. Ids, reason, and status only. | Yes. Report rows are not public. | `public` | authenticated | Medium | None. Same staff gate. |
| `public.staff_review_report(uuid, text)` | Staff sets a report to reviewing, resolved, or dismissed. | Yes. Clients cannot update report status. | `public` | authenticated | Medium | None. Same staff gate. |
| `public.staff_suspend_user(uuid)` | Staff suspends another user and pauses their published listings and requirements. Cannot suspend yourself. | Yes. Clients cannot set `users.status`. | `public` | authenticated | Medium | None. Same staff gate. |
| `public.staging_purge_test_users(interval)` | Deletes `qa+` and `testN` auth users older than the interval when the staging flag is on. Skips `test@homizi.in`. | Yes. Deletes `auth.users`. | `public, auth` | owner only | Low exposure | None. Do not grant it to `anon` or `authenticated`. |
| `public.sync_owner_lead_interest()` | Trigger. Copies an interest into the owner lead inbox. | Yes. Writes lead rows. | `public` | owner only | Low | None. |
| `public.sync_owner_lead_visit()` | Trigger. Copies a visit into the owner lead inbox. | Yes. Writes lead rows. | `public` | owner only | Low | None. |
| `public.undo_last_interest(interest_target_type, uuid)` | Deletes the caller's latest like or pass on that target. | Yes. Clients cannot delete interests. | `public` | authenticated | Low | None. |
| `public.unsave_interest(interest_target_type, uuid)` | Removes the caller's save. Leaves like and pass rows. | Yes. Clients cannot delete interests. | `public` | authenticated | Low | None. |
| `public.viewer_can_read_lifestyle()` | True when the caller is signed in, premium, and verified. Used by the lifestyle policy. | Yes. Reads verification rows the policy cannot. | `public` | authenticated | Low | None. Private-schema follow-up only. |
| `public.viewer_is_verified(uuid)` | True when that user is `mock_verified` or has a verified Aadhaar or face check. | Yes. Internal. Would leak verification status if granted. | `public` | owner only | Low | None. Keep this grant closed. |
| `tests.authenticate_as(text)` | pgTAP helper. Sets the JWT claim for a fixture user. | Yes. Test session setup. | `tests, public` | owner only | Low | None. `tests` is not in the API schemas. |
| `tests.clear_authentication()` | Clears the test JWT claim. | Yes. Test session setup. | `tests, public` | owner only | Low | None. |
| `tests.create_supabase_user(text, text, text)` | Inserts a local fixture auth user. | Yes. Writes `auth.users`. | `auth, public, extensions, tests` | owner only | Low | None. |
| `tests.get_supabase_uid(text)` | Looks up a fixture user's id by label. | Yes. Reads the test map and auth rows. | `tests, public` | authenticated | Low | None. pgTAP runs it as `authenticated`. The Data API does not expose `tests`. If 0029 lists it, leave the grant. |
