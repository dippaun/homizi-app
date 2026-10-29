# HOMIZI codebase audit (A02)

Read-only inventory of `main` at `25841d2f1a27a0d2ac8ab625ad8a79ad3eea9d15` ("Step 2 + design polish", 2026-10-22 22:00 UTC). No files under `lib/` were changed. Concurrent branches (login restore, shared swipe matcher) are not part of this score.

Checked on 2026-10-29:

- Source, routes, migrations, workflows, and tests in this tree.
- Live web: `https://dippaun.github.io/homizi-app/` (GitHub Pages, `origin/gh-pages` `06bb97b`, 2026-10-22 21:59 UTC) and `https://homizi.netlify.app/`.
- HTTP probes of those hosts. A browser pass of both sites (home, explore, role switch, 390px and 1280px, direct URLs).

This machine has no Flutter SDK and no Docker, so `flutter test` and `supabase test db` were not re-run. Test file names below are evidence that coverage exists, not a fresh green run.

## Labels

| Label | Meaning |
| --- | --- |
| existing | Routes, UI, and a persistence path (Supabase and/or an explicit demo gateway) implement the journey. Open defects are listed in [QA_MATRIX.md](QA_MATRIX.md). |
| partial | A screen exists, and a required piece is local-only, stubbed, or unreachable on the published web build. |
| missing | No route and no implementation found. |

## T01–T13 on this commit

Scores are how far each workbook acceptance line is already true on `25841d2`. This document is the missing T01 artifact; it is not on `main` until the PR merges, so T01 stays at the pre-merge score. Unweighted mean of the thirteen scores: **51**.

| Task | % | One-line evidence |
| --- | --- | --- |
| T01 Audit | 25 | `docs/plan/STATUS_1017.md` audits commit `9914e7d` against a different pipeline. `main` has no current existing/partial/missing inventory for these flows. |
| T02 Freeze MVP criteria | 35 | `docs/PRODUCT_SPEC.md` still treats identity and payments as deferred and does not list a broker role. `lib/features/roles/role_provider.dart` has roommate, tenant, host, and broker, and KYC/payments code is in the tree. No signed freeze from a current audit. |
| T03 Design tokens | 55 | `lib/core/theme/homizi_colors.dart`, `lib/core/theme/homizi_theme.dart`, and `test/core/theme/contrast_test.dart` define a real token set. The accent is `#F75620` (PD-01). The workbook ramp `#FFD20A`–`#88180B` is not applied. |
| T04 Responsive layout | 60 | Live home and explore were usable at 390px and 1280px on 2026-10-29. Empty, loading, and error widgets exist (`test/widget/shell_screens_test.dart`). Keyboard focus was hard to see, and not every core page was resized. |
| T05 Auth and roles | 60 | Email OTP, session restore, consent, and role selection are implemented under `lib/features/auth/` and `lib/features/session/`. Both live hosts skip that screen (`stagingWebSkipsLogin` in `lib/core/routing/session_redirect.dart`, `enterForcedDemo` in `lib/main.dart`). |
| T06 Listings | 70 | Wizard, photos, preview, `publish_listing`, and `host_user_id` ownership checks exist. `SupabaseDiscoveryGateway.unsaveListing` returns success and leaves the interest row in place (`lib/features/discovery/supabase_discovery_gateway.dart`). |
| T07 Search and filters | 65 | `/explore`, `/filters`, sort, saved searches, and empty states exist. Bedrooms, photos-only, and verified-host filters run after the fetch. `listingsVisibleToTenant` keeps every published home (`lib/features/discovery/domain/feed_visibility.dart`). |
| T08 Requirements | 70 | `/requirements` writes `listing_requirements` and mirrors `tenant_preferences` (`lib/features/inventory/supabase_inventory_gateway.dart`). In demo mode a publish with validation errors still opens a success screen (`lib/features/requirements/requirement_form_screen.dart`). |
| T09 Matching | 45 | `lib/features/matching/domain/intelligent_match.dart` ranks with must-haves and reasons. `tenantMatchCards` builds that deck only from `demoMatchHomes` (`lib/features/matching/match_catalog.dart`). The client uses the local scorer in `lib/features/discovery/domain/compatibility.dart`. No `rpc('score_compatibility')` call is under `lib/`. |
| T10 Role journeys | 50 | Tenant, host, broker, and roommate screens are routed. Broker chats are a fixed list of fake threads (`lib/features/broker/broker_chats_screen.dart`). Visit rows always open `/matches` (`lib/features/tenant/tenant_visits_screen.dart`). `/match` is outside the shell nav. |
| T11 QA | 40 | 116 Dart test files and 26 SQL files are in the repo. This pass did not execute them. The live defects in [QA_MATRIX.md](QA_MATRIX.md) are still open, so the "critical issues fixed" bar is unmet. |
| T12 Release | 50 | `.github/workflows/ci.yml`, `distribute.yml`, `netlify.toml`, and `tool/deploy_web.sh` exist, and both public hosts serve the app. GitHub Pages path URLs return HTTP 404. Production Supabase remains deferred in `docs/DECISIONS.md`. The production build was not re-run here. |
| T13 Integration | 40 | `main` contains the Step 2 integration (`25841d2`, PR #30). Swipe, `/roommates`, `/roomie`, and `/match` are separate contracts. Login-restore and swipe-rework work is not in this commit. |

## Stack

Flutter app `homizi` `1.0.0+1` (`pubspec.yaml`). Dart SDK `>=3.12.2 <4.0.0`. CI pins Flutter 3.44.9 (`.github/workflows/ci.yml`). Client state is Riverpod. Navigation is `go_router` (`lib/core/routing/app_router.dart`). Backend client is `supabase_flutter`. Maps use `flutter_map`. Payments client is `razorpay_flutter`. Push client is `firebase_messaging`. Crash reporting is `sentry_flutter`, off unless `SENTRY_DSN` is set.

`lib/main.dart` does not call `usePathUrlStrategy`. The published apps use hash URLs (`/#/home`). `docs/release/WEB.md` describes path URLs such as `/privacy`.

## Routes

Declared in `lib/core/routing/route_paths.dart`. Registered in `lib/core/routing/app_router.dart`, plus `lib/features/matching/match_routes.dart` and `lib/features/roommates/roomie/roomie.dart`.

Initial location is `/splash`. The shell is a `StatefulShellRoute` with nine branches (`lib/features/shell/role_nav.dart`): `/home`, `/explore`, `/roommates`, `/discover`, `/matches`, `/saved`, `/seekers`, `/listings`, `/profile`. Which tabs show depends on `HomiziRole`.

| Area | Paths |
| --- | --- |
| Boot and auth | `/splash`, `/welcome`, `/login`, `/role`, `/demo/done` |
| Public legal | `/privacy`, `/terms`, `/support`, `/delete-account` |
| Home shell | `/home`, `/explore`, `/filters`, `/recently-viewed`, `/saved-searches`, `/discover`, `/matches`, `/saved`, `/profile` |
| Listing | `/listing/:id`, `/listings/edit`, `/listings/photos`, `/listings/preview` |
| Tenant | `/tenant`, `/tenant/setup`, `/tenant/search`, `/tenant/visits`, `/profile/tenant`, `/profile/create`, `/requirements` |
| Roommate | `/roommates`, `/flatmate/mutual`, `/flatmate/rooms`, `/flatmate/person/:id`, `/roomie`, `/roomie/preferences`, `/roomie/preferences/saved`, `/roomie/lifestyle`, `/roomie/priorities`, `/roomie/person/:id`, `/roomie/match/:id`, `/roomie/chat/:id`, `/roomie/explore/:id` |
| Intelligent match | `/match`, `/match/priorities`, `/match/priorities/saved`, `/match/feed`, `/match/swipe`, `/match/commute`, `/match/commute/saved`, `/match/commute/:id`, `/match/signals/reset`, `/match/explained/:id`, `/match/card/:id`, `/match/mutual/:id`, `/match/chat/:id`, `/match/visit/:id`, `/match/visit/:id/done`, `/match/contact/:id`, `/match/contact/:id/done`, `/match/docs/:id`, `/match/docs/:id/done` |
| Host and owner | `/host`, `/host/options`, `/host/onboard`, `/host/seekers`, `/host/leads`, `/host/visits`, `/profile/host`, `/owners`, `/owner`, `/owner/overview`, `/owner/stats/:id` |
| Broker | `/broker`, `/broker/register`, `/broker/seekers`, `/broker/briefs`, `/broker/briefs/:id`, `/broker/listings`, `/broker/listings/:id`, `/broker/leads`, `/broker/leads/:id`, `/broker/chats`, `/broker/visits`, `/broker/visits/:id` |
| Trust and ops | `/verify`, `/payments`, `/agreements`, `/services`, `/services/request`, `/notifications`, `/safety/report`, `/moderation`, `/moderation/service-leads`, `/help`, `/settings`, `/tools` and `/tools/receipt`, `/split`, `/agreement`, `/checklist`, `/deposit` |
| Chat | `/matches/:matchId/chat` |

Session guard: `sessionRedirect` in `lib/core/routing/session_redirect.dart`. It is a client redirect. It does not replace RLS. Public browse without a session is `/home`, `/explore`, `/filters`, and `/listing/:id`. `/profile/create` and `/host/onboard` stay reachable while signed out.

`stagingWebSkipsLogin` is true when the build is web and `APP_ENV` is staging. `lib/main.dart` then enables `forceDemoModeProvider` and calls `enterForcedDemo()`, which signs the on-device demo in as `demo@homizi.in` with the development code (`lib/features/session/session_controller.dart`). `config/staging.json` is the file the web workflows compile (`DEMO_SKIP_LOGIN` is true there). Both live hosts behave as that build: the first screen is the home, and a Sign in control is absent.

## Data model

Baseline tables are created in `supabase/migrations/20261011120000_homizi_schema.sql`. Later migrations add the rest. `docs/DATA_MODEL.md` describes the October 11 core and is behind the later tables (broker, roommate, KYC, payments, owner leads).

| Group | Tables |
| --- | --- |
| People | `users`, `profiles`, `private_contacts`, `host_profiles`, `tenant_preferences`, `consent_records`, `staff_roles`, `broker_profiles`, `roommate_profiles`, `roommate_lifestyle` |
| Listings | `properties`, `property_private_details`, `property_features`, `property_photos`, `listing_requirements`, `localities` |
| Match and contact | `interests`, `matches`, `contact_consents` |
| Conversation | `conversations`, `messages`, `visit_requests`, `notifications`, `notification_preferences`, `device_tokens` |
| Discovery extras | `listing_views`, `saved_searches`, `recent_searches`, `photo_requests`, `saved_search_alert_log` |
| Owner desk | `owner_leads`, `owner_lead_audit` |
| Safety | `reports`, `blocks`, `audit_events`, `analytics_events` |
| Money and services | `subscriptions`, `payments`, `service_leads`, `agreements`, `identity_verifications` |
| Tools | `rent_receipts`, `rent_agreement_drafts`, `move_in_checklists`, `move_in_items`, `deposit_trackers`, `deposit_deductions`, `support_tickets` |
| Staging | `staging_flags` (public). `private.staging_secrets` is not public. |

Views: `analytics_funnel`, `analytics_funnel_steps`, and `analytics_funnel_daily` are `security_invoker`. `public.user_badges` is recreated with `security_invoker = false` so the view owner can read contact flags (`supabase/migrations/20261017211500_live_identity_checks.sql`). `authenticated` can select it.

RLS is enabled on the core tables in `supabase/migrations/20261011120100_homizi_access.sql` and on the later product tables in their own migrations. Policies found in this pass use `auth.uid()` and `public.is_staff()`. No policy in `supabase/migrations` references `user_metadata`. Many RPCs are `SECURITY DEFINER` in `public`, which is the app's access pattern and is worth a dedicated review before production.

Representative RPCs the client is built to call: `create_interest`, `create_mutual_match`, `undo_last_interest`, `publish_listing`, `publish_requirement`, `get_contact_visibility`, `grant_contact_consent`, `open_conversation`, `send_message`, `request_visit`, `list_my_listings`, `get_my_listing_stats`, `set_my_listing_status`, `list_owner_leads`, `set_owner_lead_status`, `seekers_for_my_listings`, `list_roommate_seekers`, `roommate_compatibility_breakdown`, `requirement_listing_match`, `profile_activity`, `record_kyc_consent`, `delete_own_account`. `score_compatibility` exists in `supabase/migrations/20261014170000_score_compatibility.sql` and is mirrored locally. The Flutter tree does not call it.

Edge functions in `supabase/functions/`: `start-kyc` (client), `create-razorpay-order` (client), `create-esign` (client), `kyc-webhook`, `razorpay-webhook`, `esign-webhook`, `send-push`, `notify-service-lead`. Whether those functions are deployed on the hosted project was not re-checked in this pass. `docs/HANDOVER.md` records an earlier gap; `lib/features` agreement code falls back when `create-esign` is missing.

Storage buckets referenced by the client: `listing-photos`, `avatars`.

## Feature inventory

### Tenant — full room, shared room, roommate

**Full room: existing. Shared room: existing. Roommate seeker: partial.**

There is no separate route tree per room type. A full home is an Explore chip and property type (`full_house`, apartment, independent house, villa). A shared room or PG is `shared_room` / `pg`. A private room in a shared flat is `private_room` and the `flatmate` chip. Definitions: `lib/features/discovery/domain/listing_filters.dart`. Tenant preferences store the same types in `lib/features/account/profile_records.dart` and `tenant_preferences`.

| Step | Where |
| --- | --- |
| Role | `lib/features/roles/role_selection_screen.dart` → `HomiziRole.tenant` |
| Home | `/tenant` `lib/features/tenant/tenant_home_screen.dart`. Cards in `lib/features/tenant/tenant_entries.dart` (search, explore, saved, brief, matches, visits). The journey block renders only when the role is tenant (`lib/features/tenant/tenant_journey_section.dart`). |
| Setup | `/tenant/setup` `lib/features/tenant/tenant_setup_screen.dart` |
| Search handoff | `/tenant/search` `lib/features/tenant/tenant_search_screen.dart` writes the filter and opens `/explore` |
| Brief | `/requirements?kind=tenant` `lib/features/requirements/requirement_form_screen.dart` |
| Browse | `/explore` `lib/features/discovery/explore_screen.dart`, detail `/listing/:id` |
| Save and like | `lib/features/discovery/supabase_discovery_gateway.dart` via `create_interest` |
| Visits | `/tenant/visits` `lib/features/tenant/tenant_visits_screen.dart` reads `profile_activity`. Each row's tap target is `/matches`. |

Roommate-as-seeker is `HomiziRole.roommate` plus `/requirements?kind=roommate`, which also writes `roommate_profiles` / `roommate_lifestyle` through `lib/features/roommates/roommate_profile_gateway.dart`. Person discovery is split across three UIs (see Roommate finder).

Demo overlays: `openDemoSuccess` in `lib/features/demo/demo_success.dart`. Tenant setup shows that screen on `AccountFailure` while demo mode is on. Requirement publish does the same when `draft.errors` is non-empty.

### Owner and host

**Existing.** Owner is not a fifth `HomiziRole`. The account role is `host`. Listing writes set `host_profiles.host_category` to `owner` for a host and `broker` for a broker (`lib/features/account/supabase_account_gateway.dart`). The word "owner" is the dashboard.

| Surface | Files |
| --- | --- |
| Host home | `/host` and the shell `/home` gate: `lib/features/host/host_home_screen.dart`, `lib/features/host/host_home_gate.dart` |
| Onboarding | `/host/onboard` `lib/features/host/host_onboarding_screen.dart` |
| Profile | `/profile/host` `lib/features/profile/host_profile_screen.dart` |
| Options, leads, visits, seekers | `/host/options`, `/host/leads`, `/host/visits`, `/host/seekers` |
| Marketing page | `/owners` `lib/features/owner/for_owners_screen.dart` |
| Desk | `/owner` `lib/features/owner/owner_dashboard_screen.dart`, `/owner/overview`, `/owner/stats/:id` |
| Gateway | `lib/features/owner/supabase_owner_gateway.dart`: `list_my_listings`, `get_my_listing_stats`, `set_my_listing_status`, `list_owner_leads`, `set_owner_lead_status` |

Shell `/listings` shows the owner dashboard for a host and the broker list for a broker (`lib/features/broker/broker_gates.dart`). The owner and host routes in `app_router.dart` do not check `HomiziRole.host` before building the page. A signed-in user who knows the path can open them. Server RPCs still scope rows to the caller.

### Roommate finder

**Partial.**

| Surface | Status | Persistence |
| --- | --- | --- |
| Shell tab `/roommates` | existing | `list_roommate_seekers`, `roommate_compatibility_breakdown`, interests. `lib/features/roommates/roommate_screen.dart`, `lib/features/roommates/supabase_roommate_gateway.dart` |
| `/flatmate/person/:id`, `/flatmate/mutual` | existing | Same gateway. Mutual list: `lib/features/roommates/mutual_interest_screen.dart` |
| `/flatmate/rooms` | existing | Filters the discovery feed for shared listings. `lib/features/roommates/shared_rooms_screen.dart` |
| `/discover` people swipe | existing | `lib/features/interest/swipe_screen.dart`, `lib/features/interest/supabase_people_swipe_gateway.dart` (published `listing_requirements`) |
| `/roomie/*` Find Your Roomie | partial | In-memory `lib/features/roommates/roomie/roomie_store.dart` and a local catalog. Home links here from `lib/features/home/home_screen.dart` |
| `/match/*` intelligent match | partial | In-memory `lib/features/matching/match_controller.dart` over `demoMatchHomes` / `demoTenantLeads` |

`/roomie` can mark verified and premium in the demo store (`roomie_store.dart`). Those flags are not a Digio result.

### Broker

**Partial.**

Registration: `/broker/register` `lib/features/broker/broker_registration_screen.dart` writes `broker_profiles`, `private_contacts`, `profiles.primary_role`, and `host_profiles` (`lib/features/broker/broker_providers.dart`). While signed out, broker paths redirect toward login (`lib/features/broker/broker_auth.dart`). On the staging web build that redirect is then rewritten away from `/login`. When the session is ready, `/broker` itself redirects to `/home`, and the shell home gate shows `BrokerHomeScreen`.

| Desk | Path | Backend |
| --- | --- | --- |
| Briefs | `/broker/briefs`, shell `/seekers` | RPC `seekers_for_my_listings` |
| Listings | `/broker/listings`, shell `/listings` | Same owner listing RPCs |
| Leads | `/broker/leads` | `list_owner_leads` |
| Visits | `/broker/visits` | Owner leads plus in-memory notes |
| Chats | `/broker/chats` | Fixed threads `broker-ananya`, `broker-rohan`, and ten more. Tap opens `/matches/<that id>/chat` |

Demo registration treats an invalid draft as saved. Lead and visit actions call `openDemoSuccess` in demo mode. The broker screens do not check `HomiziRole.broker` themselves. The shell gates do, for `/home`, `/seekers`, and `/listings` only.

### Auth

**Partial** on the published web build. **Existing** in the non-web and non-staging code paths.

| Piece | Files |
| --- | --- |
| Welcome consent | `lib/features/onboarding/welcome_screen.dart`. Slide 2 says identity checks are mocked and that no Aadhaar number or face scan is collected. |
| Login | `lib/features/auth/login_screen.dart`. Staging email OTP, optional staging password flag, development code only when `allowsDevOtp` is on. |
| Magic link | `lib/features/auth/magic_link_session.dart` |
| Session | `lib/features/session/session_controller.dart`, `session_state.dart` |
| Restore | `SupabaseAccountGateway.restore` when the gateway is the Supabase one |
| Roles | `lib/features/roles/role_selection_screen.dart`, `selectPrimaryRole` |
| Account deletion | `/delete-account` plus RPC `delete_own_account` |

`accountGatewayProvider` returns `DemoAccountGateway` when Supabase is unconfigured or `forceDemoModeProvider` is on (`lib/features/account/account_providers.dart`). The live web builds turn that flag on before sign-in, so the session the UI uses is the on-device demo even though `Supabase.initialize` still runs when a URL and key are compiled in.

Tests present (not re-run here): `test/features/session/session_controller_test.dart`, `test/core/routing/session_redirect_test.dart`, `test/widget/login_qa_test.dart`, `test/widget/login_staging_test.dart`, `test/widget/role_flow_*`.

### Listings

**Existing.**

Draft and wizard: `lib/features/listings/domain/listing_draft.dart`, `listing_wizard.dart`, `listing_payload.dart`. UI: `listing_editor_screen.dart` (`/listings/edit`), `photo_manager_screen.dart`, `listing_preview_screen.dart`. Controller: `listing_draft_controller.dart`.

Supabase writes: `properties`, `property_photos`, `property_features`, `property_private_details`, bucket `listing-photos`, then RPC `publish_listing` (`lib/features/inventory/supabase_inventory_gateway.dart`). Loads and saves filter on `host_user_id`. Demo saves stay in `DemoListingMemory` and set `publishedByServer: false` (`lib/features/inventory/demo_inventory_gateway.dart`). With `DEMO_SKIP_LOGIN`, providers try the remote call and fall back to the demo copy.

Public cards omit street address and contact (`docs/PRODUCT_SPEC.md`, `lib/features/safety/domain/contact_visibility_policy.dart`). Detail route: `/listing/:id` `lib/features/discovery/listing_detail_screen.dart`.

Known hole: unsave on the Supabase gateway (QA-03).

### Search and filters

**Partial.** The explore journey works on the live site. Several filters never reach PostgREST.

| Piece | File |
| --- | --- |
| Explore UI | `lib/features/discovery/explore_screen.dart` |
| Filter UI | `lib/features/discovery/filter_screen.dart` (`/filters`) |
| Filter model | `lib/features/discovery/domain/listing_filters.dart` |
| Sort | `lib/features/discovery/domain/listing_sort.dart`. "Best match" uses local `listingMatchesProvider` scores. |
| Query | `SupabaseDiscoveryGateway._propertyQuery`: city, locality, budget, furnishing, property type, area, preferred tenant, parking, pets, food, gated, floor, move-in, text |
| After fetch | `applyFilters`: bedrooms, `photosOnly`, `verifiedHostsOnly`, and BHK bedroom checks |
| Saved searches | `saved_searches` and `saved_search_new_count` in `lib/features/explore/supabase_explore_gateway.dart`. Screens: `/saved-searches`, `/recently-viewed` |
| Feed rule | `listingsVisibleToTenant` returns the full published list. Budget and locality score a card. They do not hide one. |

BHK quick chips on the server query restrict `property_type` to apartment, independent house, and villa, and do not send a bedroom predicate (`supabase_discovery_gateway.dart`). The bedroom check is client-side.

Live check, 2026-10-29: from the GitHub Pages home, Search opened `/#/explore` with listing cards (prices, locality, photo counts, a "100% Match" badge). Locality chips and "Set Your Priorities" were on screen. The same explore path worked at 390px and 1280px.

### Requirements

**Existing**, with a demo success hole.

Form: `lib/features/requirements/requirement_form_screen.dart`. Draft rules: `lib/features/requirements/domain/requirement_draft.dart`. Kinds `tenant` and `roommate`. Publish calls `publish_requirement`. The Supabase gateway also upserts `tenant_preferences`. Host and broker read seekers through `seekers_for_my_listings` (`lib/features/roles/seeker_providers.dart`, `lib/features/roles/seeker_matches_screen.dart`).

Gender, religion, caste, age, and marital status are excluded from `score_compatibility` (`docs/DATA_MODEL.md`, migration `20261014170000_score_compatibility.sql`). The live "Set Your Priorities" screen did show a flatmate gender preference and lifestyle chips (non-smoker, non-drinker). Those belong to the roommate / roomie priority UI, which is a different form from the listing score RPC.

Tests present: `test/features/requirements/requirement_draft_test.dart`, `test/features/roles/requirement_match_test.dart`.

### Matching

**Partial.** Three engines.

| Engine | Route | What it ranks | Store |
| --- | --- | --- | --- |
| Listing swipe | `/discover` `lib/features/interest/swipe_screen.dart` | Filtered homes. Badge from local `scoreCompatibility`. | RPC `create_interest`, `create_mutual_match`, `undo_last_interest` |
| Roommate deck | `/roommates` | Seekers, with `roommate_compatibility_breakdown` when Supabase is connected | `interests` |
| Intelligent match | `/match/*` | Must-have misses, weighted factors, commute heuristic, reason strings (`lib/features/matching/domain/intelligent_match.dart`) | `demoMatchHomes` only. `MatchController` does not write Supabase. |
| Listing match on Explore | sort "best match" | `requirement_listing_match` when the remote engine is on, else `lib/features/discovery/domain/listing_match.dart` | optional RPC |

Tests present: `test/features/matching/intelligent_match_test.dart`, `test/features/matching/match_flow_test.dart`, `test/features/discovery/compatibility_test.dart`, `test/features/roommates/roommate_compatibility_test.dart`. They cover the local engines, including rank order on fixture homes. They do not prove the `/match` deck is the published catalog.

Chat refuses phone numbers and emails in `lib/features/chat/` (`send_message`). Contact reads go through `get_contact_visibility`.

### Verification

**Partial.**

| Mode | Behavior |
| --- | --- |
| Demo / forced demo | `KycScreen._start` opens "Verification saved" and returns (`lib/features/verification/kyc_screen.dart`). |
| Offline gateway | `lib/features/verification/offline_kyc_gateway.dart` returns a coming-soon start. |
| Supabase | `lib/features/verification/supabase_kyc_gateway.dart` reads `identity_verifications`, calls `record_kyc_consent`, and invokes `start-kyc`. |
| Edge | `supabase/functions/start-kyc/index.ts` accepts `digilocker` and `aadhaar_offline` and calls Digio. `pan` exists on `KycDocumentKind` in `lib/features/verification/domain/kyc_rules.dart` and is rejected by that function. |

Rules in `kyc_rules.dart` reject storing a 12-digit Aadhaar number in the app. The screen shows masked last-4 and a provider reference when the gateway returns them. Trust chips: `lib/features/trust/user_badges.dart`, `trust_badge_row.dart`. The live explore cards showed "Verified" on demo listings, which is the catalog badge, not a Digio result from this session.

Welcome slide 2 still says the checks are mocked.

## Build and deploy

| Piece | Evidence |
| --- | --- |
| Version | `pubspec.yaml` `1.0.0+1`. Notes in `docs/release/VERSIONING.md`. |
| Analyze and test CI | `.github/workflows/ci.yml`: format, analyze, `flutter test`, `tool/secret_scan.dart`, `tool/dependency_scan.dart`, and a Supabase db job. `docs/release/CI.md` says Origin pushes do not run GitHub Actions. |
| Android distribute | `.github/workflows/distribute.yml` builds APK/AAB and optionally Firebase App Distribution. |
| iOS | `.github/workflows/ios.yml` is `workflow_dispatch` only, `flutter build ios --no-codesign`. |
| Web, documented | `netlify.toml` publishes `build/web` and rewrites `/*` to `/index.html`. `tool/deploy_web.sh` builds with `--dart-define-from-file=config/staging.json`. PWA notes: `docs/release/WEB.md`, `tool/install_web_sw.py`. |
| Web, GitHub Pages | No Pages workflow in this repo. `origin/gh-pages` exists. Live `index.html` has `<base href="/homizi-app/">`. `web/index.html` in git still has the `$FLUTTER_BASE_HREF` placeholder, so the base href is applied at build time and is not committed on `main`. |
| Env examples | `config/env.dev.json.example`, `env.staging.json.example`, `env.prod.json.example`: `APP_ENV`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `POLICY_VERSION`, `SENTRY_DSN`. URL, anon key, and DSN are empty. |
| Compiled staging file | `config/staging.json` adds `SUPABASE_PUBLISHABLE_KEY`, `STAGING_PASSWORD_AUTH`, `STAGING_TEST_PASSWORD` (placeholder text containing `REDACTED`), and `DEMO_SKIP_LOGIN` true. Values are not copied here. |
| Android id | `in.homizi.app` (see `docs/release/ANDROID.md`). Release signing is still the debug config per `docs/plan/STATUS_1017.md`. |

Live HTTP, 2026-10-29:

| URL | Result |
| --- | --- |
| `https://dippaun.github.io/homizi-app/` | 200, Flutter shell, base `/homizi-app/`. Last-Modified 2026-10-22 22:00 GMT. |
| `https://dippaun.github.io/homizi-app/privacy` (and `/terms`, `/support`, `/delete-account`, `/explore`, `/login`, `/listing/abc`) | HTTP 404. Body length matches the app shell (7534 bytes) because `404.html` is that shell. |
| `https://homizi.netlify.app/` and `/privacy` | HTTP 200. Netlify rewrite serves the shell for every path. |
| Browser, both hosts | App settles on `/#/home` with no sign-in screen. `/privacy` and `/login` become `.../privacy#/home` and `.../login#/home`. |

`main.dart.js` on Pages contains the staging project host and the demo mailbox string. It is a staging web build, consistent with `stagingWebSkipsLogin`.

## What is missing

No feature in the requested set is wholly absent. The holes are partial journeys:

- A single roommate matcher shared by `/roommates`, `/roomie`, and `/match`.
- Intelligent match against published listings.
- Broker chat backed by `matches`.
- Sign-in on the public web builds.
- Path URLs for the legal pages the release doc names.
- Workbook yellow-to-red tokens.
- A frozen MVP spec that matches this tree.

Staff moderation UI exists (`/moderation`) and requires `staff_roles`. No staff user is seeded (`docs/PRODUCT_SPEC.md`). That queue stays closed until a row is inserted.
