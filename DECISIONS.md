# Product decisions

Approved by the owner (deep) on 12 October 2026. These replace the earlier defaults that were recommendations only.

## Approved

| ID | Decision | Record |
| --- | --- | --- |
| PD-01 | Placeholder palette | Keep seed teal `#1F6F6A`, clay `#C4553A`, ink `#1C2430`, and sand `#F6F1EA` until brand assets arrive. Do not invent a new logo or type system. |
| PD-02 | One account, both roles | One account may hold tenant and host. The role screen offers tenant, host, and both. |
| PD-03 | Pass after a match | A pass does not unmatch. An active match stays until an account is deleted or a later approved rule says otherwise. |
| PD-04 | Contact consent | The person shares their own phone, email, or both, for one match. The other person's contact appears only when `get_contact_visibility` returns it. Share and stop share call `grant_contact_consent` and `revoke_contact_consent`. Neither call returns a phone or an email. The screen copy is: "Share your own contact. This does not reveal theirs." |
| PD-05 | Discovery requires sign-in | Anonymous clients cannot read listings. The shell stays on welcome or login until a session is ready. |
| PD-06 | Compatibility weights | Budget 40 inside the range, 15 when close, 0 when outside. City 25. Locality 15. Furnishing 10. Property type 10. Gender, religion, caste, age, and marital status are not inputs and are not stored for scoring. |
| PD-07 | Store id | Application id `in.homizi.app`. Android namespace `app.homizi`, because `in` is not a valid Java package segment. |
| PD-08 | Chat contact block | A chat message cannot contain a phone number or an email address. The same check is enforced in the client and by the `messages` constraint. A visit request is one to three start times, not a street address. |

## Still blocked

These stay out until the owner supplies accounts and approvals. Nothing in this list is treated as approved.

| Gate | Blocked on |
| --- | --- |
| Real payments and pricing | Finance and store-policy approval. The payments table stays read-only for clients. |
| Real Aadhaar or identity verification | A provider, a lawful basis, and a privacy review. The app calls the mock function only. |
| Push delivery | A push provider and its credentials. In-app notifications do not register a device token. |
| Production Supabase and production secrets | An approved project, region, and least-privilege secrets. Local demo keys are not production secrets. |
| Store submission | A signed release, privacy labels, screenshots, and an explicit go-ahead. |
| Staffed moderation | A named owner for the report queue. Reports are stored and blocks are enforced. Nobody is assigned to review them. |
| Legal policy text | A qualified review of terms, the privacy notice, and retention. The welcome screen still records a draft version only. |
| Production backups, vendor deletion, and incident response | An operations owner. Local account deletion removes the signed-in user on this device or the connected local server. It does not call a payment provider, an identity vendor, analytics, or a production backup. |
