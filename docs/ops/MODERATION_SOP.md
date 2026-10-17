# Moderation SOP

S-07. Interim moderator: the owner, deep. Assigned 17 October 2026. This is the staging and pre-launch process. A wider roster and a public-launch response clock are still pending (D-10).

The store draft must keep saying that a staffed public review queue is not a launch claim. `docs/STORE_LISTING.md` is still a draft.

## What the product already does

- A signed-in person can report a user or a listing. The report stores a reason. Report text cannot contain a phone number or an email address (`supabase/tests/08_safety_deletion.sql`, `test/features/safety/safety_rules_test.dart`).
- A block stops messages and contact in both directions. A person cannot block themselves.
- Clients cannot set report status, listing status, or user status. Staff actions go through `staff_list_reports`, `staff_review_report`, `staff_hide_listing`, and `staff_suspend_user` in `supabase/migrations/20261016183000_realtime_moderation_analytics.sql`.
- Each of those functions checks `public.is_staff()`, which is true only when `auth.uid()` is in `public.staff_roles`.
- The queue payload is ids, a reason, and a status. It does not return a phone or an email. Widget test: `queue rows drop contact fields and free text`.
- A suspended account cannot send a message. Hiding a listing sets `properties.status` to `paused`. Suspending a user sets `users.status` to `suspended` and pauses that user's published listings.
- On 17 October 2026 an anonymous call to `staff_list_reports` on Mumbai staging returned `42501 permission denied for function staff_list_reports`. The function is present. Anonymous clients cannot open it.

## What is not done yet

`public.staff_roles` has no seeded user. Authenticated clients may select their own row and may not insert one (`staff_roles_select_self`, grant is select only). Until the owner's user id is inserted by the database owner, Settings will not open a working queue for deep. Demo mode does not open the queue.

The pgTAP file `supabase/tests/10_realtime_moderation_analytics.sql` covers member denial and staff review. This audit did not execute it. Docker is not available on the audit machine.

## Grant the interim moderator

Do this in the Supabase SQL editor for project `loraalfiuklespaldotd`, as the project owner. Do not put the user id in git.

1. Sign in once in the app against staging so `ensure_own_account` creates the `public.users` row for that auth user.
2. In Authentication, Users, copy the user id for the owner's account.
3. Run `insert into public.staff_roles (user_id) values ('<that uuid>');`
4. Open the app as that user. Settings shows the review queue only when `is_staff()` is true (`test/widget/settings_staff_test.dart`).

Remove access with `delete from public.staff_roles where user_id = '<that uuid>';`.

## How to handle a report

Look at open and reviewing reports when you are at the machine. Before any public launch, the queue is part of the daily check. A numbered public SLA is not set.

1. Open Review reports. `staff_list_reports` returns open and reviewing rows.
2. Mark the report `reviewing` while you look.
3. If the listing should leave discovery, hide it. If the account should stop messaging and publishing, suspend it. Say which you did in the audit row the function writes (`review_report` and the status). The metadata is the new status, not contact details.
4. Mark the report `resolved` when the hide or suspend is done, or `dismissed` when the report does not need a product change.
5. A block between two people is separate. Either person can block. Staff do not need to block on their behalf for the contact gate to close.

If the moderator is away and a report describes a contact leak or a threat, pause the listing from the SQL editor (`properties.status = 'paused'`) and follow [INCIDENT_ROLLBACK_RUNBOOK.md](INCIDENT_ROLLBACK_RUNBOOK.md).

## What staff must not do

- Do not collect Aadhaar, a face image, or a payment card while reviewing.
- Do not copy a phone number or an email into a report note or an audit payload.
- Do not update `reports.status`, `properties.status`, or `users.status` from the client. Use the staff functions so the check and the audit row stay in place.
- Do not tell users the store listing already has a full moderation team. The interim moderator is one person, the owner.
