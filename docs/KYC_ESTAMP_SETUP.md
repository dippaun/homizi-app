# E-stamp, e-sign, and identity checks

The default adapter is a demo. Digio is used only when `DIGIO_CLIENT_ID` and `DIGIO_CLIENT_SECRET` are set on the Edge Functions. No key is in the repo.

## What is stored

`identity_verifications` stores a status, a provider (`demo` or `digio`), a document kind (`digilocker`, `aadhaar_offline`, or `pan`), a provider reference, and `masked_last4` (exactly four characters). It does not store an Aadhaar number, a document, or a face image. A 12-digit run in the reference or the mask is rejected.

`verification_status` on this table (`pending`, `verified`, `rejected`) is written only by `apply_verification_result`, which is granted to `service_role`. A signed-in user can record consent (`record_kyc_consent`) and nothing further. A trigger refuses those statuses when the JWT role is `authenticated` or `anon`.

`profiles.verification_status` stays the existing mock enum. This slice does not add enum values there.

`agreements` tracks a draft through e-sign: `draft`, `sent`, `tenant_signed`, `owner_signed`, `completed`, `declined`, `expired`. `source_draft_id` is a uuid with no foreign key, so a draft table from another slice can be linked later. Demo signatures use `demo_sign_agreement`. Digio status changes go through `apply_esign_result`.

## Edge Functions

| Function | JWT | Role |
| --- | --- | --- |
| `start-kyc` | yes | With Digio secrets, creates a sandbox KYC request and sets `pending`. Without them, records a demo `verified` result (`demo-kyc`, mask `4821`). |
| `kyc-webhook` | no | Header `x-homizi-provider-secret` must match `DIGIO_WEBHOOK_SECRET` (or `DIGIO_CLIENT_SECRET`). Applies the status. |
| `create-esign` | yes | With Digio secrets, uploads the draft and marks `sent`. Without them, calls `send_agreement`. |
| `esign-webhook` | no | Same provider secret. Updates agreement status. |

Secrets: `DIGIO_CLIENT_ID`, `DIGIO_CLIENT_SECRET`, optional `DIGIO_WEBHOOK_SECRET`, optional `DIGIO_BASE_URL` (default `https://ext.digio.in`).

## Legal and compliance

- This is not a completed KYC programme. Sandbox and demo results are not a government identity proof.
- Do not collect or log a raw Aadhaar number, an e-Aadhaar PDF, or a DigiLocker document. The provider holds those. HOMIZI keeps the reference and the last four characters.
- E-stamp and e-sign have state stamp-duty rules. A demo agreement is not stamped or registered. A Digio sandbox document is not a registered leave-and-licence.
- Consent is collected in the app before a check starts. The consent row is the status `consent_given` and `consented_at`.
- Deleting an account removes the verification row with the user. It does not call Digio to delete a provider file. That call stays out until a reviewed deletion programme exists.
- Do not put identity numbers in agreement titles or bodies. The database rejects `@` and a 12-digit run.
