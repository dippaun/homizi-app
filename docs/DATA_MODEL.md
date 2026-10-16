# Data model

The tables are created in `supabase/migrations/20261011120000_homizi_schema.sql`. Later migrations add photo limits, chat, visits, notifications, and account deletion. Clients do not write status, interests, matches, payments, or verification state except through the granted functions.

## People

`users`, `profiles`, `private_contacts`, `host_profiles`, `tenant_preferences`, `consent_records`, `staff_roles`.

Phone and email live in `private_contacts`. There is no Aadhaar column and no payment-card column.

## Listings

`properties` holds the public fields: title, locality, city, rent, deposit, furnishing, type, and status. `property_private_details` holds the street address and is not selected for the feed. `property_features` and `property_photos` hang off the property. Photo `sort_order` 0 is the primary image. Files go in the private `listing-photos` bucket at `{userId}/{propertyId}/{fileId}.{ext}`.

`listing_requirements` is the tenant brief.

## Matching and contact

`interests` records like, pass, and save. `matches` is the mutual match. `contact_consents` records who shared a phone, an email, or both for one match. `get_contact_visibility` is the only read that may return a phone or an email, and only when the rules pass.

`public.score_compatibility` scores a home from budget, city, locality, furnishing, and property type (PD-06). The arguments do not include gender, religion, caste, age, or marital status. Demo mode runs the same rules in `lib/features/discovery/domain/compatibility.dart`.

## Conversation

`conversations`, `messages`, `visit_requests`, `notifications`. A message cannot contain a phone number or an email address. A visit stores start times only. A notification payload is ids, not the message body. `messages` is in the `supabase_realtime` publication when that publication exists, with full replica identity so a client can filter one conversation. A block still removes the row from the listener.

## Safety and money

`reports`, `blocks`, `audit_events`. `subscriptions` and `payments` are placeholders. Clients cannot write them.

`staff_list_reports`, `staff_review_report`, `staff_hide_listing`, and `staff_suspend_user` are the staff path. Each one checks `staff_roles`. Hiding a listing sets `properties.status` to `paused`. Suspending a user sets `users.status` to `suspended` and pauses that user's published listings. The queue payload is ids, a reason, and a status. Audit metadata is the new status. No phone or email is returned. No staff row is seeded.

`analytics_events` stores `app_open`, `listing_view`, `interest_sent`, `match_opened`, and `message_sent`. Properties may only be a `listing_id` or `match_id` UUID. The signed-in person can insert their own row. Only staff can select. `analytics_funnel`, `analytics_funnel_steps`, and `analytics_funnel_daily` are security-invoker views, so a member does not see another person's counts.

## Deletion

`delete_own_account` removes the signed-in user on this database, their listings, related rows, and their objects in `listing-photos`. It does not call an outside vendor.
