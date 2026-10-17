# Data safety form

DRAFT — NOT FOR SUBMISSION. Answers match the SDKs and code in this repository. Recheck before the owner fills Play Console.

## SDKs that can touch data

| Package | What it does in this app | Collected by default? |
| --- | --- | --- |
| `supabase_flutter` 2.18.2 | Auth, Postgres, and Storage when `SUPABASE_URL` and the public client key are compiled in. Staging project `loraalfiuklespaldotd` is in Mumbai (`ap-south-1`). | Only in a connected build. Demo mode (empty URL or key) keeps data on the device. |
| `sentry_flutter` 10.1.0 | Crash reporting only when the binary was compiled with `SENTRY_DSN`. The DSN is not in the repo. `sendDefaultPii` is false and the user record is stripped. | No. Sentry stays off unless a DSN is compiled in. |
| `image_picker` 1.2.4 | Opens the gallery so the user can attach a listing photo. The app does not open the camera. | The photo is collected only if the user picks one and the listing is saved. |
| First-party analytics | Not a third-party SDK. Events are written to the same Supabase database. | On, until the person turns the Settings switch off for that session. |

No advertising SDK. No payment SDK. No SMS provider in the app. Hosted phone SMS is off.

## Data types

| Play data type | Collected? | What it is | Optional? | Shared? |
| --- | --- | --- | --- | --- |
| Name | Yes, if entered | Display name on the profile | The person can leave it blank | Other users can see the display name the product shows. Not sold. |
| Email address | Yes, on a connected email sign-in | Sign-in contact. Not stored on the profile row. | Required to sign in to a connected project. Demo mode does not send it. | Processed by Supabase. Not sold. Not shown in chat. |
| Phone number | Only if the person types one | Demo sign-in, or a contact they choose to share for one match. Hosted SMS is off. | Yes for sharing. A connected staging sign-in uses email. | Shared with the other person only after that user shares it and the server says it is visible. |
| Photos | Yes, if the user adds listing photos | Gallery images in the private `listing-photos` bucket, or on the device in demo mode | Yes | Other users can see photos on a published listing. |
| App interactions | Yes, in a connected build, until opt-out | `app_open`, `listing_view`, `interest_sent`, `match_opened`, `message_sent`. Properties are limited to a listing id or a match id. | Yes. Turn product analytics off in Settings. The switch starts on and is not saved across sessions. | Stays in the same Supabase database. No third-party analytics SDK. |
| User IDs | Yes, in a connected build | Supabase auth user id on the account and on analytics rows | Required for a connected account | Processed by Supabase. Not an advertising id. |
| Messages | Yes, if the person chats | Chat text. The client and the server refuse a phone number or an email in the message. | Yes | The other person in the match can read the thread. |
| Approximate location | City and locality only, typed | Not GPS. No location permission. | The person types it | Shown on a listing as city and locality. |
| Crash logs | No in default builds | Sentry event only if `SENTRY_DSN` is compiled in | n/a when off | When a DSN is set, Sentry is the processor. Default builds do not send crashes. |
| Financial info | No | Rent figures are listing text. The app does not take payment. | n/a | No |
| Device or advertising id | No | Not requested | n/a | No |

## Form-level answers

- Data is encrypted in transit: yes. The Supabase client uses HTTPS.
- Users can request deletion: yes. Settings → Delete account, also described at `/delete-account`. On a connected build this calls `delete_own_account` and removes that user's listing photos. Demo mode clears the device only.
- Deletion does not purge a production backup, a payment provider, or Sentry. Say that if the form asks whether deletion covers all copies. No backup purge exists.
- Data is not sold.
- Data is not used for advertising or tracking across other companies' apps.
- Supabase is a service provider (the database, auth, and file host), not an advertising partner. For the staging app, the region is Mumbai.
- No third-party analytics SDK. Do not declare Firebase Analytics, Google Analytics, or Facebook.
- Declare Sentry only for a build that was actually compiled with a DSN. The release builds from this repo without `SENTRY_DSN` must not claim that crash logs are collected.
- No retention period is approved. Data remains until the account is deleted. Do not invent a number of days.
