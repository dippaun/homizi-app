# Reviewer access

DRAFT — NOT FOR SUBMISSION. Instructions for a Play reviewer or an internal tester. This uses the throwaway staging account. It is not a production login.

## Which build

The reviewer build must be compiled with the staging defines:

```bash
flutter build appbundle --release --dart-define-from-file=config/staging.json
```

The same file is what `tool/deploy_web.sh` uses for the web app. A release build without that file stays in demo mode and does not sign in to the Mumbai project.

`config/staging.json` sets `APP_ENV` to `staging` and points at Supabase project `loraalfiuklespaldotd` (Mumbai). The publishable client key in that file is public. The service-role key is not in the app.

## Account

| Field | Value |
| --- | --- |
| Email | `test@homizi.in` |
| Code | `000000` |
| Password selected by that code | the GitHub Actions secret `STAGING_TEST_PASSWORD` |

`config/staging.json` contains only the placeholder `REDACTED_STAGING_PASSWORD`. A build that still has that placeholder does not send it. On a staging build compiled with the secret, email `test@homizi.in` plus code `000000` signs in with that secret. `000000` is not a hosted email OTP, and a production build ignores it. Phone SMS is off. A normal staging user can instead request a 6-digit code by email. `test5@homizi.in` with `000000` stays on the device.

The owner has to create `test@homizi.in` in the Mumbai project's Authentication users with Auto Confirm on before this login works. That step is in `docs/STAGING_SETUP.md`. The password is the GitHub Actions secret, the same value as `private.staging_secrets.test_password`. It is not written in this file.

## Steps

1. Install the staging release build, or open the staging web app.
2. On the welcome screen, accept the draft policy. The recorded version is `2026-10-11-draft`.
3. Sign in with the email and code above.
4. Choose Tenant, Host, or both.
5. Explore shows published seed homes. Open one. Contact is hidden.
6. Settings includes the product-analytics switch and Delete account.
7. Privacy, terms, support, and deletion instructions are public, with no sign-in, at `/privacy`, `/terms`, `/support`, and `/delete-account`.

Do not treat this mailbox as a real person. Do not upload this build to production while it still contains the staging test password. Production compiles drop that password.
