# Email and mobile OTP

This file is the owner checklist for HOMIZI sign-in codes. Nothing in this change was applied to the Mumbai project `loraalfiuklespaldotd`, and no Auth setting was changed in the dashboard.

## Current state

Checked against this tree before the OTP work:

| Layer | What the repo uses |
| --- | --- |
| Client | Flutter / Dart. Material 3. Riverpod and go_router. `supabase_flutter` 2.18.2. |
| UI tokens | `HomiziColors`. Orange `#F75620` (`logoOrange`). Ink `#172033`. White surfaces. Plus Jakarta Sans and Inter are bundled. |
| Backend | Supabase Postgres, Auth, Storage, RLS. Edge Functions under `supabase/functions/`. |
| Staging | Project ref `loraalfiuklespaldotd`, Mumbai. Schema is pasted from `docs/staging_apply_*.sql`. This change does not paste or push. |
| Email code already in the app | Staging with a Supabase URL called `signInWithOtp` with no `emailRedirectTo`, then `verifyOTP` type `email`. Templates in `supabase/templates/` already show `{{ .Token }}`. |
| What was refused | A mobile number on that staging path. The screen said phone SMS was not connected. |
| Demo and dev | Empty Supabase values, and `APP_ENV=dev`, keep the on-device code `000000`. `test5@homizi.in` with `000000` is an on-device session and does not call Auth. |
| Production | Refuses `000000`. It did not send an email code. |
| Contacts | `public.private_contacts` stores email and phone for the owner. `public.profiles` had no phone column. Views that expose `email_verified` / `phone_verified` mean “a contact is on file”, not `auth.users` confirmation. |
| Roles | `HomiziRole` is `roommate`, `tenant`, `host`, `broker`. Those wire values are unchanged. |

## Role names

The owner’s names map onto the existing enum. The enum is not renamed and no role rows are migrated.

| Owner name | Enum | Wire value on `profiles.primary_role` |
| --- | --- | --- |
| Tenant | `HomiziRole.tenant` | `tenant` |
| Host | `HomiziRole.host` | `host` |
| Property Partner | `HomiziRole.broker` | `broker` |
| Home-Sharer | `HomiziRole.roommate` | `roommate` |

The role picker still labels tenant as “Rental”, broker as “Broker”, and home-sharer as “Roommate”. Legacy `users.primary_role` stays `tenant` or `host`. A legacy host whose category is broker is still read as Property Partner.

## What the app does now

Email sign-up and sign-in, when staging or production is connected to Supabase:

1. `signInWithOtp` with the email and no `emailRedirectTo`.
2. The person types the 6-digit code.
3. `verifyOTP` with type `email`.

A link in the message is still only a fallback.

Mobile, for someone who is already signed in:

1. `updateUser` with the E.164 number `+91` and 10 digits.
2. `verifyOTP` with type `phoneChange`.

That links the number to the same auth user. It does not call `signUp` and it does not create a second account.

Sign-in with a mobile that is already verified uses `signInWithOtp` with `shouldCreateUser: false`, then `verifyOTP` type `sms`.

The +91 field accepts 10 digits starting with 6, 7, 8, or 9. The code boxes take a paste. Resend waits 60 seconds. The client stops after 5 wrong codes. `over_email_send_rate_limit` shows “Too many codes requested. Please wait a minute and try again.” The provider code is logged in dev and staging only, and it is not shown on the screen. A number that already belongs to someone else shows “This number is already linked to another Homizi account”.

At startup the app reads `GET /auth/v1/settings` with the public key and keeps that answer for the session. `external.google: false` hides Continue with Google. `external.phone: false` hides “Use mobile number instead” and phone sign-in. Verify mobile then shows “Mobile verification is coming soon”. A failed read hides Google and phone, so a broken button is not shown. “Opening Google…” becomes “Google did not open. Try again.” after 15 seconds.

Email and mobile confirmed states come from `email_confirmed_at` and `phone_confirmed_at` on the session user. The client never writes those flags and never stores the code. `public.profiles.email_confirmed_at` and `phone_confirmed_at` are filled by a trigger on `auth.users`. The migration is in the repo and is not applied.

Demo mode and `test5@homizi.in` / `000000` still work. Production still refuses `000000` before it calls Auth.

## Email template

Paste both files after custom SMTP is connected. Subject: `Your HOMIZI code`.

- Magic Link: `supabase/templates/magic_link.html`
- Confirm signup: `supabase/templates/confirmation.html`

Each file shows `{{ .Token }}` as the 6-digit code on white, with orange `#F75620`. A short `{{ .ConfirmationURL }}` remains so a message that also contains a link can still open the app. The code expires in 5 minutes when the dashboard expiry is 300 seconds. Local `supabase/config.toml` points the same files at Inbucket/Mailpit. Do not `supabase config push` that file to Mumbai.

## Dashboard checklist for Deep

Do these in the Supabase dashboard. This change did not do them.

### SMTP (Resend)

1. Open Authentication, Emails, SMTP Settings on the project you approve (staging `loraalfiuklespaldotd` first).
2. Enable custom SMTP.
3. Host `smtp.resend.com`. Port `465`. Username `resend`.
4. Password: a Resend API key. Set it only in the dashboard. Do not commit it and do not put it in the app.
5. Sender name `HOMIZI`. Sender address on a domain you have verified in Resend.
6. Verified-domain checklist in Resend, for the homizi domain you send from:
   - Add the domain in Resend and use the address that domain owns.
   - Publish the SPF record Resend shows.
   - Publish the DKIM records Resend shows.
   - Wait until Resend marks the domain verified before the templates are saved.
7. Paste the two templates above. Set the email OTP length to 6 and the email OTP expiry to 300 seconds or less.

### SMS (MSG91) and TRAI DLT

Supabase has no built-in MSG91 provider. The Send SMS hook is `supabase/functions/send-sms-msg91`. It checks the Standard Webhooks signature with `SEND_SMS_HOOK_SECRET`, then calls the MSG91 OTP API with the code Supabase generated. It does not generate, log, or store the code.

1. Register the principal entity on the TRAI DLT portal used by your operator.
2. Register a header (sender id) that matches `MSG91_SENDER_ID`.
3. Register a transactional template that contains the OTP variable MSG91 documents for that template (their OTP API fills `##OTP##` from the `otp` we forward). The template must be approved before live SMS.
4. Create the MSG91 auth key, template id, and sender id in the MSG91 console. Do not put them in git.
5. Deploy the function only when you choose to: `send-sms-msg91`. Set these Edge secrets, empty in `config/edge.env.example`:
   - `SEND_SMS_HOOK_SECRET` — the hook signing secret from the dashboard (`v1,whsec_…`).
   - `MSG91_AUTH_KEY`
   - `MSG91_TEMPLATE_ID`
   - `MSG91_SENDER_ID`
6. In Authentication, Hooks, add a Send SMS hook. Type HTTPS. URL is the deployed function `.../functions/v1/send-sms-msg91`. Use the same secret as `SEND_SMS_HOOK_SECRET`.
7. Leave the built-in Twilio, MessageBird, Vonage, and Textlocal providers off. This project sends India SMS only through the hook.
8. Phone OTP length 6. Phone OTP expiry 300 seconds or less.

Local `supabase/config.toml` maps `919000000001` to `123456` under `[auth.sms.test_otp]`. That map is not pushed. Test OTPs skip the hook. The hook block in that file stays commented until the secrets exist.

Hosted test numbers are separate: Authentication, Phone, Test OTPs. Add any number you want to exercise without a live SMS, with a fixed 6-digit code. Do not use `000000` there for production.

### hCaptcha

1. Create an hCaptcha site. The site key is public. The secret is not.
2. App builds read `HCAPTCHA_SITE_KEY`. Empty means the widget is off. The official test site key, for a staging build or screenshots, is `10000000-ffff-ffff-ffff-000000000001`.
3. Put the secret only in Authentication, Bot and Abuse Protection. Choose hCaptcha. For local or staging experiments, hCaptcha publishes a test secret that always passes; it is still not committed here.
4. The pinned `supabase_flutter` `updateUser` method has no captcha argument. When a token is present, the app sends it on `PUT /auth/v1/user` as `gotrue_meta_security.captcha_token`. `signInWithOtp` and `signUp` take `captchaToken` directly.

### Rate limits

Set these in Authentication, Rate Limits. Suggested starting values after SMTP and SMS work:

| Setting | Suggested value |
| --- | --- |
| Emails sent per hour | 30 |
| SMS sent per hour | 30 |
| Token verifications per 5 minutes | 30 |
| Email OTP length | 6 |
| Email OTP expiry | 300 seconds |
| SMS OTP length | 6 |
| SMS OTP expiry | 300 seconds |

Raise the hourly caps only after you have watched real traffic. The client also waits 60 seconds between resends and stops after 5 wrong codes.

### Migration

Apply `supabase/migrations/20261114120000_auth_contact_verification.sql` yourself when you approve it. The same SQL is wrapped for the staging editor in `docs/staging_apply_OTP_1114.sql`. Neither file is applied by this change.

It adds `profiles.email_confirmed_at` and `profiles.phone_confirmed_at`, copies them from `auth.users` with trigger `zz_sync_auth_contact`, blocks client writes, and adds unique indexes on `private_contacts.email` and `private_contacts.phone`.

### What this change did not do

- No merge, no deploy, no `supabase db push`, no `supabase config push`.
- No Resend, MSG91, hCaptcha, or DLT account was created.
- No hosted Auth setting was changed.
- Production still refuses `000000`.
