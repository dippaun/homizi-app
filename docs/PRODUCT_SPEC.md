# Product spec

Description of the HOMIZI build in this repository. This is the current MVP scope. It is not a new owner approval. Approved choices stay in [DECISIONS.md](DECISIONS.md). Items that still need the owner, a lawyer, finance, or a vendor stay in that file’s still-blocked table and in [plan/PLAN_DIFF.md](plan/PLAN_DIFF.md).

## Who it is for

Tenants, owners, flatmates, and brokers in Indian cities. One account can hold a tenant, host, roommate, or broker role.

## Acceptance criteria

A build meets this MVP when each line below is true on the staging web app and in `flutter test`.

1. The splash stays on the four choices until the person taps Tenant, Owner, Random Roommate Finder, Broker, or Sign in. It does not open home or sign-in by itself.
2. Tenant: full room, shared room, or roommate, then budget, location, amenities, and preferences, then the shared swipe deck of homes with a match percent and reasons.
3. Owner: the same swipe deck shows seeker demand. Posting a flat still uses the listing wizard.
4. Random Roommate Finder opens Find Your Roomie and the same swipe deck for people. The Roommates tab uses that deck when swipe is on.
5. Broker: location, price, amenities, images, and other details, then the swipe deck.
6. `/match` swipe, `/match/feed`, `/roommates` swipe, `/roomie` swipe, and `/flow/swipe` are that one deck. The intelligent match feed uses the shared `SwipeMatcher` with chip filters, match colours (green ≥70, yellow 40–69, red <40 or key miss), reasons on the card, and verification badges kept separate from the score.
7. Home cards are ranked with `score_compatibility` (budget, city, locality, furnishing, property type). Likes, skips, saves, visits, verification, listing quality, and freshness adjust that score. Gender, religion, caste, age, and marital status are not score inputs.
8. Connected sessions rank published listings from the server. The offline catalog is used only in demo mode.
9. Photos only is applied in the property query, not only after the page returns.
10. Match colour is green at 70% or more, yellow from 40% to 69%, and red below 40% or when a key requirement misses. The percent text sits on that colour. Verification badges are separate.
11. `test5@homizi.in` with code `000000` opens the on-device demo confirmation from the sign-in screen outside production. Other mailboxes keep the hosted staging sign-in. Production refuses `000000`.
12. A like or the end of a deck opens a confirmation. Contact stays hidden until a mutual match and a share. No real payment is taken.

## What this build includes

- Splash search start with the four paths, and a sign-in control that leaves the choice on purpose.
- Welcome consent records a draft policy version. The legal text is not approved.
- Sign-in. Hosted staging emails a 6-digit code. `test5@homizi.in` / `000000` is the client demo account and does not call Supabase Auth. No SMS is sent.
- Tenant, host, roommate, and broker profiles, plus a mock verification state. No Aadhaar number and no face capture.
- A requirement: city, locality, budget, move-in, occupancy, amenities, and preferences. The same brief can be edited and opened again on this device.
- A listing: title, city, locality, rent, deposit, furnishing, type, amenities, photos, preview, and server-side publish checks. The public card has no street address, phone, or email.
- Explore with search, filters, rent sort, and pages of homes. Photos only, bedroom count, and verified hosts are part of the query.
- One swipe deck for homes and people. Like, pass, and save. A mutual like creates a match. A later pass does not remove it (PD-03).
- Intelligent match (`/match`) opens that deck for homes. Find Your Roomie and the Roommates tab open it for people.
- Contact stays hidden until there is a match and the other person has shared their own phone, email, or both (PD-04).
- Chat refuses a phone number or an email. A visit is one to three start times, not an address.
- In-app notices for a match, a message, or a visit. Push is not connected.
- Report and block. A person in `staff_roles` can review reports. No staff user is seeded.
- Account deletion on this device, and on the connected database when Supabase is configured.
- English and Hindi for the buttons, help, and demo home titles.
- Brand tokens in `lib/core/theme/homizi_colors.dart`. Yellow and golden orange use dark ink, not white.

## Deferred

Real payments, real identity verification, production Supabase, push delivery, store submission, staffed moderation, approved legal text, and production backups. See DECISIONS.md.

## Demo mode

`DEMO_SKIP_LOGIN`, forced demo mode, or an empty `SUPABASE_URL` / `SUPABASE_ANON_KEY` keeps ranking on the device. The offline catalog has homes across Bengaluru, Pune, Mumbai, Hyderabad, and Delhi NCR. Contact details are never on those cards. A connected session that is not in demo mode does not substitute that catalog when the server returns no rows.
