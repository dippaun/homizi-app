# Where a signed-in account's data is stored

A real session is a Supabase auth user id (a uuid). Demo ids such as `lst_ahd_bopal` or `demo-host-rohan` are never sent to a uuid column. The device copy stays so the app still works offline and in demo mode.

Live project counts at the time of this note: `profiles` 76, `private_contacts` 76, `properties` 7, storage objects 5, `notifications` 22, `matches` 0, `conversations` 0, `messages` 0. Zero matches and chats means no two real accounts have both liked each other, and no message has been sent between two uuid accounts. Swipes and chats against the demo catalog stay on the device on purpose.

| What the person enters or does | Signed-in store | Device copy |
| --- | --- | --- |
| Name, occupation, public bio, age range, role | `profiles` | Session cache |
| Phone and email | `private_contacts` | Not stored |
| Profile photo | Storage bucket `avatars`, path on `profiles.avatar_path` | Shown from the URL |
| Longer profile form (about, city, lifestyle, budget) | `profile_details` | In-memory draft until the write |
| City, budget, and lifestyle from personalize | `tenant_preferences` when the account is copied | `SharedPreferences` key `flutter.homizi.personalization` |
| Tenant priorities (P1 and the rest) | `priority_preferences` (`side` = tenant or host) | Same JSON on the device until the row is read back |
| Ranked priority order | `priority_rank` when that save runs | Device priorities JSON |
| Roommate requirements | `roommate_profiles` and `roommate_lifestyle`. Full form also in `roommate_profiles.brief` after `20261121195500_account_briefs.sql` | `homizi.roommate.ask` |
| Tenant home form (address, type, rooms) | `tenant_preferences` localities and occupancy. Full form in `intake` after the same migration | `flutter.homizi.tenant_home_intake` |
| Browse city and locality chips | `tenant_preferences.localities` | `flutter.homizi.browse_place` |
| Right-swipe or like on a published home | `interests` (`target_type` property, `action` like) via `create_interest` | Liked ids in the open session |
| Pass or save on a published home | `interests` (`pass` or `save`). Unsave uses `unsave_interest` | Session |
| Like, pass, or save on a roommate who is a real user | `interests` (`target_type` user) | Finder state |
| Like or pass on a demo listing or demo person | Not sent | Session and the seeker deck |
| Mutual match | `matches`, only when both people have liked each other (`create_mutual_match`) | Session |
| Saved property search | `saved_searches` (`filters.wizard` holds the full form) | `flutter.homizi.property_search` |
| Recent searches | `recent_searches` | Explore cache |
| Listing draft and publish (owner, PG, broker, room sharer) | `properties`, `property_features` (`wizard:poster`), `property_private_details` | In-memory draft |
| Listing photos | Storage bucket `listing-photos` and `property_photos` | Local bytes until upload |
| Host shortlist, dismiss, or connect on a real seeker | `interests` (`save`, `pass`, or `like` on `user`) | `flutter.homizi.seeker_deck` |
| Hidden roommate | `interests` pass when the id is a uuid | `homizi.roommate.hidden` |
| Join request on a shared home | `shared_home_join_requests` when the home id is a uuid | Shared-home device cache |
| Visit request in a real chat | `visit_requests` through the thread gateway | Demo thread only |
| In-app more-request note | `support_tickets` when the text is 10–1000 characters and has no email or 10-digit number | `flutter.homizi.more_requests` |
| Notifications | `notifications`, preferences in `notification_preferences` | Inbox until refresh |
| Direct chat with a real account | `conversations`, `conversation_members`, `messages` via `get_or_create_direct_conversation` | None for the body |
| Chat with a demo or non-uuid profile | Not sent | `LocalDirectChatStore` |
| Office pins | `office_locations` | `flutter.homizi.office` |
| Broker registration | `broker_profiles`, `host_profiles`, `private_contacts` | Form until save |
| Partner application | `property_partner_applications` | Device copy of the form |

## Migration not applied

`supabase/migrations/20261121195500_account_briefs.sql` adds `roommate_profiles.brief` and `tenant_preferences.intake`. Until it is applied, those two JSON blobs stay on the device and the existing columns still update.
