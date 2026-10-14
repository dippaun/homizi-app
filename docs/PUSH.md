# Push placeholders

Push delivery is blocked. The owner has not chosen a provider or supplied credentials. In-app notifications do not register a device token. The Settings switch labelled "Match alerts on this device" stores nothing and does not contact Firebase or Apple.

Do not add any of the following until that block is lifted:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- an APNs authentication key (`.p8`) or a push certificate
- a Firebase server key, a service account JSON, or a Cloud Messaging sender secret
- code that calls `getToken`, `registerForRemoteNotifications`, or uploads a device token

## What a later setup will need

These names are a checklist only. The files are not in this repo, and the values are not filled in.

| Platform | Placeholder the owner will supply later | App must store |
| --- | --- | --- |
| Android | A Firebase project for `in.homizi.app` and its Android app id `app.homizi` | The public client file only, never a server key |
| iOS | An APNs key id, team id, and bundle id `in.homizi.app` | The public client file only, never the `.p8` |

Until those exist, the inbox is the on-device or local-database notification list. Marking an item read writes `read_at` only. The row payload is ids, not a phone, an email, or a street address.
