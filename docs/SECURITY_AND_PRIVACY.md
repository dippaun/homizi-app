# Security and privacy

This file records the controls that exist in the repo. It is not a completed audit and it is not legal advice. The privacy notice and terms in `docs/legal/` are drafts.

| Gate | What the repo does | What is still open |
| --- | --- | --- |
| S-01 Secrets | `tool/secret_scan.dart` fails the build on private keys, live secret prefixes, and assigned service-role values. The app takes only the public anon or publishable key. | A hosted project’s real keys stay off this repo. |
| S-02 Authorization | Row level security and `supabase/tests/` deny cross-user reads and direct writes to interests, matches, payments, and listing status. | A named reviewer has not signed an audit. |
| S-03 Contact | Hidden results drop phone and email. Widget tests and SQL tests cover that. The UI is not the only gate. | — |
| S-04 Identity | Mock status only. No Aadhaar or face image is stored. | A provider, a lawful basis, and a privacy review. |
| S-05 Uploads | JPEG, PNG, and WebP only, size cap, owner path, moderation stays `pending`. | — |
| S-06 Deletion | `delete_own_account` removes the local account, listings, and that user’s listing photos. | It does not call a payment, identity, analytics, or backup vendor. |
| S-07 Moderation | Reports and blocks work. Report text cannot carry a phone or an email. | No one is assigned to read the queue. |
| S-08 Payments | Clients cannot write payments or turn a client flag into a paid entitlement. | No gateway and no webhooks, because payments are deferred. |
| S-09 Backups | Not implemented for production. | Needs a hosted project and an operations owner. |
| S-10 Store forms | Draft listing and legal text exist and are marked not for submission. | Declarations must be filled from the real SDK list at submission time. |
| S-11 Rollback | [ROLLBACK.md](ROLLBACK.md). | Halting a Play rollout needs Play Console access. |

Discovery requires a session (PD-05). Anonymous clients cannot read listings. Compatibility scoring does not use gender, religion, caste, age, or marital status (PD-06).
