# HOMIZI screenshots (latest work)

Updated 13 Nov 2026 · Master round in progress (top section, not merged) · sections 1–4 below are live; section 5 (PR 61) is being replaced by the Master round profile module.

Live site: https://dippaun.github.io/homizi-app/ · login test5@homizi.in / 000000

<!-- MASTER START -->
## Master round (13 Nov 2026), NOT merged yet

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

