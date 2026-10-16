# Product spec

Description of the HOMIZI build in this repository. This is not a new owner approval. Approved choices stay in [DECISIONS.md](DECISIONS.md). Items that still need the owner, a lawyer, finance, or a vendor stay in that file’s still-blocked table and in [plan/PLAN_DIFF.md](plan/PLAN_DIFF.md).

## Who it is for

Tenants and hosts in Indian cities looking for a rental or a flatmate. One account can be a tenant, a host, or both (PD-02).

## Minimum slice in this build

- Welcome consent records a draft policy version. The legal text is not approved.
- Sign-in. Demo mode accepts `000000` only when the build allows the development code. Production refuses it. No SMS is sent.
- Tenant profile, host profile, and a mock verification state. No Aadhaar number and no face capture.
- A requirement: city, locality, budget, move-in date, occupancy. Gender, religion, caste, age, and marital status are not collected for scoring.
- A listing: title, city, locality, rent, deposit, furnishing, type, amenities, at least three photos, preview, and server-side publish checks. The public card has no street address, phone, or email.
- Explore with search, filters, rent sort, and pages of eight homes. Discover is a deck of the same filtered homes.
- Like, pass, and save. A mutual like creates a match. A later pass does not remove it (PD-03).
- Contact stays hidden until there is a match and the other person has shared their own phone, email, or both (PD-04).
- Chat refuses a phone number or an email. A visit is one to three start times, not an address.
- In-app notices for a match, a message, or a visit. Push is not connected.
- Report and block. Reports are stored. A person in `staff_roles` can review them, hide a listing, and suspend an account. No staff user is seeded.
- Account deletion on this device, and on the connected database when Supabase is configured.
- English and Hindi for the buttons, help, and demo home titles.

## Deferred

Real payments, real identity verification, production Supabase, push delivery, store submission, staffed moderation, approved legal text, and production backups. See DECISIONS.md.

## Demo mode

Empty `SUPABASE_URL` or `SUPABASE_ANON_KEY` keeps data on the device. The offline catalog has forty homes across Bengaluru, Pune, Mumbai, Hyderabad, and Delhi NCR. Contact details are never on those cards.
