# Requirement and listing match

`public.requirement_listing_match(listing_id uuid, requirement_id uuid)` returns an integer from 0 to 100. It is created in `supabase/migrations/20261018120100_roles_requirements_brokers.sql`.

Agent K can call this function for listing match scores. Do not copy the weights into another SQL function. Demo mode mirrors them in `lib/features/roles/requirement_match.dart` so a screen still has a number when Supabase is not configured. The database function is the source of truth.

The function is `security invoker`. Row level security still applies. A missing listing or a requirement the caller cannot see scores 0. It does not read gender, religion, caste, age, phone, or email.

`public.seekers_for_my_listings()` lists published, discoverable requirements scored against the caller's own listings. It returns the best listing per requirement. It does not return a phone or an email. Contact stays on the existing mutual-match and consent flow.

## Weights

A full match is 100. A partial budget does not stack on a full budget.

| Signal | Points | Rule |
| --- | ---: | --- |
| City | 25 | Listing city equals the requirement city, ignoring case. |
| Locality | 20 | Listing locality equals one of the requirement localities, ignoring case. |
| Budget | 20 | Monthly rent is inside the requirement minimum and maximum. |
| Budget, near | 10 | Rent is outside that range but inside 80% of the minimum and 120% of the maximum. |
| Home type | 15 | Room type fits the listing property type. See below. |
| Furnishing | 10 | Furnishing matches, or the requirement has no furnishing. |
| Amenities | 5 | Share of requested amenities present on the listing, rounded. No requested amenities scores 5. |
| Timing | 5 | Either date is empty, or the listing is available on or before 30 days after the move-in date. |

Home type:

| Requirement `room_type` | Listing `property_type` |
| --- | --- |
| empty | The listing type is in `property_types`, or that list is empty. |
| `private_room` | `private_room`, `apartment`, `independent_house`, `villa` |
| `shared` | `shared_room`, `pg` |
| `1rk` | `studio`, `apartment` |
| `1bhk` | `apartment`, `independent_house`, `villa`, `studio` |
| `2bhk`, `3bhk`, `4bhk` | `apartment`, `independent_house`, `villa` |

Requested amenities are `listing_requirements.amenities`: `wifi`, `ac`, `washing_machine`, `power_backup`, `gym`, `security`. A listing has an amenity when `property_features.feature_key` is `amenity:<key>`.

## Who can see a requirement

`listing_requirements` select policy:

- The owner always sees their own row.
- Anyone else sees a row only when it is `published`, `discoverable` is true, and `is_blocked_with` is false.
- Update stays owner-only. A broker cannot edit another person's requirement.

`discoverable` defaults to true. The requirements flow calls it "Let verified hosts and brokers contact me". Turning it off hides the brief from hosts and brokers. It does not share a phone number.

## Roles

`profiles.primary_role` is `roommate`, `tenant`, `host`, or `broker`. Legacy `users.primary_role` stays `unset`, `tenant`, `host`, or `both`.

| Legacy value | Product role |
| --- | --- |
| `tenant` | `tenant` |
| `host` | `host` |
| `host` and `host_profiles.host_category = broker` | `broker` |
| `both` | `tenant` |
| `unset` | empty, so the role picker runs |

`currentRoleProvider` in `lib/features/roles/role_provider.dart` exposes `HomiziRole`.
