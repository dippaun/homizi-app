# HOMIZI screenshots (latest work)

Updated 14 Nov 2026 · sections 1–5 below are earlier gallery sets.

Live site: https://dippaun.github.io/homizi-app/ · login test5@homizi.in / 000000

## Listing identity step (14 Nov 2026)

[PR 89](https://github.com/dippaun/homizi-app/pull/89). Step 4 of 8, Verify Your Identity, no longer blocks listing. A verified Aadhaar shows a green Verified state. Otherwise Verify later and Continue both move on. The selfie is optional: camera or upload, with a preview, kept on the device unless the listing-photos bucket already exists. One back control, Homizi colours, and a 4/8 progress bar. `flutter analyze` was clean and `flutter test` passed 687 tests on this change. Phone shots are 390×844 at scale 2.

<p>
<img src="11-listing-identity/01-verify-identity.png" width="240" alt="Verify identity with progress and Aadhaar fields">
<img src="11-listing-identity/02-verify-later.png" width="240" alt="Optional selfie and Verify later">
<img src="11-listing-identity/03-verified.png" width="240" alt="Green Verified state with Continue">
</p>

## Profile, map, and nearby places (14 Nov 2026)

[PR 87](https://github.com/dippaun/homizi-app/pull/87). A finished profile shows green Profile complete. Basic information edits on a full page. Locality typing shows a Places suggestion plus nearby localities. List-a-home nearby rows are editable. Listing detail uses one approximate-area map and a Nearby places preview. 692 tests passed. Phone shots are 390×844 at scale 2. The map shot uses the no-key fallback (the live site draws Google Maps when `MAPS_API_KEY` is set).

<p>
<img src="10-profile-maps/01-profile-complete.png" width="240" alt="Profile complete at 100 percent">
<img src="10-profile-maps/02-basic-information.png" width="240" alt="Full-screen basic information edit">
<img src="10-profile-maps/03-locality-suggestions.png" width="240" alt="Locality autocomplete">
<img src="10-profile-maps/04-nearby-places.png" width="240" alt="Editable nearby places in list a home">
<img src="10-profile-maps/05-listing-map-nearby.png" width="240" alt="Listing map and nearby preview">
</p>

## Auth entry (14 Nov 2026)

[PR 84](https://github.com/dippaun/homizi-app/pull/84). Stacked Login and Signup panels in Homizi colours. 672 tests passed. Phone shots are 390×844 at scale 2.

<p>
<img src="9-auth-entry/01-initial.png" width="240" alt="Initial Login and Signup titles">
<img src="9-auth-entry/02-login.png" width="240" alt="Login form expanded">
<img src="9-auth-entry/03-signup.png" width="240" alt="Signup form expanded">
<img src="9-auth-entry/04-otp.png" width="240" alt="Email code entry">
<img src="9-auth-entry/05-welcome.png" width="240" alt="Welcome confirmation">
<img src="9-auth-entry/06-signup-success.png" width="240" alt="Signup success">
<img src="9-auth-entry/07-rate-limit.png" width="240" alt="Too many codes requested">
</p>

<!-- MASTER START -->
## Master round (13 Nov 2026), now live

8 modules are being built in parallel from your 14-page checklist. Each one appears here as it finishes. These are real screenshots of the running app (not mockups), at 390×844, scale 2.

### D · Properties Lister ([PR 63](https://github.com/dippaun/homizi-app/pull/63)), 515 tests passed

List Your Property → 1/8 to 8/8 → Review & Publish → Published → Find suitable seekers. Nearby distances show "Distance unavailable" until Google Maps is wired in.

<p>
<img src="6-master/D-lister/01-list-start.png" width="240" alt="01-list-start.png">
<img src="6-master/D-lister/02-list-intro.png" width="240" alt="02-list-intro.png">
<img src="6-master/D-lister/03-start-listing.png" width="240" alt="03-start-listing.png">
<img src="6-master/D-lister/04-location.png" width="240" alt="04-location.png">
<img src="6-master/D-lister/04b-location-permission.png" width="240" alt="04b-location-permission.png">
<img src="6-master/D-lister/05-nearby.png" width="240" alt="05-nearby.png">
<img src="6-master/D-lister/06-living.png" width="240" alt="06-living.png">
<img src="6-master/D-lister/07-house-rules.png" width="240" alt="07-house-rules.png">
<img src="6-master/D-lister/08-services.png" width="240" alt="08-services.png">
<img src="6-master/D-lister/09-rent.png" width="240" alt="09-rent.png">
<img src="6-master/D-lister/10-photos.png" width="240" alt="10-photos.png">
<img src="6-master/D-lister/11-review.png" width="240" alt="11-review.png">
<img src="6-master/D-lister/12-published.png" width="240" alt="12-published.png">
<img src="6-master/D-lister/13-find-seekers.png" width="240" alt="13-find-seekers.png">
</p>
### G · Post Analyzer, full-screen property matching ([PR 64](https://github.com/dippaun/homizi-app/pull/64)), 517 tests passed

Full-screen swipe card with the real match % and top 5 reasons, a full-screen preview, an Interested confirmation, and the one shared property card (compact version shown last).

<p>
<img src="6-master/G-post-analyzer/match-interest-sent.png" width="240" alt="match-interest-sent.png">
<img src="6-master/G-post-analyzer/match-preview.png" width="240" alt="match-preview.png">
<img src="6-master/G-post-analyzer/match-swipe-empty.png" width="240" alt="match-swipe-empty.png">
<img src="6-master/G-post-analyzer/match-swipe-reasons.png" width="240" alt="match-swipe-reasons.png">
<img src="6-master/G-post-analyzer/match-swipe.png" width="240" alt="match-swipe.png">
<img src="6-master/G-post-analyzer/property-card-compact.png" width="240" alt="property-card-compact.png">
</p>

### F · Set My Priorities + matching engine ([PR 65](https://github.com/dippaun/homizi-app/pull/65) on top of [PR 62](https://github.com/dippaun/homizi-app/pull/62)), 523 tests passed

Drag-and-drop P1–P9 for tenants, and P1–P8 for hosts and property partners. Matching now applies must-haves first (a budget, gender or occupancy miss caps the score at 39%), then weights by your order. The SQL that saves priorities to the server is written but NOT applied.

<p>
<img src="6-master/F-priorities/01-tenant-priorities.png" width="240" alt="01-tenant-priorities.png">
<img src="6-master/F-priorities/02-tenant-how-it-works.png" width="240" alt="02-tenant-how-it-works.png">
<img src="6-master/F-priorities/03-host-priorities.png" width="240" alt="03-host-priorities.png">
<img src="6-master/F-priorities/04-host-how-it-works.png" width="240" alt="04-host-how-it-works.png">
<img src="6-master/F-priorities/05-partner-priorities.png" width="240" alt="05-partner-priorities.png">
<img src="6-master/F-priorities/06-loading.png" width="240" alt="06-loading.png">
<img src="6-master/F-priorities/07-empty.png" width="240" alt="07-empty.png">
<img src="6-master/F-priorities/08-error.png" width="240" alt="08-error.png">
<img src="6-master/F-priorities/09-saved.png" width="240" alt="09-saved.png">
</p>

### E · Interested Seekers + full-screen seeker preview ([PR 67](https://github.com/dippaun/homizi-app/pull/67)), 517 tests passed

The host picks a city and a property. Match % is scored against THAT property. Tabs are All / Best Matches / Shortlisted. Not a Fit, Maybe Later and Message & Connect (which opens chat) work. Phone, email and verification docs are never shown.

<p>
<img src="6-master/E-seekers/seeker-preview.png" width="240" alt="seeker-preview.png">
<img src="6-master/E-seekers/seekers-list.png" width="240" alt="seekers-list.png">
<img src="6-master/E-seekers/confirm-maybe-later.png" width="240" alt="confirm-maybe-later.png">
<img src="6-master/E-seekers/confirm-message.png" width="240" alt="confirm-message.png">
<img src="6-master/E-seekers/confirm-not-fit.png" width="240" alt="confirm-not-fit.png">
<img src="6-master/E-seekers/seeker-about.png" width="240" alt="seeker-about.png">
<img src="6-master/E-seekers/seeker-compatibility.png" width="240" alt="seeker-compatibility.png">
<img src="6-master/E-seekers/seeker-requirements.png" width="240" alt="seeker-requirements.png">
<img src="6-master/E-seekers/seekers-best.png" width="240" alt="seekers-best.png">
<img src="6-master/E-seekers/seekers-empty.png" width="240" alt="seekers-empty.png">
<img src="6-master/E-seekers/seekers-error.png" width="240" alt="seekers-error.png">
<img src="6-master/E-seekers/seekers-filter.png" width="240" alt="seekers-filter.png">
<img src="6-master/E-seekers/seekers-loading.png" width="240" alt="seekers-loading.png">
<img src="6-master/E-seekers/seekers-shortlist.png" width="240" alt="seekers-shortlist.png">
</p>

### H · Roommate Finder ([PR 68](https://github.com/dippaun/homizi-app/pull/68)), 516 tests passed

Location selector, Find Roommate / My Roommate Matches / My Requirements, the filter sheet, the full-screen card deck with Skip / Maybe / I'm Interested, the full-screen preview with a compatibility breakdown, and It's a match, which opens chat.

<p>
<img src="6-master/H-roommate/01-finder.png" width="240" alt="01-finder.png">
<img src="6-master/H-roommate/02-filters.png" width="240" alt="02-filters.png">
<img src="6-master/H-roommate/03-requirements.png" width="240" alt="03-requirements.png">
<img src="6-master/H-roommate/04-preview.png" width="240" alt="04-preview.png">
<img src="6-master/H-roommate/05-its-a-match.png" width="240" alt="05-its-a-match.png">
</p>

### B · Profile wizard + dashboard ([PR 69](https://github.com/dippaun/homizi-app/pull/69)), 515 tests passed

The 9-step wizard (role, basic info, languages, contact OTP, Aadhaar via Digio with a coming-soon state, private selfie, profile photo, lifestyle, terms), Profile Completed, then the profile dashboard as tenant and host, the My Priorities entry and verification.

<p>
<img src="6-master/B-profile/01-role.png" width="240" alt="01-role.png">
<img src="6-master/B-profile/02-role-selected.png" width="240" alt="02-role-selected.png">
<img src="6-master/B-profile/03-basic.png" width="240" alt="03-basic.png">
<img src="6-master/B-profile/04-basic-filled.png" width="240" alt="04-basic-filled.png">
<img src="6-master/B-profile/05-languages.png" width="240" alt="05-languages.png">
<img src="6-master/B-profile/06-contact.png" width="240" alt="06-contact.png">
<img src="6-master/B-profile/07-contact-verified.png" width="240" alt="07-contact-verified.png">
<img src="6-master/B-profile/08-aadhaar.png" width="240" alt="08-aadhaar.png">
<img src="6-master/B-profile/09-aadhaar-unavailable.png" width="240" alt="09-aadhaar-unavailable.png">
<img src="6-master/B-profile/10-selfie.png" width="240" alt="10-selfie.png">
<img src="6-master/B-profile/11-selfie-captured.png" width="240" alt="11-selfie-captured.png">
<img src="6-master/B-profile/12-photo.png" width="240" alt="12-photo.png">
<img src="6-master/B-profile/13-photo-from-selfie.png" width="240" alt="13-photo-from-selfie.png">
<img src="6-master/B-profile/14-lifestyle.png" width="240" alt="14-lifestyle.png">
<img src="6-master/B-profile/15-terms.png" width="240" alt="15-terms.png">
<img src="6-master/B-profile/16-completed.png" width="240" alt="16-completed.png">
<img src="6-master/B-profile/17-dashboard-tenant.png" width="240" alt="17-dashboard-tenant.png">
<img src="6-master/B-profile/17b-priorities-entry.png" width="240" alt="17b-priorities-entry.png">
<img src="6-master/B-profile/18-dashboard-host.png" width="240" alt="18-dashboard-host.png">
<img src="6-master/B-profile/19-verification.png" width="240" alt="19-verification.png">
</p>

### C · Search + Office Router ([PR 70](https://github.com/dippaun/homizi-app/pull/70)), 522 tests passed

Office location (empty and filled), Search Properties with the 12 filter sections, and the ranked matches list. Google Maps runs only when the key is compiled in; without it, commute shows Distance unavailable.

<p>
<img src="6-master/C-search-office/office-location-filled.png" width="240" alt="office-location-filled.png">
<img src="6-master/C-search-office/office-location.png" width="240" alt="office-location.png">
<img src="6-master/C-search-office/search-matches.png" width="240" alt="search-matches.png">
<img src="6-master/C-search-office/search-properties.png" width="240" alt="search-properties.png">
<img src="6-master/C-search-office/office-autocomplete.png" width="240" alt="office-autocomplete.png">
<img src="6-master/C-search-office/office-minutes.png" width="240" alt="office-minutes.png">
<img src="6-master/C-search-office/office-multiple.png" width="240" alt="office-multiple.png">
<img src="6-master/C-search-office/office-saved.png" width="240" alt="office-saved.png">
<img src="6-master/C-search-office/office-transport.png" width="240" alt="office-transport.png">
<img src="6-master/C-search-office/search-01-occupancy.png" width="240" alt="search-01-occupancy.png">
<img src="6-master/C-search-office/search-02-property-type.png" width="240" alt="search-02-property-type.png">
<img src="6-master/C-search-office/search-03-budget.png" width="240" alt="search-03-budget.png">
<img src="6-master/C-search-office/search-04-location.png" width="240" alt="search-04-location.png">
<img src="6-master/C-search-office/search-05-possession.png" width="240" alt="search-05-possession.png">
<img src="6-master/C-search-office/search-06-gender.png" width="240" alt="search-06-gender.png">
<img src="6-master/C-search-office/search-07-lifestyle.png" width="240" alt="search-07-lifestyle.png">
<img src="6-master/C-search-office/search-08-furnishing.png" width="240" alt="search-08-furnishing.png">
<img src="6-master/C-search-office/search-09-bathroom.png" width="240" alt="search-09-bathroom.png">
<img src="6-master/C-search-office/search-10-amenities.png" width="240" alt="search-10-amenities.png">
<img src="6-master/C-search-office/search-11-rules.png" width="240" alt="search-11-rules.png">
<img src="6-master/C-search-office/search-12-suitable.png" width="240" alt="search-12-suitable.png">
<img src="6-master/C-search-office/search-error.png" width="240" alt="search-error.png">
<img src="6-master/C-search-office/search-loading.png" width="240" alt="search-loading.png">
<img src="6-master/C-search-office/search-matches-empty.png" width="240" alt="search-matches-empty.png">
<img src="6-master/C-search-office/search-progress-confirm.png" width="240" alt="search-progress-confirm.png">
<img src="6-master/C-search-office/search-progress.png" width="240" alt="search-progress.png">
</p>

### A · KERNAL shell: Home, nav, Personalize, More ([PR 71](https://github.com/dippaun/homizi-app/pull/71)), 504 tests passed

Signed-out Home with the four action cards and Explore rentals, More and its services, the appliance request, the skippable Personalize screen, and the new bottom bars for tenants and hosts (Payments removed).

<p>
<img src="6-master/A-shell/01-home-signed-out.png" width="240" alt="01-home-signed-out.png">
<img src="6-master/A-shell/02-home-explore-rentals.png" width="240" alt="02-home-explore-rentals.png">
<img src="6-master/A-shell/03-more.png" width="240" alt="03-more.png">
<img src="6-master/A-shell/04-more-services.png" width="240" alt="04-more-services.png">
<img src="6-master/A-shell/05-appliance-request.png" width="240" alt="05-appliance-request.png">
<img src="6-master/A-shell/06-personalize.png" width="240" alt="06-personalize.png">
<img src="6-master/A-shell/07-nav-tenant-search.png" width="240" alt="07-nav-tenant-search.png">
<img src="6-master/A-shell/08-nav-host-search.png" width="240" alt="08-nav-host-search.png">
</p>

### Master integration (PR 72) — live

Combined eight-module journey after PR 72 was squash-merged to main 607ae0cc and deployed to GitHub Pages (gh-pages 3f33780, md5 5eba498208164cc6878cd9019b3ff8ea). These shots are from the integration branch web build (Maps key was not compiled into that capture). Live: https://dippaun.github.io/homizi-app/

<p>
<img src="6-master/integration/01-home-signed-out.png" width="240" alt="01-home-signed-out.png">
<img src="6-master/integration/01-home.png" width="240" alt="01-home.png">
<img src="6-master/integration/02-personalize.png" width="240" alt="02-personalize.png">
<img src="6-master/integration/03-more.png" width="240" alt="03-more.png">
<img src="6-master/integration/04-login-filled.png" width="240" alt="04-login-filled.png">
<img src="6-master/integration/04-login.png" width="240" alt="04-login.png">
<img src="6-master/integration/04b-after-consent.png" width="240" alt="04b-after-consent.png">
<img src="6-master/integration/05-after-login.png" width="240" alt="05-after-login.png">
<img src="6-master/integration/05-profile-create.png" width="240" alt="05-profile-create.png">
<img src="6-master/integration/05-role.png" width="240" alt="05-role.png">
<img src="6-master/integration/06-profile-me.png" width="240" alt="06-profile-me.png">
<img src="6-master/integration/06-role.png" width="240" alt="06-role.png">
<img src="6-master/integration/07-office.png" width="240" alt="07-office.png">
<img src="6-master/integration/07-profile-create.png" width="240" alt="07-profile-create.png">
<img src="6-master/integration/07-profile-host.png" width="240" alt="07-profile-host.png">
<img src="6-master/integration/08-profile-me.png" width="240" alt="08-profile-me.png">
<img src="6-master/integration/08-search.png" width="240" alt="08-search.png">
<img src="6-master/integration/09-matches.png" width="240" alt="09-matches.png">
<img src="6-master/integration/09-office.png" width="240" alt="09-office.png">
<img src="6-master/integration/10-search.png" width="240" alt="10-search.png">
<img src="6-master/integration/10-swipe.png" width="240" alt="10-swipe.png">
<img src="6-master/integration/11-matches.png" width="240" alt="11-matches.png">
<img src="6-master/integration/11-priorities.png" width="240" alt="11-priorities.png">
<img src="6-master/integration/11-swipe.png" width="240" alt="11-swipe.png">
<img src="6-master/integration/12-list.png" width="240" alt="12-list.png">
<img src="6-master/integration/12-swipe.png" width="240" alt="12-swipe.png">
<img src="6-master/integration/13-priorities.png" width="240" alt="13-priorities.png">
<img src="6-master/integration/13-seekers.png" width="240" alt="13-seekers.png">
<img src="6-master/integration/14-list.png" width="240" alt="14-list.png">
<img src="6-master/integration/14-roommate.png" width="240" alt="14-roommate.png">
<img src="6-master/integration/14-seekers.png" width="240" alt="14-seekers.png">
<img src="6-master/integration/15-chat.png" width="240" alt="15-chat.png">
<img src="6-master/integration/15-seekers.png" width="240" alt="15-seekers.png">
<img src="6-master/integration/16-roommate-actions.png" width="240" alt="16-roommate-actions.png">
<img src="6-master/integration/16-roommate-match.png" width="240" alt="16-roommate-match.png">
<img src="6-master/integration/16-roommate.png" width="240" alt="16-roommate.png">
<img src="6-master/integration/17-chat-thread.png" width="240" alt="17-chat-thread.png">
<img src="6-master/integration/17-chat.png" width="240" alt="17-chat.png">
</p>

<!-- MASTER END -->

## Page flow chart

Page-by-page map of the live app on main `fb610e7`. Orange is a page, yellow is a processing or loading step, green is a confirmation. Each flow page has a Back button to the previous step.

Scrollable full chart (all sections in order):

<p>
<img src="flowchart/homizi_flow_readable.png" width="900" alt="HOMIZI page-by-page flow chart">
</p>

Side-by-side overview: [homizi_flow.png](flowchart/homizi_flow.png) · [SVG](flowchart/homizi_flow.svg) · source [homizi_flow.mmd](flowchart/homizi_flow.mmd)

### Onboarding

<p>
<img src="flowchart/01_onboarding.png" width="720" alt="Onboarding flow: splash, welcome, sign in, home, role picker">
</p>

### Tenant flow

<p>
<img src="flowchart/02_tenant.png" width="560" alt="Tenant flow pages from Smart Matching to Visit booked">
</p>

### Host flow

<p>
<img src="flowchart/03_host.png" width="480" alt="Host flow and listing wizard pages">
</p>

### Broker flow

<p>
<img src="flowchart/04_broker.png" width="480" alt="Broker flow pages from profile to You're all set">
</p>

### Roommate Finder

<p>
<img src="flowchart/05_roomie.png" width="720" alt="Roommate Finder flow">
</p>

### Main app

<p>
<img src="flowchart/06_main.png" width="900" alt="Main app tabs and screens">
</p>

---

## 0. LIVE now (PRs 57–60 merged)

Live md5 `5065261d7e04f018c96110984c7f0c9d` · main `fb610e7` · gh-pages `669c73b`

<p>
<img src="0-live/01-splash.png" width="240" alt="01-splash" title="01-splash">
<img src="0-live/02-sign-in.png" width="240" alt="02-sign-in" title="02-sign-in">
<img src="0-live/03-home.png" width="240" alt="03-home" title="03-home">
<img src="0-live/04-role-picker.png" width="240" alt="04-role-picker" title="04-role-picker">
<img src="0-live/05-tenant.png" width="240" alt="05-tenant" title="05-tenant">
<img src="0-live/06-host.png" width="240" alt="06-host" title="06-host">
<img src="0-live/07-broker.png" width="240" alt="07-broker" title="07-broker">
</p>

## 1. Splash, Google sign-up, Home, role picker

[PR 59](https://github.com/dippaun/homizi-app/pull/59)

<p>
<img src="1-splash-home/01-splash-start.png" width="240" alt="01-splash-start" title="01-splash-start">
<img src="1-splash-home/02-splash-morph.png" width="240" alt="02-splash-morph" title="02-splash-morph">
<img src="1-splash-home/03-splash-logo.png" width="240" alt="03-splash-logo" title="03-splash-logo">
<img src="1-splash-home/04-registration.png" width="240" alt="04-registration" title="04-registration">
<img src="1-splash-home/05-home.png" width="240" alt="05-home" title="05-home">
<img src="1-splash-home/06-create-profile.png" width="240" alt="06-create-profile" title="06-create-profile">
</p>

## 2. Tenant flow

[PR 58](https://github.com/dippaun/homizi-app/pull/58)

<p>
<img src="2-tenant/01-intro.png" width="240" alt="01-intro" title="01-intro">
<img src="2-tenant/02-priorities.png" width="240" alt="02-priorities" title="02-priorities">
<img src="2-tenant/03-host-preferences.png" width="240" alt="03-host-preferences" title="03-host-preferences">
<img src="2-tenant/04-how-matching-works.png" width="240" alt="04-how-matching-works" title="04-how-matching-works">
<img src="2-tenant/05-match-results.png" width="240" alt="05-match-results" title="05-match-results">
<img src="2-tenant/06-match-results-roomies.png" width="240" alt="06-match-results-roomies" title="06-match-results-roomies">
<img src="2-tenant/07-score-explained.png" width="240" alt="07-score-explained" title="07-score-explained">
<img src="2-tenant/08-colour-codes.png" width="240" alt="08-colour-codes" title="08-colour-codes">
<img src="2-tenant/09-happier.png" width="240" alt="09-happier" title="09-happier">
<img src="2-tenant/10-journey.png" width="240" alt="10-journey" title="10-journey">
<img src="2-tenant/11-rank.png" width="240" alt="11-rank" title="11-rank">
<img src="2-tenant/12-browse.png" width="240" alt="12-browse" title="12-browse">
<img src="2-tenant/13-swipe.png" width="240" alt="13-swipe" title="13-swipe">
<img src="2-tenant/14-detail.png" width="240" alt="14-detail" title="14-detail">
<img src="2-tenant/15-its-a-match.png" width="240" alt="15-its-a-match" title="15-its-a-match">
<img src="2-tenant/16-chat.png" width="240" alt="16-chat" title="16-chat">
<img src="2-tenant/17-contact.png" width="240" alt="17-contact" title="17-contact">
<img src="2-tenant/18-documents.png" width="240" alt="18-documents" title="18-documents">
<img src="2-tenant/19-book-visit.png" width="240" alt="19-book-visit" title="19-book-visit">
<img src="2-tenant/20-visit-booked.png" width="240" alt="20-visit-booked" title="20-visit-booked">
</p>

## 3. Host flow + listing

[PR 57](https://github.com/dippaun/homizi-app/pull/57)

<p>
<img src="3-host/01-become-a-host.png" width="240" alt="01-become-a-host" title="01-become-a-host">
<img src="3-host/02-choose-category.png" width="240" alt="02-choose-category" title="02-choose-category">
<img src="3-host/03-complete-profile.png" width="240" alt="03-complete-profile" title="03-complete-profile">
<img src="3-host/04-verify-identity.png" width="240" alt="04-verify-identity" title="04-verify-identity">
<img src="3-host/04b-verify-done.png" width="240" alt="04b-verify-done" title="04b-verify-done">
<img src="3-host/05-additional-details.png" width="240" alt="05-additional-details" title="05-additional-details">
<img src="3-host/06-trust-indicators.png" width="240" alt="06-trust-indicators" title="06-trust-indicators">
<img src="3-host/07-category-profiles.png" width="240" alt="07-category-profiles" title="07-category-profiles">
<img src="3-host/08-responsibility.png" width="240" alt="08-responsibility" title="08-responsibility">
<img src="3-host/09-host-confirmed.png" width="240" alt="09-host-confirmed" title="09-host-confirmed">
<img src="3-host/10-list-intro.png" width="240" alt="10-list-intro" title="10-list-intro">
<img src="3-host/11-start-listing.png" width="240" alt="11-start-listing" title="11-start-listing">
<img src="3-host/12-location.png" width="240" alt="12-location" title="12-location">
<img src="3-host/13-nearby.png" width="240" alt="13-nearby" title="13-nearby">
<img src="3-host/14-living.png" width="240" alt="14-living" title="14-living">
<img src="3-host/15-house-rules.png" width="240" alt="15-house-rules" title="15-house-rules">
<img src="3-host/16-services.png" width="240" alt="16-services" title="16-services">
<img src="3-host/17-rent.png" width="240" alt="17-rent" title="17-rent">
<img src="3-host/18-photos.png" width="240" alt="18-photos" title="18-photos">
<img src="3-host/19-review.png" width="240" alt="19-review" title="19-review">
<img src="3-host/20-published.png" width="240" alt="20-published" title="20-published">
</p>

## 4. Broker flow

[PR 60](https://github.com/dippaun/homizi-app/pull/60)

<p>
<img src="4-broker/01-profile.png" width="240" alt="01-profile" title="01-profile">
<img src="4-broker/02-verify.png" width="240" alt="02-verify" title="02-verify">
<img src="4-broker/03-verify-checked.png" width="240" alt="03-verify-checked" title="03-verify-checked">
<img src="4-broker/04-trust-badge.png" width="240" alt="04-trust-badge" title="04-trust-badge">
<img src="4-broker/05-onboarding-confirmation.png" width="240" alt="05-onboarding-confirmation" title="05-onboarding-confirmation">
<img src="4-broker/06-listing-intro.png" width="240" alt="06-listing-intro" title="06-listing-intro">
<img src="4-broker/07-start-listing.png" width="240" alt="07-start-listing" title="07-start-listing">
<img src="4-broker/08-location.png" width="240" alt="08-location" title="08-location">
<img src="4-broker/09-nearby.png" width="240" alt="09-nearby" title="09-nearby">
<img src="4-broker/10-living.png" width="240" alt="10-living" title="10-living">
<img src="4-broker/11-rules.png" width="240" alt="11-rules" title="11-rules">
<img src="4-broker/12-services.png" width="240" alt="12-services" title="12-services">
<img src="4-broker/13-rent.png" width="240" alt="13-rent" title="13-rent">
<img src="4-broker/14-rent-authorisation.png" width="240" alt="14-rent-authorisation" title="14-rent-authorisation">
<img src="4-broker/15-photos.png" width="240" alt="15-photos" title="15-photos">
<img src="4-broker/16-review.png" width="240" alt="16-review" title="16-review">
<img src="4-broker/17-published.png" width="240" alt="17-published" title="17-published">
<img src="4-broker/18-desk.png" width="240" alt="18-desk" title="18-desk">
<img src="4-broker/19-confirmation.png" width="240" alt="19-confirmation" title="19-confirmation">
</p>

## 5. Profile pages (tenant, owner, broker, roomie)

[PR 61](https://github.com/dippaun/homizi-app/pull/61) (not merged yet)

<p>
<img src="5-profiles/1-tenant-top.png" width="240" alt="1-tenant-top" title="1-tenant-top">
<img src="5-profiles/2-tenant-full.png" width="240" alt="2-tenant-full" title="2-tenant-full">
<img src="5-profiles/3-owner-top.png" width="240" alt="3-owner-top" title="3-owner-top">
<img src="5-profiles/4-owner-full.png" width="240" alt="4-owner-full" title="4-owner-full">
<img src="5-profiles/5-broker-top.png" width="240" alt="5-broker-top" title="5-broker-top">
<img src="5-profiles/6-broker-full.png" width="240" alt="6-broker-full" title="6-broker-full">
<img src="5-profiles/7-roomie-top.png" width="240" alt="7-roomie-top" title="7-roomie-top">
<img src="5-profiles/8-roomie-full.png" width="240" alt="8-roomie-full" title="8-roomie-full">
</p>

