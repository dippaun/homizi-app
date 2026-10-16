# Staging setup

The Mumbai staging project is `loraalfiuklespaldotd`. The app file `config/staging.json` holds the public project URL, the publishable client key, and the throwaway staging test password documented in [EMAIL_OTP_SETUP.md](EMAIL_OTP_SETUP.md). The publishable key replaces the old anon key. It is safe to commit. Do not put the service role key, the secret key, or the database password in this repository.

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

If the CLI is not available, paste `docs/staging_apply.sql` into the Supabase SQL editor on a fresh project. That file applies the same migrations, including the private `listing-photos` bucket and its policies, and records each version in `supabase_migrations.schema_migrations` so a later `db push` sees them as applied. It does not load seed data. Running it again is safe. After that file, paste `docs/staging_apply_next.sql`. That follow-up applies every migration added since `docs/staging_apply.sql`: the listing-photos policy retry, the host notification for a like, realtime chat, the staff queue, and product analytics. Running that file again is also safe.

After the schema is applied, paste `docs/staging_seed.sql` in the same SQL editor. It creates one seed host and 40 published listings (locality and city only). The host password is random and is not in the file, so do not try to sign in as that host. Running the seed again refreshes those 40 rows and does not delete listings you created. It is not `supabase/seed.sql`, and it does not use the local fixture password.

Do not run `supabase config push`. The auth block in `supabase\config.toml` is for local Docker. Pushing it would overwrite the Mumbai email settings with the local ones.

The migrations create the tables, row level security, the SQL functions, and the private `listing-photos` bucket (5 MB, JPEG, PNG, and WebP). After the push, Storage in the dashboard should show `listing-photos` as private. The `tests` schema is for local policy tests. The app role cannot execute it.

Saving a listing on staging uploads JPEG, PNG, and WebP files into that bucket at `{your user id}/{property id}/{file id}.{ext}`. The original file name is not used. `docs/staging_apply_next.sql` retries the four listing-photos policies as `supabase_storage_admin` when the session is allowed to assume that role, then returns to the original role. Until those policies exist, the app says the upload was refused instead of hiding the Storage error. If the SQL editor noticed that the policies were skipped, paste `docs/staging_apply_next.sql` again.

A match, a message, and a visit already insert an in-app notification from a database trigger. The same follow-up file notifies the host when someone likes a published listing. The row stores the property id only. Pull to refresh on the notifications screen loads those rows. No phone, email, or street address is stored.

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

## Auth in the dashboard

`db push` does not change Auth. Phone SMS stays off because it needs a provider. Leave Email on, and leave Phone off. Do not add a Twilio, MessageBird, or other SMS secret.

Hosted sign-in emails a 6-digit code. The steps to connect custom SMTP (sender name `HOMIZI`), paste `supabase/templates/magic_link.html` and `supabase/templates/confirmation.html`, and set the OTP length to 6 are in [EMAIL_OTP_SETUP.md](EMAIL_OTP_SETUP.md). The subject of both templates is `Your HOMIZI code`. Do not run `supabase config push`.

Keep this redirect on the allow list so a message that still contains a link can open the app:

1. Open the project, then Authentication, then URL Configuration.
2. Under Redirect URLs, add `in.homizi.app://login-callback`.
3. Save.

The app does not send that URL as `emailRedirectTo`. Tap Send code, then type the 6-digit code from the email. If that email contains a link, opening it on the same phone still signs you in. A laptop browser cannot open this custom scheme. A mobile number is refused and no SMS is sent. The development code `000000` is not a hosted OTP. It remains on demo mode and on a local Supabase dev run only.

`config/staging.json` also sets `STAGING_TEST_PASSWORD` to `REDACTED_STAGING_PASSWORD`. That is a throwaway password for the staging mailbox `test@homizi.in`, and it is acceptable to commit. It is not a service role key or a database password. In a staging build, that email plus the code `000000` signs in with `signInWithPassword`, then the app calls `ensure_own_account`. Production builds ignore the password and that path. Create the user in Authentication, Users, with Auto Confirm on. Details are in [EMAIL_OTP_SETUP.md](EMAIL_OTP_SETUP.md). No SMTP password belongs in git.

The sign-in screen shows the Supabase error when a send fails. A rate limit, a redirect that is not on the allow list, and an unconfirmed email each have their own sentence, plus the Supabase error code. The mailbox address is not shown.

`config/staging.json` sets `STAGING_PASSWORD_AUTH` to true. That adds email and password sign-up on staging only. Production ignores the flag. The local fixture password is refused. With Confirm email on, creating an account does not start a session until the confirmation message is opened. The login screen also has Use demo mode, which stays on the device and does not call this project.

If `docs/staging_apply.sql` skipped the trigger on `auth.users`, a new account has no `public.users` row. Paste `supabase/migrations/20261016120000_ensure_own_account.sql` in the SQL editor. The app calls `ensure_own_account` after sign-in and creates that row for the signed-in user only. The same file tries the trigger again and skips it with a notice when the hosted role is not the owner.
