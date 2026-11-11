# Google sign-in setup

The app shows **Continue with Google** on the sign-in screen, next to the existing email and phone code. This file is the owner's checklist. Nothing here is applied from the repo. Do not commit a client secret, and do not paste one into chat.

The button calls `signInWithOAuth` for Google and sends the browser back to:

`https://dippaun.github.io/homizi-app/`

If Google is not enabled on the Supabase project yet, the screen says: "Google sign-in is not switched on yet. Continue with your email and the 6-digit code." Email and phone codes are unchanged. `test5@homizi.in` with code `000000` still opens the on-device demo session.

A new Google account gets a `profiles` row from the existing `handle_new_auth_user` trigger and from `ensure_own_account` when the app restores the session. If that profile has no role yet, the app stores tenant and opens Home. The person can change it from Create Your Profile.

Staging project ref: `loraalfiuklespaldotd` (Mumbai).

## 1. Google Cloud

1. Open [Google Cloud Console](https://console.cloud.google.com/) for the HOMIZI project. Create a project there if you do not have one. This is not done from the app.
2. APIs & Services, then OAuth consent screen. User type External is enough for staging. App name `HOMIZI`. Support email is your own. Add the scope `openid`, `email`, and `profile` (the default sign-in scopes). Save.
3. APIs & Services, then Credentials, then Create credentials, then OAuth client ID. Application type: Web application.
4. Authorised JavaScript origins:
   - `https://dippaun.github.io`
   - `https://loraalfiuklespaldotd.supabase.co`
5. Authorised redirect URI (this is Supabase, not the app URL):
   - `https://loraalfiuklespaldotd.supabase.co/auth/v1/callback`
6. Copy the client ID and the client secret into a password manager. Do not put them in this repo, in a commit, or in a PR.

## 2. Supabase

1. Open the Mumbai project `loraalfiuklespaldotd`.
2. Authentication, then Sign In / Providers, then Google. The older path is Authentication, then Providers.
3. Enable Google. Paste the client ID and the client secret from Google Cloud. Save. Leave the secret only in the dashboard.
4. Authentication, then URL Configuration.
5. Set Site URL to `https://dippaun.github.io/homizi-app/`.
6. Under Redirect URLs, add `https://dippaun.github.io/homizi-app/` and keep the existing `in.homizi.app://login-callback` entry used by email links.

Do not run `supabase config push`. Do not edit auth settings from SQL.

## 3. Check

1. Open https://dippaun.github.io/homizi-app/ after a build that contains this button.
2. Accept the terms, then tap Continue with Google.
3. Google should return to the site, and Home should open.
4. Until step 2 is saved, the same button stays on the sign-in screen and shows the friendly message above. The email code path still works, including `test5@homizi.in` / `000000`.
