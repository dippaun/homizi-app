# Privacy notice

DRAFT FOR LEGAL REVIEW — not approved.

This file is a placeholder so the product can describe what the current build does. It is not legal advice, it has not been reviewed by counsel, and it must not be published or linked as the live policy. The welcome screen still records policy version `2026-10-11-draft` only. The still-blocked table in `DECISIONS.md` stays in force.

## What this build handles

- A phone number or email address used to sign in, when a Supabase project is connected. In demo mode that contact stays on the device.
- A display name, occupation, and bio on the tenant or host profile. Profile writes do not include a phone, an email, or a verification result.
- A requirement: city, locality, budget, occupancy, and move-in date. It does not ask for gender, religion, caste, or age, and it does not collect a street address.
- A listing: title, city, locality, rent, deposit, furnishing, property type, and photos. Photos in demo mode stay on the device. With a project connected they go to a private bucket and stay pending review.
- Likes, passes, saves, matches, chat messages, and visit times. Chat refuses a phone number or an email address. A visit does not store a street address.
- A report and an optional block. A staff account can review a report. No moderator is named in this build.
- Product counts, when the Settings switch is on and a project is connected: an event name and, at most, a listing id or a match id. Not a phone number, an email address, or a name. Turning the switch off stops new events for that session. Error reporting stays off unless the build was compiled with a Sentry DSN, which is not in this repository.
- An in-app notification with ids only. A device token is stored only when Firebase is compiled into the build.
- A public map point rounded to a locality. The exact coordinate stays private until a visit is agreed.
- A test-mode payment row between a match: amount, kind, and status. No card number.
- An agreement draft and e-sign status. A sandbox identity row: status, provider reference, and last 4 characters.
- A home-service request: city, locality, date, size, and a note. No phone number on that row.

## What this build does not do

- It does not collect an Aadhaar number, a face scan, or a document image. A sandbox result is not a government identity proof.
- A test-mode payment does not collect money. Live payment keys are refused.
- It does not send the development code `000000` as an SMS or an email.
- It does not call a production backup, an analytics vendor, or a payment provider when an account is deleted. Deletion removes the account on this device or on the connected local server.

## Contact between two people

One person can share their own phone, email, or both, for a single match. The other person's contact appears only when the server says it is visible. Sharing does not reveal the other person's contact. A block hides contact even after consent.

## Retention

No retention period is approved. Do not treat this draft as a retention schedule.
