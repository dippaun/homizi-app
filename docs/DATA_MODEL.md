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

`conversations`, `messages`, `visit_requests`, `notifications`. A message cannot contain a phone number or an email address. A visit stores start times only. A notification payload is ids, not the message body.

## Safety and money

`reports`, `blocks`, `audit_events`. `subscriptions` and `payments` are placeholders. Clients cannot write them.

## Deletion

`delete_own_account` removes the signed-in user on this database, their listings, related rows, and their objects in `listing-photos`. It does not call an outside vendor.
