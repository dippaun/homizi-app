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
| Roommate profile and "I want my roommate to be" list | `roommate_profiles` columns for the person's own answers, and `roommate_profiles.brief` (`want` holds the ranked list) after `20261121195500_account_briefs.sql` | `homizi.roommate.ask` |
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

Tenants create a profile at Create Your Profile (`/profile/create`) and the tenant profile page (`/profile/tenant`). They post a room from Home or Profile with **Post a room**, which opens the room-sharer flow (`/post-property/room`): Shared room or Full house, then the listing steps. A roommate seeker profile is created in Roommate Finder, first compartment **Your Roommate Profile**. Photo, name, age, gender, occupation, office, bio, city, and verified phone or email come from that profile and are not asked again. Budget, move-in, looking for, localities, and lifestyle are the extra answers. **Publish my roommate profile** makes it visible in Find Roomie. **My Requirements for Roommie** is the ranked "I want my roommate to be…" list inside that same compartment. The match percent is the lower of the two directions: how they meet your list, and how you meet the requirements they have actually saved.

## One person

The tenant profile (`profiles`, `profile_details`, and the saved priorities) is the only copy of a person's details. Find Roomie shows that profile. A shared-room post shows that same profile as the current occupant. Listing steps do not ask for the person's name, food, smoking, pets, or schedule again. Matching reads the saved profile and priorities. A live roommate deck does not add sample people.

The question "List me as a roommate seeker?" is asked once, at the end of profile creation, unless the person chose Share my room or Find a roommate. Those two goals publish the roommate profile immediately (`roommate_profiles.discoverable` and `open_to_flatmates`). Publishing a shared-room listing does the same. After a yes or a no, Roommate Finder does not show the yellow banner again. The same yes/no stays on Profile as "List me as a roommate seeker" and writes `profilePosted` and `postAsked`.

Company, current city, and office are the same values everywhere. The profile draft (`profile_details.company_name`, `profile_details.city`, and the device copy `flutter.homizi.profile_create`) is filled from personalization, a saved search place, the profile place pin, and the host company when those were saved first. Office stays on `office_locations`. Search, priorities, and the roommate ask read and write those same fields. A search no longer drops homes that miss a hard filter: every published home is ranked, same city first, including 0%.

About Me shows goal tags as "Looking for a room", "Sharing my room", "Finding a roommate", and "Hosting a home". A demo session shows the address or phone the person typed (`demo@homizi.in` when that was the login), not the `qa+d…@homizi.in` mailbox opened behind it.

## First sign-in goals

The first sign-in asks once, with several goals allowed: Find a room / flat, Share my room, Find a roommate, Host a flat / room. They are stored on the existing profile. `profile_details.roles` keeps `tenant`, `sharer`, and `host` (the database check does not allow a fifth role). The exact goals are tags on `profile_details.tags`: `goal:tenant`, `goal:sharer`, `goal:roommate`, `goal:host`. No new column.

The guided profile steps that already have a name, city, occupation, languages, or lifestyle are skipped. Basic Information and Your Office Location open with the saved city, company, office, transport, and commute time filled in. Saving the office updates that same office. A later goal uses Profile → Your goals and only opens Basic Information when the name or city is still empty.

## City and who is visible

A city is saved from a Places pick. Typing a city and leaving the field saves the top Places suggestion, or the closest catalogue city (so "ahmedbad" becomes Ahmedabad). Feeds and decks show the viewer's city first, sorted by match percent, then every other city under that. A card from another city shows `Different city · <City>`. A 0% match stays in the list. The location factor scores 4 points for a different city instead of the full 15, so that one factor weighs less. Match percent on a home card, a roommate card, and a host's seeker card comes from `scoreMatch`. A factor counts only when both sides have stated it. The breakdown is the factor list on the card.

`list_roommate_seekers_in_city` can return one city. The feeds do not call it, so it does not hide other cities.

A roommate or share-a-room profile with no photo still shows a portrait. The picture is one of `assets/avatars/avatar_01.webp` through `avatar_06.webp`, chosen from the person id. It is drawn on the card, the profile, and the match deck only. It is not saved on `profiles.avatar_path`. An uploaded photo replaces it.

## Match factors and the one profile

A person's own answers live in one place. Set My Priorities (`SearchPriorities`, stored in `priority_preferences.prefs`) is the editor. Saving it also copies the habit fields onto the roommate ask so Find Roomie uses the same answers. The listing wizard is the other side of a property match. A factor is scored only when both sides have stated it. "Prefer not to say" stays unscored, which is the yellow missing icon. Tapping that icon opens Set My Priorities on that tile (`?focus=`).

| Icon | Seeker field | Where it is edited | Listing counterpart | Where the host sets it |
| --- | --- | --- | --- | --- |
| Budget | `budget_min_inr` / `budget_max_inr` | Priorities, Budget range | `properties.rent_inr` | Rent step |
| Location | `city`, `locations` | Priorities, Location & commute | `properties.city`, `locality` | Location step |
| Room type | `occupancy` (`single`, `shared`, `any`) | Priorities, Occupancy type | `properties.occupancy_max` | Living details |
| Property type | `property_types` | Priorities, Property type | `properties.property_type` | What to list / living details |
| Move-in | `move_in` | Priorities, Move-in date | `properties.available_from` | Availability |
| Food | `food` | Lifestyle tile Food | `properties.non_veg_allowed` | Rules, Non-veg allowed |
| Smoking | `smoking` | Lifestyle tile Do you smoke? | `wizard:smoking` (`yes` / `no`), shown as Smoking allowed / No smoking | Rules, Smoking allowed |
| Pets | `pets` (`avoid`, `ok`, `required`) | Lifestyle tile Pets | `properties.pets_allowed` | Rules, Pets allowed |
| Schedule | `schedule` (`early`, `flexible`, `night`) | Lifestyle tile Sleep schedule | `wizard:schedule` | Rules, Occupant schedule |

Roommate match uses the same habit answers, plus a few that are not on the property icon row:

| Roommate factor | Same field | Editor |
| --- | --- | --- |
| Food, smoking, pets, sleep schedule | `food`, `smoking`, `pets`, `schedule` | Lifestyle tiles above |
| Work style | `work_style` (`office`, `hybrid`, `home`) | Lifestyle tile Work style |
| Cleanliness | `tidy` (`relaxed` 2, `average` 3, `tidy` 5) | Lifestyle tile How tidy are you? |
| Drinking, guests, cooking | `drinking`, `guests`, `cooking` | Lifestyle tiles |
| Budget, city, move-in, gender, room | the priority rows | Priorities list |
| Age, occupation, languages | `profiles` and `profile_details` | Create profile / My Profile |

Drinking, guests, and cooking are roommate-only. They are not property-match icons, because a listing does not state the seeker's drinking or cooking. Gender on a listing is a host preference and is not a score input.

`wizard:smoking` and `wizard:schedule` are `property_features` rows. No new column.

## Migration not applied

`supabase/migrations/20261121195500_account_briefs.sql` adds `roommate_profiles.brief` and `tenant_preferences.intake`. Until it is applied, those two JSON blobs stay on the device and the existing columns still update.

`supabase/migrations/20261122193000_roommate_same_city.sql` adds `list_roommate_seekers_in_city(p_city)`. The feeds do not use it to hide other cities.

`supabase/migrations/20261122193100_ahmedabad_demo_seed.sql` inserts Ahmedabad demo homes and marks them with `property_features` `wizard:demo` = `ahmedabad`. It runs only when an auth user `demo-ahmedabad@homizi.app` already exists. It does not create that user and does not call a photo service. Photos are the existing `homizi.netlify.app/demo_media` files.
