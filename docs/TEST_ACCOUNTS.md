# Staging fresh testers

This path exists only on the Mumbai staging project `loraalfiuklespaldotd`. It gives the owner a brand-new empty account for each update, so onboarding can start from the role picker every time.

Production builds never call it. The migration creates the switch table and leaves it empty. The flag row is inserted only by the staging script below.

## Sign in

1. Open the staging app. Accept the terms on the welcome screen.
2. On the sign-in screen, enter a new mailbox and the code `000000`.
3. Use either shape:
   - `qa+<suffix>@homizi.in`. The suffix is 1 to 32 characters and may contain `a-z`, `0-9`, and `-`. Examples: `qa+build-1019@homizi.in`, `qa+owner-2@homizi.in`.
   - `test<N>@homizi.in`, where N is 1 to 9999 with no leading zero. Examples: `test1@homizi.in`, `test2@homizi.in`, `test9999@homizi.in`. `test5@homizi.in` is not this path. See below.
4. The app calls `staging_create_test_user` when that mailbox is missing, then signs in with `STAGING_TEST_PASSWORD` from `config/staging.json` (`REDACTED_STAGING_PASSWORD`). The SQL does not contain that password. `staging_create_test_user` reads `private.staging_secrets` where `key` is `test_password`. Set that row once by hand, with the same value the staging app was built with:

```sql
insert into private.staging_secrets (key, value)
values ('test_password', '<the same value as STAGING_TEST_PASSWORD>')
on conflict (key) do nothing;
```

A later paste does not replace an existing value. If the row is missing or blank, a new mailbox is refused. An existing mailbox is returned and its password is left as it is.
5. The account is email-confirmed. No role is chosen and no onboarding answers are stored, so the app opens the role picker.
6. The next update needs a new suffix or a new number. Signing in again with the same mailbox returns to that same account.

`000000` is not an emailed code. Any other mailbox still uses the 6-digit code from the email. `test@homizi.in` with `000000` still signs in to the shared staging mailbox and does not create a new user.

## Deterministic client test

`test5@homizi.in` with the code `000000` does not call Supabase Auth. Outside production, that pair opens an on-device demo session and then shows a confirmation on the sign-in screen. A wrong code for that mailbox still uses the emailed 6-digit code. Other `test<N>@homizi.in` addresses and `qa+` addresses keep `staging_create_test_user` and the staging password. Production ignores the client path.

No dashboard user, password, or test OTP is required for `test5@homizi.in`. `supabase/config.toml` has no email test-OTP map, and that file is not pushed to Mumbai, so a dashboard test OTP is not assumed.

If sign-in fails for any other mailbox, the same sign-in screen offers **Continue in demo mode**. That stays on the device and does not call the project. Staging web no longer skips this screen. `config/staging.json` sets `DEMO_SKIP_LOGIN` to false.

These addresses are refused: `qa+@homizi.in`, `qa+bad_email@homizi.in`, `qa+foo@gmail.com`, a `qa+` suffix longer than 32 characters, `test@homizi.in` (the shared mailbox), `test0@homizi.in`, `test01@homizi.in`, and `test10000@homizi.in`. Production builds ignore both fresh-tester shapes, the same way they ignore `qa+`.

## Turn it on

Edge Functions are not deployed on staging. Paste `docs/staging_apply_J_1019.sql`, `docs/staging_apply_K_1019.sql`, `docs/staging_apply_L_1019.sql`, and `docs/staging_apply_M_1019.sql` in that order. Running any of them again is safe. On a database that already has the older functions, paste `docs/staging_apply_N_1020.sql`. That file installs the fixed functions and does not set the password. The M file creates:

- `public.staging_flags`, and the row `test_accounts_enabled = true`
- `public.staging_create_test_user(p_email text)`, granted to `anon`
- `public.staging_purge_test_users(older_than interval)`, not granted to `anon` or `authenticated`

The function inserts `auth.users` and `auth.identities` (bcrypt via `crypt` / `gen_salt('bf')`, `email_confirmed_at` set, `aud` and `role` `authenticated`, `instance_id`, `raw_app_meta_data` provider `email`, `identity_data` with `sub` and `email`, and `provider_id`). The M paste, the K paste, and `docs/staging_apply_N_1020.sql` each install a function that accepts a `qa+` mailbox and `test<N>@homizi.in` for N from 1 to 9999, and still refuses `test@homizi.in`. Re-running M after K does not narrow that rule. Both shapes share one limit of 50 new mailboxes per UTC day. If the mailbox already exists, it returns that user and does not count it again. `private.staging_secrets` is granted to `service_role` for select and insert. `anon` and `authenticated` cannot read it.

The function does nothing useful while the flag row is missing or false. Do not paste the staging script into production.

No service role key, secret key, or database password belongs in this repository. The throwaway mailbox password above is the only password this path uses.

## Clean up

In the SQL editor, with the flag still on:

```sql
select public.staging_purge_test_users(interval '7 days');
```

That deletes `qa+` mailboxes and `test<N>@homizi.in` mailboxes older than 7 days, including their empty profile rows. It does not delete `test@homizi.in` or any other address. A zero or negative interval is refused. Purge also refuses to run when `test_accounts_enabled` is absent or false. The M, K, and N pastes each install that purge.
