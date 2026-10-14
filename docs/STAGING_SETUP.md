# Staging setup

The Mumbai staging project is `loraalfiuklespaldotd`. The app file `config/staging.json` holds only the public project URL and the publishable client key. That key replaces the old anon key. It is safe to commit. Do not put the service role key, the secret key, or the database password in this repository.

A run with no defines stays in demo mode and does not call this project.

This is staging, not the production approval in `DECISIONS.md`.

## Database push

Install the Supabase CLI (this repo was checked with 2.120.0). From the repository root in Windows PowerShell:

```powershell
Set-Location C:\path\to\homizi-app
supabase login
supabase link --project-ref loraalfiuklespaldotd
supabase db push
```

`supabase link` asks for the database password. Type the password from the dashboard: Project Settings, Database, Database password. It is entered on your machine. It is not written into a committed file. The CLI cache under `supabase\.temp` is gitignored. If `supabase db push` asks again, enter the same password.

`supabase db push` prints the migration list and asks you to confirm. Confirm only after you have read that list. Do not run `supabase db reset` against this hosted project. Reset would wipe data. Seed accounts and the fixture password in `supabase\seed.sql` are for the local Docker database only. `db push` does not load that seed.

Do not run `supabase config push`. The auth block in `supabase\config.toml` is for local Docker. Pushing it would overwrite the Mumbai email settings with the local ones.

The migrations create the tables, row level security, the SQL functions, and the private `listing-photos` bucket (5 MB, JPEG, PNG, and WebP). After the push, Storage in the dashboard should show `listing-photos` as private. The `tests` schema is for local policy tests. The app role cannot execute it.

If a later local database complains that a migration checksum changed, that is the `auth.uid()` grant, which is now skipped when the hosted role cannot grant it. Local `supabase db reset` replays the files cleanly.

## Run the app

Demo mode, no network project:

```powershell
flutter run
```

Staging:

```powershell
flutter run --dart-define-from-file=config/staging.json
```

`supabase_flutter` is initialized with `publishableKey`. The value in `config/staging.json` is `sb_publishable_...`. A `sb_secret_` value or a key that contains `service_role` is refused at startup.

## Auth toggles in the dashboard

`db push` does not change Auth. Sign-in on the hosted project needs these settings. Phone SMS stays off because it needs a provider.

1. Open the project, then Authentication, then Sign In / Providers.
2. Email: turn the provider on.
3. Confirm email: on. The app verifies the 6-digit code, so a new inbox can confirm by that code.
4. Phone: leave the provider off. Do not add a Twilio, MessageBird, or other SMS secret.
5. Open Authentication, then Emails, then Templates, then Magic Link.
6. The message body must include `{{ .Token }}` so the email contains the 6-digit code. You can leave `{{ .ConfirmationURL }}` in the template as well. The app does not depend on the link.
7. Save the template.

Then sign in from the staging app with an email address. Tap Send code, read the inbox, and enter the 6 digits. A mobile number is refused and no SMS is sent. The development code `000000` is not accepted against this hosted project. It remains on demo mode and on a local Supabase dev run only.

The built-in Supabase mailer is enough for a few staging codes. It is rate limited. A custom SMTP provider is not required for this step and no SMTP password belongs in git.
