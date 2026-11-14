# Two-user live test

Use this after Deep has applied `docs/staging_apply_LIVE_1115.sql` on staging (`loraalfiuklespaldotd`). Do not apply that file until Deep says yes to each section.

`test5@homizi.in` with code `000000` stays an on-device demo. It does not call Supabase Auth. Use two other mailboxes for this test.

## Before the migration

1. Sign in as two real staging accounts on two browsers or phones. Do not use `test5@homizi.in`.
2. Open Home. Published homes already on staging should load for a signed-in person. If a table from the unapplied list is missing, that screen shows the bundled catalog with a **Sample** tag and the app keeps working.
3. `test5@homizi.in` / `000000` still opens the on-device demo and does not write to the project.

## After the migration

Run these steps with user A and user B. Each step should show up for the other person within a few seconds, without a manual refresh.

1. A signs up or signs in, then posts a home (a flat, a shared room, or a PG) and publishes it. B, signed in and not verified, sees that home on Home. A guest who is not signed in sees it through `public_listings()` and does not see the street address or a phone number.
2. A draft that A has not published does not appear for B or for a guest.
3. B likes A's home. A sees that like. A third account does not.
4. A likes B back (B needs a published home or a published roommate brief). One match appears for both. Contact stays hidden. Neither person sees a phone number or an email address.
5. A sends a chat message that is not a phone number or an email. B sees it in the open thread. A message that contains a phone number or an email is refused.
6. A saves a roommate profile. B sees A in Find Your Roomie or the roommate deck. Liking each other creates the same kind of match as step 4.
7. A saves a search. It is stored on `saved_searches` for A only.
8. A submits a property-partner application. Only A can read that row.
9. A photo on the published home can be opened by B. A photo that is not on a published home stays hidden.

## What must stay true

- Anon `select` on `properties`, `interests`, `matches`, `messages`, and `private_contacts` is denied.
- Anon can call `public_listings()` and receives only published card columns.
- Owners update only their own listings.
- `get_contact_visibility` is the only read that can return a phone or an email, and only after consent.

## Automated check

`supabase/tests/L15_live_two_user.sql` covers the same rules with two database roles and an anonymous role. The database CI job runs it with `supabase test db` after `supabase db reset`. That does not touch the staging project.
