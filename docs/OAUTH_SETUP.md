# Google sign-in setup

The sign-in screen already has **Continue with Google**, under the email code. The app calls `signInWithOAuth(OAuthProvider.google)` and sends the browser back to `https://dippaun.github.io/homizi-app/` (base href `/homizi-app/`). On the way back, the app restores the session and calls the existing `ensure_own_account`, which inserts the profiles row. A new person lands on the role picker. Someone who already has a role goes straight in.

Do not put a Google client secret, a `.json` key file, or any other secret in this repo. Paste them only in the Supabase dashboard.

If Google is not enabled yet, the screen says that Google sign-in is not turned on and keeps the email code. `test5@homizi.in` / `000000` and the `qa+` mailboxes are unchanged.

Apple sign-in is deferred.

## Google Cloud

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create a project (or pick the one you want for Homizi).
2. Open **APIs & Services**, then **OAuth consent screen**. Choose External, fill the app name `HOMIZI`, and add your email as the support contact. Save.
3. Open **APIs & Services**, then **Credentials**, then **Create credentials**, then **OAuth client ID**. Create a Web client ID.
4. Application type: **Web application**.
5. Under **Authorized redirect URIs**, add exactly:

   `https://loraalfiuklespaldotd.supabase.co/auth/v1/callback`

6. Create the client. Copy the **Client ID** and the **Client secret**. Leave them out of git and out of chat.

## Supabase Auth

1. Open the Mumbai project `loraalfiuklespaldotd`.
2. Open **Authentication**, then **Sign In / Providers** (the older label is **Auth Providers**), then **Google**.
3. Turn Google on.
4. Paste the client ID and the client secret from the step above. Save.

## Supabase URL configuration

1. Open **Authentication**, then **URL Configuration**.
2. Set the **Site URL** to `https://dippaun.github.io/homizi-app/`.
3. Under **Redirect URLs**, add `https://dippaun.github.io/homizi-app/` if it is not already there. The trailing slash matters. Save.

Keep `in.homizi.app://login-callback` in that allow-list as well. Email codes still use it only when a phone opens a link. Google does not use that scheme.

After this, Continue with Google on https://dippaun.github.io/homizi-app/ opens Google and returns to the same site.
