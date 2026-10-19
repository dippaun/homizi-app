# Roommate compatibility

This section is only the roommate score. Listing and requirement match is a different score and should stay in its own section above this one when both land in this file. The two scores do not share a function or a weight table.

The home listing score is `public.score_compatibility`. Roommate compatibility does not call it.

`public.roommate_compatibility(a uuid, b uuid)` returns an integer from 0 to 100 for two people. The breakdown is `public.roommate_compatibility_breakdown`. The Dart mirror used in demo mode is `lib/features/roommates/domain/roommate_compatibility.dart`. Missing roommate profile rows score 0. The score is symmetric. Age is shown on the card and is not an input. Religion and caste are not inputs.

A person calling the public functions must be one of the two ids, or staff. Anonymous calls are rejected. `public.list_roommate_seekers` returns discoverable people only. A roommate with `discoverable` false stays out. A tenant stays out unless `open_to_flatmates` is true. The list does not include phone, email, or flatmate notes. Those stay on the caller's own `roommate_profiles` row and on `private_contacts`.

## Weights

Hard requirements, 60 points:

| Row | Max | Rule |
| --- | --- | --- |
| City | 12 | 12 when the cities match. 0 otherwise. |
| Locality | 10 | 10 when a locality overlaps. 6 when the city matches and a list is empty. 4 when the city matches and the lists do not overlap. 0 when the cities differ. |
| Budget | 12 | 12 when the ranges overlap. 6 when one side is unset, or the gap is within 20% (`gap * 5 <= bound`). 0 otherwise. |
| Move-in | 8 | 8 when a date is unset (flexible), or the dates are within 30 days. 4 within 60 days. 0 after that. |
| Gender preference | 8 | 8 when each person accepts the other. 0 otherwise. |
| Occupancy | 4 | 4 when either side is unset or `any`, or the values match. |
| Food | 2 | 0 only when the diets conflict and someone marked food as a dealbreaker. |
| Smoking | 2 | 0 only when one person never smokes, the values differ, and someone marked smoking as a dealbreaker. Sometimes and regularly do not conflict. |
| Pets | 2 | 0 only when one person has pets and the other wants none, and someone marked pets as a dealbreaker. `ok` does not conflict. |

Lifestyle and notes, 40 points:

| Row | Max | Rule |
| --- | --- | --- |
| Sleep | 5 | Order early, flexible, night. Same is 5, one step is 3, two steps is 0, unknown is 3. |
| Cleanliness | 5 | Difference 0 is 5, 1 is 3, 2 is 1, otherwise 0. A null or a value outside 1–5 is 3. |
| Social | 5 | Order quiet, balanced, social. Same scale as sleep. |
| Work from home | 4 | Equal is 4. An empty side is 2. One hybrid is 2. Office against home is 0. |
| Cooking | 4 | Order rarely, sometimes, often. Same is 4, one step is 2, two steps is 0, unknown is 2. |
| Guests | 4 | Order rare, sometimes, often. Same scale as cooking. |
| Languages | 4 | An empty side is 2. An overlap is 4. No overlap is 0. |
| Hobbies | 4 | Same as languages. |
| Flatmate notes | 5 | Tokens are lowercase words of 4 or more letters, with with, this, that, your, want, looking, from, they, and their removed. An empty side is 2. Two shared tokens are 5. One shared token is 3. None is 0. |

A breakdown row is a check when its points equal its maximum. A partial row is a cross.

Gender preference accepts `any` or an empty preference, an empty or undisclosed other person, `women` with `woman`, `men` with `man`, and `same` when the genders match. An unknown self gender accepts `same`.

Food conflicts when one side is veg and the other is not, or when one side is eggetarian and the other is non-veg. `any`, or the same value, is not a conflict.

## Examples

Against the staging viewer (Bengaluru, Koramangala and Indiranagar, ₹18,000–₹32,000, move-in 1 Dec 2026, woman, veg and non-smoker dealbreakers, early, quiet, hybrid):

- Mira Shah scores 95. The city, locality, budget, and move-in match. Cleanliness is one step apart and her flatmate note is empty.
- Rohan Mehta scores 40. He is in Mumbai, with a later sleep schedule, a different social level, and no shared language or hobby.

The Roommates tab sorts by this score, highest first.
