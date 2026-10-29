# Email OTP setup

Hosted staging sign-in emails a 6-digit code. The app calls `signInWithOtp` without `emailRedirectTo`, then `verifyOTP` with type `email`. A link is only a fallback: if the message contains one and the phone opens it, the app still adopts that session. Phone SMS stays off.

`supabase db push` does not apply these templates. Do not run `supabase config push`. Paste them in the dashboard after custom SMTP is connected. Local `supabase/config.toml` already sets `otp_length = 6` under `[auth.email]`. That local file is not pushed to Mumbai.

## Custom SMTP

Hosted Supabase will not let you edit the Magic Link or Confirm signup templates until a custom SMTP provider is connected.

1. Open the Mumbai project `loraalfiuklespaldotd`.
2. Open Authentication, then Emails, then SMTP Settings. The older path is Project Settings, Authentication, SMTP.
3. Enable custom SMTP and save the provider credentials in the dashboard. Do not commit an SMTP password.
4. Set the sender name to `HOMIZI`.

## Paste the templates

1. Open Authentication, then Emails, then Templates. The older label is Authentication, Email Templates.
2. Open the Magic Link template. Set the subject to `Your HOMIZI code`. Replace the message body with the full contents of `supabase/templates/magic_link.html`. Save.
3. Open the Confirm signup template. Set the subject to `Your HOMIZI code`. Replace the message body with the full contents of `supabase/templates/confirmation.html`. Save.

Both files use a white background and the HOMIZI orange `#F75620`. Each shows `{{ .Token }}` as a large 6-digit code. A short link uses `{{ .ConfirmationURL }}` so a message that contains a link can still open the app. The sign-in screen asks for the code. The link is not the main path.

The app does not send `emailRedirectTo` on the code request, so the code works even when the link points at the site URL.

## OTP length

Set the email OTP length to 6.

In the dashboard this is Authentication, Providers, Email, or Authentication, Emails, then the OTP length field. Use 6, the same value as `otp_length` in `supabase/config.toml`. The app rejects a code that is not 6 digits before it calls `verifyOTP`.

## Redirect URL

Keep `in.homizi.app://login-callback` under Authentication, URL Configuration, Redirect URLs. The app does not send that URL on the code request. It is used only when an email contains a link and the phone opens `in.homizi.app://login-callback`.

## Staging test login

`config/staging.json` sets `STAGING_TEST_PASSWORD` to `REDACTED_STAGING_PASSWORD`. That is a throwaway password for one staging mailbox. It is acceptable to commit. It is not a production secret, a service role key, or a database password.

Create the user once in the staging dashboard:

1. Open Authentication, then Users, then Add user.
2. Email: `test@homizi.in`.
3. Password: `REDACTED_STAGING_PASSWORD`.
4. Turn on Auto Confirm so the mailbox does not wait for a confirmation message.

In a staging build (`APP_ENV=staging`, with the Supabase URL and publishable key set), `test@homizi.in` plus the code `000000` calls `signInWithPassword` with `STAGING_TEST_PASSWORD`. The app then calls `ensure_own_account` for that user. A fresh mailbox `qa+<suffix>@homizi.in` with the same code creates that user when it is missing, then signs in the same way and opens the role picker. The steps are in [TEST_ACCOUNTS.md](TEST_ACCOUNTS.md). `test5@homizi.in` with `000000` is the exception: it opens an on-device demo session and does not call `staging_create_test_user`. Any other email still uses the 6-digit code from the email. `000000` is not a hosted OTP for other mailboxes.

Production builds ignore this path. `AppConfig.parse` drops `STAGING_TEST_PASSWORD` unless `APP_ENV` is `staging`, and the sign-in controller checks the environment again before calling `signInWithPassword`. A production build that is handed this password still refuses `000000` and does not sign in as `test@homizi.in` with it.

Do not point a production build at `config/staging.json`. Remove this user and the define when the shared staging mailbox is no longer needed.
