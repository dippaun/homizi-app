# HOMIZI QA matrix (A09)

## Revision — source at `e941b79`

PR #32 is on `main`. The browser rows below were taken on the previous Pages and Netlify publish (`gh-pages` `06bb97b`), which still opened `/#/home` with no sign-in screen. Source at `e941b79` shows a splash with four branches and does not call `enterForcedDemo()` until a branch is chosen. The defect list QA-02 through QA-10 and QA-13 still matches the source: legal hash versus path URLs, unsave, invalid "Brief published", visit rows to `/matches`, bedrooms and verified-host filters after fetch, broker fixture chats, and no focus ring. QA-01 remains for the published build until that build is replaced. PR #31 was open and is not part of these results.


Executed against `main` `25841d2` (source) and the two public web hosts on 2026-10-29. App code was not changed. Defects are open. This file is the log. It does not mark T11 done: the acceptance line also requires the critical issues to be fixed, and they are not.

`flutter test` and `supabase test db` were not re-run. This environment has no Flutter SDK and no Docker. Rows that say "code" were confirmed by reading the cited file. Rows that say "live" were confirmed in a browser or by HTTP.

Severity: **Blocker** stops a critical journey on the published site. **High** breaks a core promise (auth, privacy URL, saved data, or a fake success on a primary form). **Medium** is a wrong path, a stub, or an accessibility gap with a workaround. **Low** is copy or a dead option.

## Critical journeys

| ID | Journey | Role | Steps | Result on 2026-10-29 | Notes |
| --- | --- | --- | --- | --- | --- |
| J01 | Cold open | any | Open `https://dippaun.github.io/homizi-app/` and `https://homizi.netlify.app/`. Wait for the shell. | Pass as a demo. Fail as sign-in. | Both land on `/#/home`. Headline observed: "Find a place. Find your people. Rent smarter, live better." No Sign in control. See QA-01. |
| J02 | Pick a role | tenant, host, roommate, broker | On Pages, open the menu and choose Host. | Pass | Menu lists Tenant ("Full room, shared room, or a roommate"), Host ("See seeker demand, or post a flat"), Flatmate ("Find Your Roomie and swipe people"), Broker ("Post a flat, then match it"). Host switches the shell to Seekers, Swipe, Matches, Listings. |
| J03 | Search homes | tenant | Home → Search / Explore. | Pass | `/#/explore` shows cards (example: Koramangala, Bengaluru, rent, deposit, BHK, photo count, "100% Match"). |
| J04 | Filter | tenant | On explore, open Set Your Priorities and use a locality chip. | Pass with a caveat | Chips and a priority form render. Server-side coverage is incomplete (QA-08). |
| J05 | Open a listing from the app | tenant | Tap a card on explore. | Pass | Detail content (price, locality, photos, verified chip) was visible on the card. A full detail scroll was not recorded as a separate case. |
| J06 | Direct listing URL | tenant | Request `/listing/abc` on Pages. | Fail | HTTP 404. Hash routing ignores the path (QA-02). |
| J07 | Sign in with email OTP | new user | Open `/login` on either host. | Fail | URL becomes `.../login#/home`. The login screen does not stay. Code path: `stagingWebSkipsLogin` plus `enterForcedDemo`. |
| J08 | Publish a requirement | tenant | `/requirements?kind=tenant`, submit an invalid brief while demo mode is on. | Fail (code) | Success screen "Brief published" / "The brief is saved for this demo." (`requirement_form_screen.dart`). |
| J09 | Post a listing | host | `/listings/edit` through preview and publish. | Not re-run live | Wizard and `publish_listing` exist. The live session is the on-device demo, so a publish there is not a server publish. |
| J10 | Unsave a home | tenant | Save a listing, then unsave, on a Supabase session. | Fail (code) | `unsaveListing` returns the unsave copy and does not delete the interest (QA-03). |
| J11 | Swipe to a match | tenant | `/discover` like. | Not re-run live | RPC `create_interest` / `create_mutual_match` in `supabase_discovery_gateway.dart`. Demo mode short-circuits many of these to `/demo/done`. |
| J12 | Roommate deck | roommate | Shell tab Roommates. | Not clicked this pass | Supabase RPC path exists. `/roomie` and `/match` are separate local decks (QA-06). |
| J13 | Intelligent match | tenant | Open `/#/match`. | Not clicked this pass | Deck is `demoMatchHomes` only (QA-06). |
| J14 | Owner desk | host | Menu → Host → Owner dashboard / My listings. | Partial | Host home offers those entries. Routes have no role check (QA-07). |
| J15 | Broker desk | broker | Menu → Broker, then Chats. | Fail for chats (code) | Chats are twelve hard-coded people, ids `broker-ananya` through `broker-aditya` (QA-04). |
| J16 | Visits | tenant | Open `/tenant/visits` and tap a row. | Fail (code) | Tap always `go`s to `/matches` (QA-05). |
| J17 | Verification | any | Open `/verify` in demo mode and start. | Fail as proof of identity (code) | Dialog "Verification saved" / "Identity stays on this device for the demo." Live cards still show a Verified chip from the catalog (QA-09). |
| J18 | Legal page | public | Open `/privacy` on both hosts. Also `/terms`, `/support`, `/delete-account` on Pages via HTTP. | Fail | See QA-02. |
| J19 | Account deletion | signed in | `/delete-account`. | Not completed | Page is public in the router. The live path URL does not open it (QA-02). The RPC `delete_own_account` was not called. |
| J20 | Report and block | signed in | `/safety/report`. | Not clicked | Screen is registered. Staff queue `/moderation` needs `staff_roles`. No staff seed. |

## Role permissions

Client redirects are in `lib/core/routing/session_redirect.dart` and `lib/features/broker/broker_auth.dart`. RLS is in `supabase/migrations`. This pass did not log into two real accounts, so the SQL negative tests were not re-executed.

| Case | Expected | What the code does | Live |
| --- | --- | --- | --- |
| Signed out, `/explore` or `/listing/:id` | Public browse | `isPublicBrowse` allows it | Home and explore open inside the forced demo, so this is not a signed-out session on the web hosts |
| Signed out, `/login` on staging web | Sign-in form | `stagingWebSkipsLogin` never returns the login route. `main.dart` calls `enterForcedDemo` | Confirmed. QA-01 |
| Signed out, `/owner` or `/host/leads` on a non-skip build | Login redirect | Any non-public path redirects to login when signed out | Not re-tested off staging web |
| Signed in as tenant, open `/owner` | Hidden or refused | Router builds `OwnerDashboardScreen` with no role check | Not deep-linked this pass. QA-07 |
| Signed in as tenant, open `/broker/chats` | Hidden or refused | `BrokerChatsScreen` has no role check. Shell gates cover only `/home`, `/seekers`, `/listings` | QA-07 |
| Ready session, `/broker` | Broker home | Redirects to `/home`, where the shell gate may show the broker home | Code: `broker_auth.dart` |
| Another user's listing edit | Refused | Supabase load/save filters `host_user_id` | Not re-tested against the hosted DB |
| Contact before a match | Hidden | `get_contact_visibility` is the read path. Public listing JSON is covered by existing widget tests | Not re-tested live |
| Staff queue as a normal user | Empty / denied | RPCs call `is_staff()` | Not re-tested |

## Forms

| Form | Path | Persistence | Defect |
| --- | --- | --- | --- |
| Welcome consent | `/welcome` | Local policy version. RPC `record_consent` when a Supabase user id exists | Skipped on live web because the demo accepts consent inside `enterForcedDemo` |
| Login OTP | `/login` | `verifyOTP` / staging password helpers | Unreachable on live web (QA-01) |
| Role | `/role` | `selectPrimaryRole` → `profiles.primary_role` | Reachable from the menu inside the demo |
| Tenant setup | `/tenant/setup` | `profiles`, `tenant_preferences` | Demo shows success on `AccountFailure` |
| Requirement | `/requirements` | `listing_requirements`, `tenant_preferences`, roommate tables for kind `roommate` | Demo publish with errors shows success (QA-10) |
| Listing wizard | `/listings/edit` | `properties` and child tables, then `publish_listing` | Demo publish is local (`publishedByServer: false`) |
| Photos | `/listings/photos` | Bucket `listing-photos` | Not exercised live (file picker) |
| Broker registration | `/broker/register` | `broker_profiles` and related rows | Demo treats an invalid draft as saved |
| KYC start | `/verify` | `identity_verifications`, function `start-kyc` | Demo returns success without the function (QA-09) |
| Report | `/safety/report` | `reports` | Not submitted |
| Tools (receipt, split, agreement, checklist, deposit) | `/tools/*` | Tool tables when the Supabase gateway is selected | Not submitted. Several screens call `openDemoSuccess` |

Empty, loading, and error widgets exist and have widget tests under `test/widget/shell_screens_test.dart`. They were not walked on every live form.

## Responsiveness

Browser, GitHub Pages, 2026-10-29.

| Viewport | Screens | Result |
| --- | --- | --- |
| about 390px wide | Home, explore, priorities | Layout held. Bottom nav stayed on screen. No horizontal overflow recorded. |
| about 1280px wide | Home, explore | Content uses the width. Listing cards showed Owner and Interested actions. |
| Netlify desktop | Home after the orange loader (about 5s) | Same home as Pages. |

Not checked: `/match` flow, listing wizard, chat, broker desk, and text scale 2.0 on the live canvas. `test/widget/accessibility_scale_test.dart` covers scale 1.6 in widget tests. Those tests were not re-run.

## Privacy

| Check | Evidence | Result |
| --- | --- | --- |
| Legal URLs from `docs/release/WEB.md` | Live `/privacy` on both hosts | Fail. QA-02. The in-app route exists (`lib/features/legal/public_legal_pages.dart`) and is on the public allow-list. |
| Draft banner | `docs/legal/PRIVACY.md`, `docs/legal/TERMS.md` | Copy is still marked draft for legal review. The live page was not shown, so the banner was not seen in the browser. |
| Contact on a public card | Product rule and `contact_visibility_policy.dart` | Explore cards showed rent, locality, and match text. No phone or email was visible on the cards inspected. |
| Street address | `property_private_details` is a separate table | Not selected for the feed in the discovery gateway. Not re-proven with a database query this pass. |
| Secrets in the client | Pages `main.dart.js` | Contains the staging project host (expected for this build) and `demo@homizi.in`. No service-role key was searched for in the response, and none is referenced by the app config loader as a client key. `docs/TEST_ACCOUNTS.md` exists and describes mailboxes. Passwords are not copied into this file. |
| `user_metadata` in RLS | `supabase/migrations` | No matches. |
| `user_badges` | `20261017211500_live_identity_checks.sql` | View is security definer (`security_invoker = false`) and granted to `authenticated`, so it can read contact flags as the owner. The view is documented as booleans only. Treat as a review item (QA-12), not as a confirmed data leak. |
| Demo verified badges | Live explore | "Verified" on catalog homes while the session never completed Digio (QA-09). |
| Welcome KYC copy | `welcome_screen.dart` lines 41–42 | Says checks are mocked and that no face scan is collected. The Supabase gateway can open Digio, and the KYC snapshot model has a face status. Copy is stale (QA-11). |

## Accessibility

| Check | Evidence | Result |
| --- | --- | --- |
| Contrast tokens | `lib/core/theme/homizi_colors.dart` states white on `#F75620` is about 3.3:1 and puts near-black labels on the accent. `test/core/theme/contrast_test.dart` exists. | Tokens are intentional. Not re-measured on the live canvas. |
| Text scale | `test/widget/accessibility_scale_test.dart` | Present, not re-run. |
| Semantics | `Semantics` widgets in home, swipe, requirements, welcome | Partial coverage. Live canvas semantics were not dumped. |
| Keyboard focus | Tab from the Pages home | Focus moved. A visible ring was not apparent (QA-13). `homizi_theme.dart` sets hover and minimum sizes and does not set a focus color. |
| Reduced motion | Welcome reads `MediaQuery.disableAnimationsOf` | Not toggled in the browser. |
| Loader name | `web/index.html` `#homizi-loader` has `role="status"` and `aria-label="Loading HOMIZI"` | Present in the served HTML. |
| Target size | Theme minimum 48px on icon buttons and text buttons | Code only. |

## Defects

### QA-01 — Published web skips sign-in

- Severity: **Blocker**
- Sites: GitHub Pages and Netlify. Source: `main`.
- Repro: Open `https://dippaun.github.io/homizi-app/`. Wait until the orange loader is gone. Look for Sign in. Then open `https://dippaun.github.io/homizi-app/login`.
- Expected: A consent or sign-in screen, and `/login` shows the email code form.
- Actual: Home loads at `/#/home` with the full tenant shell. `/login` ends as `.../login#/home`.
- Evidence: `stagingWebSkipsLogin` in `lib/core/routing/session_redirect.dart`. `lib/main.dart` sets `forceDemoModeProvider` and calls `enterForcedDemo`. `lib/features/session/session_controller.dart` signs `demo@homizi.in` in through `DemoAccountGateway` once that flag is on. `config/staging.json` is what `distribute.yml` and `tool/deploy_web.sh` compile, with `DEMO_SKIP_LOGIN` true and `APP_ENV` staging.

### QA-02 — Legal and other path URLs do not open those screens

- Severity: **High**
- Sites: both. Source: `main` (no `usePathUrlStrategy` under `lib/`).
- Repro (Pages): `curl -sI https://dippaun.github.io/homizi-app/privacy` → HTTP 404. The body is the Flutter shell (same size as `/`). In the browser the address becomes `.../privacy#/home` and the home headline is shown. Repeat for `/terms`, `/support`, `/delete-account`.
- Repro (Netlify): `curl -sI https://homizi.netlify.app/privacy` → HTTP 200 because `netlify.toml` rewrites every path to `index.html`. The browser still shows home at `.../privacy#/home`.
- Expected: The privacy, terms, support, and delete-account pages named in `docs/release/WEB.md`.
- Actual: The Flutter router reads the hash. The path is ignored. Initial route `/splash` continues into the demo home.
- Extra: A direct load of `https://dippaun.github.io/homizi-app/explore` once stopped on `/explore#/splash` (role cards) instead of the explore feed that in-app Search opens at `/#/explore`.

### QA-03 — Unsave does not remove the Supabase interest

- Severity: **High**
- Site: any build that uses `SupabaseDiscoveryGateway` (not the forced demo).
- Repro: Sign in against Supabase with demo mode off. Save a listing (`create_interest` action `save`). Unsave it. Read `interests` for that user and listing.
- Expected: The save row is gone and the heart stays empty after refresh.
- Actual: `unsaveListing` (`lib/features/discovery/supabase_discovery_gateway.dart`) checks the id, then returns `DiscoveryCopy.serverUnsave`. The demo gateway removes the id. The server method does not.

### QA-04 — Broker chats are a fixed cast

- Severity: **High**
- Repro: As a broker, open `/broker/chats`. Tap "Ananya Iyer".
- Expected: Threads from `matches` / `open_conversation` for that broker.
- Actual: `lib/features/broker/broker_chats_screen.dart` lists Ananya Iyer, Rohan Mehta, Meera Krishnan, and nine more with ids `broker-ananya`, `broker-rohan`, and so on. The tap pushes `/matches/broker-ananya/chat`. Those ids are not match UUIDs. On a Supabase thread gateway, `open_conversation` fails for them. In demo mode the chat screen can still render the fixture.

### QA-05 — A visit row opens the match inbox

- Severity: **Medium**
- Repro: Open `/tenant/visits` with at least one visit. Tap the row (chevron is shown).
- Expected: That visit, or its chat, with the same id.
- Actual: `onTap` in `lib/features/tenant/tenant_visits_screen.dart` calls `context.go(RoutePaths.matches)`.

### QA-06 — Three matchers, and `/match` ranks demo homes only

- Severity: **High** for anyone treating `/match` as the product matcher. **Medium** as duplication.
- Repro: Open `/#/match/feed` after changing real listings in Supabase. Compare with `/#/roommates` and `/#/roomie`.
- Expected: One deck of published homes or seekers, with the same hard filters and the same reasons.
- Actual: `/roommates` can call `list_roommate_seekers`. `/roomie` uses `roomie_store.dart`. `tenantMatchCards` in `lib/features/matching/match_catalog.dart` loops `demoMatchHomes` only. `lib/` contains no `rpc('score_compatibility')`. The SQL function still exists for a client that never calls it.

### QA-07 — Host, owner, and broker routes do not check the role

- Severity: **Medium** (client). Server RPCs still filter by `auth.uid()`.
- Repro: In a signed-in tenant session, go to `/#/owner`, `/#/host/leads`, `/#/broker/leads`, `/#/broker/chats`.
- Expected: Redirect to that role's home, or an explanation that the page is for hosts or brokers.
- Actual: `app_router.dart` builds those screens directly. `broker_gates.dart` only swaps the shell branches for home, seekers, and listings.

### QA-08 — Some filters apply only after the page of results

- Severity: **Medium**
- Repro: Against Supabase, set the 1 BHK chip, photos only, and verified hosts only. Compare the SQL request with the cards.
- Expected: The query constrains bedrooms and the two boolean flags.
- Actual: `_propertyQuery` maps `1bhk`–`4bhk` to property types apartment / independent house / villa. Bedrooms, `photosOnly`, and `verifiedHostsOnly` are applied in `ListingFilters.matches` on the returned page (`listing_filters.dart`). A page can under-fill. `listingsVisibleToTenant` also returns every published home, so a saved budget does not hide listings.

### QA-09 — Demo verification and catalog "Verified" chips

- Severity: **Medium**
- Repro: On the live home, open explore. Read the badges. Then, in demo mode, open `/verify` and start.
- Expected: A verified chip only after `identity_verifications` says verified. Start on demo explains that the check did not run.
- Actual: Cards showed "Verified" and "100% Match" during the forced demo (Pages, Koramangala card). `KycScreen._start` (`kyc_screen.dart`) calls `openDemoSuccess` with title "Verification saved" and returns before `start-kyc`.

### QA-10 — Demo forms report success when the draft is invalid or the save failed

- Severity: **Medium**
- Repro: With `demoModeOn`, publish a requirement whose `errors(today)` is non-empty. Repeat for tenant setup on `AccountFailure`, and for broker registration with an invalid draft.
- Expected: The field errors stay on the form. Nothing says the brief was published.
- Actual: `requirement_form_screen.dart` calls `openDemoSuccess` ("Brief published") when `errors.isNotEmpty` and demo and publish. The same helper is used on the tenant setup failure path and the broker registration invalid-draft path.

### QA-11 — Welcome copy disagrees with the KYC gateway

- Severity: **Low**
- Repro: Read welcome slide 2, then `SupabaseKycGateway.start` and `start-kyc/index.ts`.
- Expected: The slide describes Digio when the Supabase path is on, and the demo path when it is not.
- Actual: The slide says "Identity checks are mocked in this build. No Aadhaar number or face scan is collected." The edge function accepts DigiLocker and Aadhaar offline. `KycDocumentKind.pan` has no button path that `start-kyc` will accept (`kinds` is only those two strings).

### QA-12 — `user_badges` is a security-definer view

- Severity: **Medium** until a reviewer confirms the column list on the hosted database. Not demonstrated as a live leak in this pass.
- Repro: Read `supabase/migrations/20261017211500_live_identity_checks.sql`. As `authenticated`, `select * from public.user_badges`.
- Expected: Invoker rights, or a view that cannot see `private_contacts` except through a narrow definer function outside `public`.
- Actual: The view sets `security_invoker = false` and is granted to `authenticated` so badge booleans can be computed from contact rows.

### QA-13 — Keyboard focus is hard to see

- Severity: **Medium**
- Repro: On `https://dippaun.github.io/homizi-app/#/home`, click the page, then press Tab several times.
- Expected: A visible focus ring on the control that has focus (WCAG 2.4.7).
- Actual: Focus moved. No clear ring was visible in the 2026-10-29 browser pass. `lib/core/theme/homizi_theme.dart` does not set `focusColor`.

### QA-14 — GitHub Pages is outside the repo's deploy scripts

- Severity: **Low** for a developer. **High** when combined with QA-02, because the URL in the product brief is the Pages host.
- Repro: Search the repo for `gh-pages` or `github.io`. Compare `origin/gh-pages` (`06bb97b`, "Publish the Step 2 web build") with `main`.
- Expected: The workflow that builds `--base-href /homizi-app/` and a note that path routes need `404.html` plus hash or path strategy.
- Actual: `main` documents Netlify only (`docs/release/WEB.md`, `tool/deploy_web.sh`). Pages was updated the same day as `25841d2` and serves that generation of the app, with the hash-routing bug above.

## Release blockers

These stay open. Do not treat the web hosts as a signed-in production deploy.

1. QA-01. The public sites cannot exercise real sign-in, role permissions, or RLS.
2. QA-02. Privacy, terms, support, and account deletion URLs from the release doc do not render those pages.
3. QA-03. Unsave is a false success on the Supabase gateway.
4. QA-04. Broker chat is fixture data.
5. QA-06. The intelligent matcher does not read published listings.
6. QA-10. Demo mode reports successful publishes for invalid drafts.

## Retest after a fix

| Fix | Check |
| --- | --- |
| QA-01 | Staging web shows `/login`. A wrong code does not open home. A real staging session can open `/tenant` and is refused from another user's listing. |
| QA-02 | `https://dippaun.github.io/homizi-app/#/privacy` and the path form named in the release doc both show the draft privacy title. Pages returns 200 for the document or documents the hash URL. Netlify matches. |
| QA-03 | Unsave deletes the `interests` row. Refresh keeps the heart empty. Widget test covers the gateway. |
| QA-04 | Broker chat ids are match UUIDs from the signed-in broker's inbox. A stranger's thread is absent. |
| QA-05 | The visit row opens that visit. |
| QA-06 | `/match/feed` changes when a published listing changes. One nav entry is the matcher. |
| QA-09 | Demo start does not say "Verification saved" unless a check ran. Catalog badges say demo. |
| QA-13 | Tab shows a ring at 390px and 1280px on home, explore, and a form. |
