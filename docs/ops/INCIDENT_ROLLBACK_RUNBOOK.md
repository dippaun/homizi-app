# Incident and rollback runbook

S-11. Owner: deep. Written 17 October 2026. There is no production Play rollout and no production Supabase project, so several steps below are the procedure to use when those exist. The shorter repository note is [../ROLLBACK.md](../ROLLBACK.md).

## When to use this

Use it when a build, a migration, or the staging project is hurting people or exposing data: a crash loop, a contact leak, a bad migration, a secret in a log, or a store rollout that must stop.

The interim moderator for user reports is the same owner. Report handling is [MODERATION_SOP.md](MODERATION_SOP.md). This runbook is for stopping a release and restoring service.

## Severity

| Level | Examples | First move |
| --- | --- | --- |
| High | Contact details leaking, service-role key exposed, account takeover | Stop the bad client path and rotate the key. Tell affected people once the facts are known. |
| Medium | Staging sign-in down, listings not loading, a migration error | Keep demo mode available. Fix forward with a new migration or a new build. |
| Low | Copy error, a single tester build | Ship a new build. Leave staging up. |

## Who does what

| Role | Person | Does |
| --- | --- | --- |
| Incident lead | deep (owner) | Decides halt, rollback, and what testers are told. |
| Repository | Whoever is committing | Adds a forward migration or a new build. Does not edit a migration already applied to Mumbai. |
| Store | deep, once Play Console exists | Halts a rollout in Play Console. This repository cannot do that. |

## Stop the client from calling a backend

Demo mode is the safe client. A build with an empty `SUPABASE_URL` or an empty public key stays on the device and does not call Mumbai. `AppConfig.parse` rejects a key that starts with `sb_secret_` or contains `service_role` (`lib/core/config/app_config.dart`).

The web app at https://homizi.netlify.app and any APK built with `config/staging.json` do call staging. To stop new web users, unpublish or roll back the Netlify deploy from the Netlify dashboard. To stop new Android installs, stop shipping that build. Installed APKs keep working until the owner tells testers to uninstall them.

## Stop tester distribution

`.github/workflows/distribute.yml` uploads only when `FIREBASE_APP_ID` and `FIREBASE_TOKEN` are both set. Removing those repository secrets stops later uploads. It does not delete a build already installed. There is no silent in-app code push. A UI fix ships as a new APK or app bundle.

## Halt a Play rollout

No Play app is published. When one exists:

1. Open Play Console for `in.homizi.app`.
2. Open the production or testing release and halt the staged rollout.
3. Leave the previous approved release as the one new users receive, if Play still offers that control.
4. Ship a hotfix as a new version code, higher than `1.0.0+1`, with the upload key that was backed up outside git.

This git repository cannot halt a Play rollout.

## Database

Migrations in `supabase/migrations/` are forward-only once they are on Mumbai. Add a new file to correct a mistake. Do not edit a migration that staging has already applied. Do not run `supabase db reset` against `loraalfiuklespaldotd`. Reset wipes data.

If a migration is harmful and has not been applied, do not apply it. If it has been applied, write a corrective migration and apply that through the SQL editor or `supabase db push` after reading the list.

The owner can pause the staging project from the Supabase dashboard if the project itself must go offline. Pausing is an owner action. This repo has no production backup to restore. S-09 stays blocked until a production project exists and a restore has been rehearsed.

## Secrets

If a service-role key, database password, or signing key lands in git or a log:

1. Rotate it in the Supabase or Play dashboard.
2. Remove it from the working tree and from CI secrets.
3. Treat the old value as public. The secret scan (`dart run tool/secret_scan.dart`) fails the build on private keys, live secret prefixes, AWS-style access keys, JWTs, and assigned service-role values.

The publishable key in `config/staging.json` is a client key. Rotating it means shipping a new build with the new publishable key.

## Feature disable

There is no remote feature-flag service. Payments have no checkout. Push does not register a device token. Sentry stays off unless a build is compiled with `SENTRY_DSN`, and that value is not in the repo (`test/core/observability/error_reporting_test.dart`).

To hide a single listing or suspend an account during an incident, the interim moderator uses the staff functions after their user id is in `staff_roles`. Until that row exists, the project owner can pause a listing from the SQL editor by the same status change `staff_hide_listing` makes (`properties.status` to `paused`). Prefer the staff function once the moderator row exists, so `audit_events` records the actor.

## After the incident

Write down the time, the impact, the commit or migration, and what testers were told. Keep that note with the release evidence. A public launch is still blocked, so this runbook has not been rehearsed against Play Console or a production restore.
