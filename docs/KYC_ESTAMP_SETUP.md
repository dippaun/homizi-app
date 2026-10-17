# Identity verification and e-stamp

Aadhaar and face verification are live. The app calls `start-kyc`. That function calls Digio production when the production secrets below are set. If they are not set, `start-kyc` returns HTTP 503 `{ "ok": false, "error": "verification_unavailable", "message": "verification temporarily unavailable" }`. The app shows **Verification is coming soon**. The Aadhaar and face badges stay unverified. The app never marks a pass on its own.

No Digio key belongs in this repository, in `config/`, or in a `--dart-define`.

## What HOMIZI stores

`identity_verifications` stores:

- status (`not_started`, `consent_given`, `pending`, `verified`, `rejected`)
- `aadhaar_status` and `face_status` (`not_started`, `in_progress`, `verified`, `failed`)
- timestamps (`consented_at`, `started_at`, `aadhaar_verified_at`, `face_verified_at`)
- the Digio request id in `provider_reference`
- `masked_last4` (exactly four characters)

It does not store a full Aadhaar number, an e-Aadhaar PDF, a DigiLocker file, or a face image. A 12-digit run in the request id or the mask is rejected.

`aadhaar_status`, `face_status`, and `verification_status` of `pending`, `verified`, or `rejected` are written only by `apply_kyc_checks`, which is granted to `service_role`. A signed-in user can record consent (`record_kyc_consent`) and can delete their own row (`delete_my_verification`). They cannot insert or update the table. A trigger also refuses those status changes when the JWT role is `authenticated` or `anon`.

`user_badges.aadhaar_verified` and `user_badges.face_verified` are true only when those statuses are `verified`. The view does not expose the mask or the request id.

Paste `docs/staging_apply_H_1017.sql` into the Supabase SQL editor for a project that already has the earlier staging scripts. It matches `supabase/migrations/20261017211500_live_identity_checks.sql` and can be run again.

## Edge Functions

| Function | JWT | Role |
| --- | --- | --- |
| `start-kyc` | yes | Requires a consent row, then creates a Digio KYC request for DigiLocker or Aadhaar offline e-KYC plus the face check in the same template. Returns a gateway URL. Does not return a mode. |
| `kyc-webhook` | no | Requires header `X-Digio-Checksum`, the hex HMAC-SHA256 of the raw body. Updates Aadhaar and face status for the stored request id. Ignores a body that does not match a request HOMIZI created. |

Deploy both after the migration:

```bash
supabase functions deploy start-kyc
supabase functions deploy kyc-webhook
```

Webhook URL to register with Digio:

`https://<project-ref>.supabase.co/functions/v1/kyc-webhook`

## Secrets

Set these in the Supabase dashboard under Edge Functions, or with `supabase secrets set`. Do not commit the values.

| Secret | Required | Purpose |
| --- | --- | --- |
| `DIGIO_CLIENT_ID` | yes | Production client id from the Digio dashboard. |
| `DIGIO_CLIENT_SECRET` | yes | Production client secret. Also the webhook HMAC key when `DIGIO_WEBHOOK_SECRET` is empty. |
| `DIGIO_WEBHOOK_SECRET` | recommended | HMAC key Digio uses for `X-Digio-Checksum`. |
| `DIGIO_KYC_TEMPLATE` | yes | Template name that includes Aadhaar (DigiLocker or offline e-KYC) and a selfie liveness check with face match against the Aadhaar photo. |
| `DIGIO_TEMPLATE_DIGILOCKER` | no | Overrides the template when the person chooses DigiLocker. |
| `DIGIO_TEMPLATE_AADHAAR_OFFLINE` | no | Overrides the template when the person chooses Aadhaar offline e-KYC. |
| `DIGIO_ENV` | no | Read only on the server. Defaults to `production`. The app cannot send this. Leave it unset or set `production`. |
| `DIGIO_BASE_URL` | no | Leave unset. Production calls `https://api.digio.in` and opens `https://app.digio.in`. Set an `https://` host only if Digio gives you a different production API host. |

`DIGIO_ENV` is not a client switch. If it is set to anything other than `production` and `DIGIO_BASE_URL` is empty, `start-kyc` returns `verification_unavailable` instead of calling another environment.

## Getting production keys

1. Create a Digio business account at [https://www.digio.in](https://www.digio.in) (Enterprise / API access, not a personal trial login).
2. Complete Digio's business KYC. They typically ask for the company PAN, GST registration, certificate of incorporation, an authorised signatory, a cancelled cheque or bank proof, and a short description of the product. Describe HOMIZI as a rental and flatmate app that verifies tenants and owners before they share a home.
3. Sign Digio's services agreement. Ask them for the current per-check rate card before you go live. DigiLocker or offline Aadhaar, and the selfie liveness plus face match, are priced per completed check. The rate is on that agreement, not in this repo. Budget for both checks, because each verification runs them together.
4. In the Digio production dashboard, create one KYC template:
   - Aadhaar via DigiLocker, or Aadhaar offline e-KYC if DigiLocker is not the path you contracted.
   - Selfie with liveness, and face match against the Aadhaar photograph, in the same template.
   - Copy the template name into `DIGIO_KYC_TEMPLATE`. If you contract both Aadhaar paths, create two templates and set `DIGIO_TEMPLATE_DIGILOCKER` and `DIGIO_TEMPLATE_AADHAAR_OFFLINE`.
5. Create production API credentials. Copy the client id and client secret into `DIGIO_CLIENT_ID` and `DIGIO_CLIENT_SECRET`. Do not put sandbox credentials in these secrets.
6. In Digio, set the webhook URL above and a webhook secret. Copy that secret to `DIGIO_WEBHOOK_SECRET`. The signature is hex HMAC-SHA256 of the raw request body, sent as `X-Digio-Checksum`.
7. Whitelist the return URL `https://homizi.netlify.app/verify` (and any other production origin you serve). The app appends it when it opens Digio. Android opens the same HTTPS flow in the browser and reads the result when the person comes back.
8. Set `DIGIO_ENV` to `production` or leave it unset. Do not set `DIGIO_BASE_URL` unless Digio's production API host is different from `https://api.digio.in`.
9. Deploy `start-kyc` and `kyc-webhook` again after the secrets are saved so the functions pick them up.
10. Run one real check with a founder account. Confirm the webhook moves `aadhaar_status` and `face_status` to `verified`, the profile shows **Aadhaar verified** and **Face verified**, and `identity_verifications` has only the last 4 digits.

Until step 10 succeeds, the app keeps showing **Verification is coming soon** and the badges stay off.

## What the person does

1. Opens **Verify identity** and reads the consent (purpose, Digio as the processor, what HOMIZI stores, and the right to delete).
2. Chooses DigiLocker or Aadhaar offline e-KYC and ticks the consent box.
3. HOMIZI records consent, then `start-kyc` opens Digio.
4. Digio collects the Aadhaar check and the selfie. Liveness and the match to the Aadhaar photo happen in that Digio flow.
5. Digio calls `kyc-webhook`. The badges change only after that write.
6. **Delete verification data** removes the HOMIZI row. Deleting the account removes it too, because the row is `on delete cascade`. Ask Digio to erase their copy under your agreement. This app does not send the photo or the full number to its own storage, so there is no HOMIZI file to delete.

## E-stamp and e-sign

`create-esign` and `esign-webhook` are unchanged. With the same Digio client id and secret they upload a draft and mark it sent. Without those secrets, `create-esign` still calls `send_agreement` for the on-platform draft flow. E-stamp and e-sign follow state stamp-duty rules. A draft in HOMIZI is not a registered leave-and-licence until Digio, or the state, says it is stamped and signed.

Do not put an Aadhaar number or an email address in an agreement title or body. The database rejects `@` and a 12-digit run.
