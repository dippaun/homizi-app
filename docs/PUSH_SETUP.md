# Push setup

Push is wired and stays inert until a Firebase project is compiled in. Demo mode does not call Firebase. Do not commit `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, a service-account JSON, or an APNs key.

## 1. Create the Firebase project

1. Open the Firebase console and create a project for HOMIZI.
2. Add an Android app with package name `in.homizi.app`.
3. Add a Web app. Copy the public config (`apiKey`, `appId`, `messagingSenderId`, `projectId`).
4. In Cloud Messaging, create a Web Push certificate and copy the public VAPID key.

## 2. Files to drop locally

| File | Where |
| --- | --- |
| `google-services.json` | `android/app/google-services.json` (gitignored). The Google Services plugin applies only when this file exists. |
| Web public config | Replace `null` in `web/firebase-config.js` with the web app object. This file is public. It is not a server key. |

The Android manifest removes `FirebaseInitProvider` and sets `firebase_messaging_auto_init_enabled` to false, so a build without the JSON file still launches.

## 3. Dart defines

Pass these with `--dart-define` or a local json file that is not committed:

- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_VAPID_KEY` (web)

`config/staging.json` stays free of these values. Empty values keep the app on the in-app inbox.

## 4. Supabase secrets and database settings

Deploy the `send-push` Edge Function (`verify_jwt = false`). Set:

- `FCM_SERVICE_ACCOUNT` — the Firebase service-account JSON, as one secret. Do not commit it.
- `PUSH_WEBHOOK_SECRET` — a long random string shared with the database.

In the SQL editor, after the function URL is known:

```sql
alter database postgres set app.settings.push_function_url = 'https://loraalfiuklespaldotd.supabase.co/functions/v1/send-push';
alter database postgres set app.settings.push_webhook_secret = '<same value as PUSH_WEBHOOK_SECRET>';
```

Until both settings exist, the notification insert trigger does nothing. The function also returns without sending when `FCM_SERVICE_ACCOUNT` is missing.

## 5. What is stored

`device_tokens` holds the FCM registration token, the platform (`android`, `ios`, or `web`), and the user id. Row security is own-row only. Staff cannot read tokens. Push copy is a fixed title and body plus the notification id. It does not include a phone, an email, or an address.

Preferences: if `notification_preferences` exists, `push_allowed` honours `{category}_enabled`, `{category}_push`, or a `categories` jsonb object for `matches`, `chat`, and `visits`. Unknown notification types are not pushed. If that table is absent, known categories are allowed.

## 6. Web

`web/firebase-messaging-sw.js` is served as its own file. It loads Firebase only when `firebase-config.js` is not null. The app asks `firebase_messaging` for a token with `serviceWorkerScriptPath: firebase-messaging-sw.js`. Browsers cannot set a custom User-Agent; that limit is for map tiles, not for FCM.
