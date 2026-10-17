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
| Password selected by that code | `REDACTED_STAGING_PASSWORD` |

On a staging build, email `test@homizi.in` plus code `000000` signs in with the staging test password. `000000` is not a hosted email OTP, and a production build ignores it. Phone SMS is off. A normal staging user can instead request a 6-digit code by email.

The owner has to create `test@homizi.in` in the Mumbai project's Authentication users with Auto Confirm on before this login works. That step is in `docs/STAGING_SETUP.md`. The password is the throwaway value already stored in `config/staging.json`.

## Steps

1. Install the staging release build, or open the staging web app.
2. On the welcome screen, accept the draft policy. The recorded version is `2026-10-11-draft`.
3. Sign in with the email and code above.
4. Choose Tenant, Host, or both.
5. Explore shows published seed homes. Open one. Contact is hidden.
6. Settings includes the product-analytics switch and Delete account.
7. Privacy, terms, support, and deletion instructions are public, with no sign-in, at `/privacy`, `/terms`, `/support`, and `/delete-account`.

Do not treat this mailbox as a real person. Do not upload this build to production while it still contains the staging test password. Production compiles drop that password.
