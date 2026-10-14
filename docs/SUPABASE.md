# Local Supabase

This guide starts the database that already lives in this repo. It does not create a hosted production project. Production Supabase is still blocked until the owner approves a project, a region, and least-privilege access. See the still-blocked table in `DECISIONS.md`.

## What you need

- Docker
- Supabase CLI 2.120.0 (the version CI uses)
- Flutter 3.47.7 if you also run the app

## Start

From the repository root:

```bash
supabase start
supabase db reset --yes
supabase test db
```

`supabase start` applies `supabase/migrations/` and `supabase/seed.sql`. `supabase test db` runs the row-level security checks in `supabase/tests/`.

When the stack is up:

- API: `http://127.0.0.1:54321`
- Database: `127.0.0.1:54322`
- Studio: `http://127.0.0.1:54323`

## Keys the app may use

Run:

```bash
supabase status -o env
```

Copy `API_URL` into `SUPABASE_URL`. Copy `ANON_KEY` or `PUBLISHABLE_KEY` into `SUPABASE_ANON_KEY`. Those are public client keys.

Do not copy the service role key into the app, into `config/env.*.json`, or into git. The client is not granted that role. Migrations already keep new tables off the anonymous and authenticated roles unless a grant says otherwise (`auto_expose_new_tables` is false).

Point the app at the local API with `config/env.dev.json` as described in `docs/ENV.md`.

## What the local project already enforces

- Interests, matches, and contact visibility go through SQL functions. The client does not insert those rows.
- A chat message cannot contain a phone number or an email address.
- A visit stores one to three start times and not a street address.
- Listing photos go in the private `listing-photos` bucket, under the signed-in account, and stay pending review.
- Payments exist as tables. Clients cannot write them.
- Identity verification is the mock function only. It cannot set a verified state.

Seed accounts are `ananya@example.test`, `rohan@example.test`, `priya@example.test`, and `kabir@example.test`, with the fixture password `local-dev-only`. That password is not a production secret.

## Stop

```bash
supabase stop
```

Stopping the local stack does not delete a hosted project, because this guide never creates one.
