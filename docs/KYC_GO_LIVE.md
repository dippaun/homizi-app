# Aadhaar + face verification: go-live checklist

The code is complete. Verification turns on by itself the moment the Digio
secrets below exist in Supabase (sandbox keys with `DIGIO_ENV=sandbox` for
testing, or production keys with `DIGIO_ENV` unset). Until then every screen shows
**Verification coming soon**, nothing about Aadhaar is collected, and no badge
can turn green.

Policy the code enforces:

- No demo or mock path in the app. Digio sandbox is an operator choice
  (`DIGIO_ENV=sandbox` function secret) for testing with sandbox keys; the
  client can never pick it. Unset means production.
- Only results that come from Digio can set a check to `verified`: the signed
  `kyc-webhook`, or `start-kyc` `{action: "refresh"}`, which reads the
  person's own stored request from Digio's `/client/kyc/v2/{id}/response`
  server to server. The app and a signed-in user cannot write a result.
- HOMIZI stores the result, timestamps, the Digio request id, and the last 4
  digits of Aadhaar. Never the full number, the document, or the selfie.
- The Digio return address is chosen on the server from an allowlist. It
  defaults to the live app: `https://dippaun.github.io/homizi-app/#/verify`.

## 0. Sandbox first (what we asked Digio for)

When Digio sends **sandbox** client id + secret:

1. Create the KYC template in the **sandbox** dashboard (step 3 below).
2. Set function secrets: `DIGIO_CLIENT_ID`, `DIGIO_CLIENT_SECRET`,
   `DIGIO_TEMPLATE_NAME` (the template name), `DIGIO_ENV=sandbox`, and
   optionally `DIGIO_WEBHOOK_SECRET`.
3. Deploy the two functions (step 8). The app switches on by itself; hosts
   used are `https://ext.digio.in:444` (API) and `https://ext.digio.in`
   (gateway), per Digio's environments page.
4. The webhook is optional for sandbox: while the screen shows "Checking
   with Digio" it polls `start-kyc` `refresh`, which asks Digio directly.
5. Sandbox results are test data but still turn the badge green on the
   project they run against. Delete them (Delete verification data) before
   real users see that project, and switch to production keys with
   `DIGIO_ENV` unset for launch.

## 1. Get Digio API access (you have DigiDocs e-sign only today)

A DigiDocs login is the e-sign product. Aadhaar KYC needs Digio's
**Enterprise / API** access with the **KYC (DigiLocker / Aadhaar offline +
face match)** product enabled.

1. Contact Digio (DigiDocs dashboard → Help / contact form, the "Contact
   sales" form on digio.in, or your account manager) and ask for: "API access for KYC: Aadhaar via DigiLocker
   and Aadhaar Offline XML, with selfie liveness and face match, production
   environment, plus webhooks." Mention you are an existing DigiDocs customer.
2. Ask for the current per-check rate card (DigiLocker / offline Aadhaar, and
   liveness + face match are usually billed per completed check).
3. Sign the services agreement and DPA they send.

## 2. Business KYC documents Digio usually asks for

- Company PAN, and certificate of incorporation (or partnership deed / sole
  proprietor proof)
- GST registration certificate (if registered)
- Authorised signatory's PAN + Aadhaar/ID and a board resolution or
  authorisation letter
- Cancelled cheque or bank statement in the business name
- Registered office address proof
- Website / app link (`https://dippaun.github.io/homizi-app/`) and a short use
  case: "HOMIZI is a rental and flatmate app. We verify tenants, owners and
  roommates with Aadhaar and a live selfie before they meet or share a home.
  We store only the result and the last 4 digits."
- Privacy policy URL that mentions Digio as the KYC processor

## 3. Create the KYC template (Digio production dashboard)

1. KYC → Templates → New template.
2. Add an **Aadhaar** step: DigiLocker (recommended) and/or Aadhaar Offline
   XML.
3. Add a **Selfie** step with **liveness** and **face match against the Aadhaar
   photo**, in the same template.
4. Link expiry: 10 days (the app treats an older pending request as expired).
5. Save. Copy the template name.
   - One template for both paths → `DIGIO_KYC_TEMPLATE`.
   - Separate templates → `DIGIO_TEMPLATE_DIGILOCKER` and
     `DIGIO_TEMPLATE_AADHAAR_OFFLINE` (keep `DIGIO_KYC_TEMPLATE` as the
     fallback).
6. Allow the redirect / return URL `https://dippaun.github.io/homizi-app/#/verify`
   if Digio asks for an allowlist.

## 4. API keys

Digio dashboard → Developer / API settings → generate **production** client
id and client secret. Do not use sandbox keys. Do not paste them in chat,
commits, issues, or `config/`.

## 5. Webhook

Digio dashboard → Webhooks:

- URL: `https://<project-ref>.supabase.co/functions/v1/kyc-webhook`
  (staging project ref is in the Supabase dashboard URL)
- Events: KYC request approved / completed / rejected / failed / expired
  (all KYC request events are fine; unknown ones are ignored)
- Secret: generate one and save it as `DIGIO_WEBHOOK_SECRET`. Digio signs the
  raw body with HMAC-SHA256 and sends it in `X-Digio-Checksum`. A wrong or
  missing signature gets HTTP 401 and changes nothing.

Replays and out-of-order events are safe: a verified check is never
downgraded, a failed check does not go back to in progress, and a duplicate
event is acknowledged without a write. If the database write fails the
function returns 500 so Digio retries.

## 6. Secrets (Supabase dashboard → Edge Functions → Secrets)

Names only. Set values in the dashboard, never in the repo.

| Secret | Required | Notes |
| --- | --- | --- |
| `DIGIO_CLIENT_ID` | yes | production client id |
| `DIGIO_CLIENT_SECRET` | yes | production client secret |
| `DIGIO_WEBHOOK_SECRET` | yes (recommended) | webhook HMAC key; falls back to the client secret |
| `DIGIO_TEMPLATE_NAME` | yes (or `DIGIO_KYC_TEMPLATE`) | template name; either name works |
| `DIGIO_KYC_TEMPLATE` | alias | same as `DIGIO_TEMPLATE_NAME` (checked first) |
| `DIGIO_TEMPLATE_DIGILOCKER` | no | per-path template |
| `DIGIO_TEMPLATE_AADHAAR_OFFLINE` | no | per-path template |
| `DIGIO_ENV` | sandbox only | `sandbox` with sandbox keys; unset (or `production`) with production keys. Any other value keeps verification off |
| `DIGIO_BASE_URL` | no | leave unset (overrides the API host only, https only) |
| `KYC_RETURN_URLS` | no | comma-separated allowlist of return URLs; first is the default. Unset = `https://dippaun.github.io/homizi-app/#/verify` |
| `KYC_ALLOWED_ORIGINS` | no | comma-separated CORS origins. Unset = `https://dippaun.github.io` (plus localhost for local builds) |

The app asks `start-kyc` `{action: "status"}` and gets back only
`available: true/false` (plus `reason: "not_configured"` when off, or
`environment: "sandbox" | "production"` when on). It turns true only when the
client id, client secret, a template, and a valid `DIGIO_ENV` are set (the
webhook secret falls back to the client secret). Any other call while off
returns HTTP 503 `{error: "verification_unavailable", reason:
"not_configured"}` and the app shows **Verification coming soon**.

## 7. Database (optional hardening, pending your yes)

`supabase/migrations/20261114170000_kyc_idempotent_checks.sql` (same text in
`docs/staging_apply_KYC_1114.sql`) makes `apply_kyc_checks` refuse downgrades
inside the database too. The Edge Function already applies the same rule, so
the app is correct without it. To apply on staging: paste
`docs/staging_apply_KYC_1114.sql` into the SQL editor and run it. It is safe to
run twice.

The earlier KYC migrations (`20261017180300_agreements_kyc.sql`,
`20261017211500_live_identity_checks.sql`) must already be on the project.

## 8. Deploy the functions

From the repo root, logged in with `supabase login` and linked with
`supabase link --project-ref <project-ref>`:

```bash
supabase functions deploy start-kyc
supabase functions deploy kyc-webhook --no-verify-jwt
```

Redeploy (or just save the secrets; functions read them per request) after
changing secrets. `supabase/config.toml` already sets `verify_jwt = false` for
`kyc-webhook` and `true` for `start-kyc`.

## 9. Test checklist (with a founder account)

1. Open `https://dippaun.github.io/homizi-app/#/verify` signed in. You should
   see **Get verified with Aadhaar** (not "coming soon"). If you still see
   "coming soon", a secret is missing or the function was not deployed.
2. Get started → choose DigiLocker → tick consent → Open secure check. Digio
   opens in the same tab.
3. Finish DigiLocker and the selfie. Digio returns you to
   `…/homizi-app/#/verify`. The screen shows **Checking with Digio** and polls
   every 5 seconds for up to 3 minutes (also on returning to the tab, and on
   **Check status**).
4. Within a minute it should show **You're verified** with "Aadhaar ending
   XXXX".
5. In Supabase → Table editor → `identity_verifications`: `aadhaar_status` and
   `face_status` are `verified`, `masked_last4` has 4 digits, there is no full
   number anywhere.
6. Edge Function logs → `kyc-webhook`: one 200 per event, no 401.
7. Profile shows **Aadhaar & face: Verified** (green); your listings show
   **Aadhaar verified**; roommate/tenant cards and chat show the green
   **Aadhaar verified** / **Face verified** chips.
8. Failure path: start again with a different account and cancel in Digio, or
   use a mismatching selfie. The screen shows **Verification did not finish**
   with **Try again**.
9. Delete: on the success screen tap **Delete verification data** → the row
   is removed and badges disappear.
10. Replay: resend the last webhook from the Digio dashboard. Logs show
    `ignored: duplicate`; the status stays verified.

## Rollback

Unset `DIGIO_CLIENT_ID` (or any required secret). The app returns to
**Verification coming soon** on the next screen load. Existing verified
results stay as they are.
