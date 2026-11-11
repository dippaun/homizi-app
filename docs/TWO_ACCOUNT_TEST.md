# Two-account test

Use two fresh staging mailboxes. Do not reuse them after this pass.

- Account A: `qa+a1111@homizi.in`
- Account B: `qa+b1111@homizi.in`
- Staging test code for both: `000000`
- Any other email uses the 6-digit code from the Supabase email (`signInWithOtp`, then `verifyOTP`). `test5@homizi.in` / `000000` stays the on-device demo and does not write these rows.

Paste `docs/staging_apply_PERSIST_1111.sql` in the Mumbai SQL editor before the accept and reject steps. Do not run it until that file is approved. The rest of this script uses tables that are already on staging.

Sign out between accounts. After each action, reload the other account and confirm the row is still there.

## 1. Register

1. Open the app. Accept the terms.
2. On Sign in, enter `qa+a1111@homizi.in` and `000000`. Continue.
3. The role picker opens. Choose Tenant. A `profiles` row exists for that user (`ensure_own_account`).
4. Sign out. Repeat for `qa+b1111@homizi.in` and choose Host.

For a mailbox that is not `qa+` or `test<N>`, tap Send code, read the 6-digit email, and type it. The same role picker follows.

## 2. Listing

On B:

1. Post a home. Move through every step. Leave the screen and come back. The draft is still there, including photos.
2. Publish it.
3. Edit the title. Save. Reload. The new title is there.
4. Delete a second draft if you made one. It is gone after reload.

## 3. Save, pass, like

On A:

1. Save B's home. Sign out, sign in again. Saved still lists it. Unsave. Reload. It is gone.
2. Pass a different home. Reload the deck. That home does not return.
3. Like B's published home.

On B, reload Lead inbox. A's interest is listed. No phone number is shown.

## 4. People and roommates

On A, save roommate preferences (city, locality, occupation). Reload. The brief is still filled in.

On B, open the people deck. A appears when the requirement is published. Like A. On A, reload. B is listed under people who liked you, after the persist SQL is applied.

## 5. Accept and reject

On B, open the lead and tap Accept. Reload.

On A, open Matches. The request says Accepted. If both sides liked, a match card is there. Open chat, send "Is Saturday morning free?", and reload.

On B, reload Conversations. The same message is there. Reply. Reload A. The reply is there.

Repeat with a second listing and tap Reject. A sees Rejected after reload. No match is created for that reject.

## 6. Profile

On A, edit the display name. Reload. The new name is on the profile and on B's lead card.

## What was only on the device before this change

- Listing steps before a rent was entered, street address and landmark, and photos opened from My listings.
- Home-deck skip (pass).
- Passes were stored but the deck showed them again after reload.
- Search-flow swipes, seeker-demand likes, and the roomie catalog deck.
- Flow requirements, roomie brief publish, and priority ranks.
- Intelligent-match like, skip, and save.
- Host and broker accept or reject. The seeker could not read the decision.
- Incoming likes were not listed for the other account.

These already went to Supabase for a signed-in user and were left as they are: explore save and unsave, listing like and pass on the swipe deck, people swipe, the main roommate list, real match chat, tenant and host profile edits, and avatar upload. Demo mode, including `test5@homizi.in`, still keeps those actions on the device.
