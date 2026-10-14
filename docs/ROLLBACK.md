# Rollback

What can be stopped from this repository, and what needs the owner.

## This repo

- Do not put `SERVICE_ROLE_KEY` or a release keystore in Git. The secret scan is the check.
- Demo mode is the safe client: leave `SUPABASE_URL` or `SUPABASE_ANON_KEY` empty and the app does not call a hosted project.
- Database changes are versioned migrations. A local reset is `supabase db reset`. Do not edit a migration that has already been applied to a shared database; add a new one.
- `.github/workflows/distribute.yml` does not upload a build when the Firebase secrets are missing. Removing those secrets stops later uploads. It does not recall a build already installed.
- There is no in-app silent code push. A UI change ships as a new APK or app bundle.

## Needs the owner

- Halt a Play rollout, unpublish a listing, or answer a review in Play Console.
- Disable a hosted Supabase project, restore a backup, or rotate a key that was issued outside this repo.
- Tell testers to uninstall a Firebase build. This repo cannot delete an install from a phone.

There is no production project connected here, so there is no production rollout to halt yet.
