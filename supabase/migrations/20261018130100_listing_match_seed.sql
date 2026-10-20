-- Listing match inputs and a detailed requirement for test@homizi.in.
-- The score itself stays in the client until requirement_listing_match lands.
-- Safe to run again.

alter table public.properties
  add column if not exists listing_verified boolean not null default false;

comment on column public.properties.listing_verified is
  'The listing was reviewed. This is not an Aadhaar or face check.';

alter table public.listing_requirements
  add column if not exists bedrooms smallint,
  add column if not exists food_rule text,
  add column if not exists pets_rule text,
  add column if not exists household_rule text,
  add column if not exists wanted_amenities text[] not null default '{}';

alter table public.listing_requirements
  drop constraint if exists listing_requirements_bedrooms;

alter table public.listing_requirements
  add constraint listing_requirements_bedrooms
  check (bedrooms is null or bedrooms between 0 and 10);

alter table public.listing_requirements
  drop constraint if exists listing_requirements_food_rule;

alter table public.listing_requirements
  add constraint listing_requirements_food_rule
  check (food_rule is null or food_rule in ('veg_only', 'non_veg_ok'));

alter table public.listing_requirements
  drop constraint if exists listing_requirements_pets_rule;

alter table public.listing_requirements
  add constraint listing_requirements_pets_rule
  check (pets_rule is null or pets_rule in ('required', 'avoid'));

alter table public.listing_requirements
  drop constraint if exists listing_requirements_household_rule;

alter table public.listing_requirements
  add constraint listing_requirements_household_rule
  check (
    household_rule is null
    or household_rule in ('family', 'bachelors', 'female', 'any')
  );

grant insert (
  bedrooms, food_rule, pets_rule, household_rule, wanted_amenities
) on public.listing_requirements to authenticated;

grant update (
  bedrooms, food_rule, pets_rule, household_rule, wanted_amenities
) on public.listing_requirements to authenticated;

do $homizi_match_seed$
declare
  v_host uuid := 'c0ffee00-0000-4000-8000-000000000001';
  v_tenant uuid;
  v_requirement uuid := 'a1019100-0000-4000-8000-0000000000aa';
begin
  if to_regclass('auth.users') is not null then
    select id into v_tenant
    from auth.users
    where lower(email) = 'test@homizi.in'
    limit 1;
  end if;

  if v_tenant is null then
    raise notice 'test@homizi.in is not in auth.users; requirement skipped';
  else
    insert into public.users (id, status)
    values (v_tenant, 'active')
    on conflict (id) do nothing;

    insert into public.profiles (user_id, display_name, occupation)
    values (v_tenant, 'Test tenant', 'Product designer')
    on conflict (user_id) do nothing;

    -- furnishing is an enum until 20261019103000, then a text array.
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'listing_requirements'
        and column_name = 'furnishing'
        and data_type = 'ARRAY'
    ) then
    insert into public.listing_requirements (
      id, user_id, city, localities, budget_min_inr, budget_max_inr,
      move_in_date, occupancy, property_types, furnishing, lifestyle, status,
      bedrooms, food_rule, pets_rule, household_rule, wanted_amenities
    )
    values (
      v_requirement,
      v_tenant,
      'Bengaluru',
      array['Koramangala', 'Whitefield', 'HSR Layout'],
      18000,
      28000,
      date '2026-11-20',
      2,
      array['apartment']::public.property_type[],
      array['furnished']::text[],
      array['pets_ok']::text[],
      'published'::public.listing_status,
      2,
      'non_veg_ok',
      'required',
      'family',
      array['Lift', 'Power backup']
    )
    on conflict (id) do update
    set user_id = excluded.user_id,
        city = excluded.city,
        localities = excluded.localities,
        budget_min_inr = excluded.budget_min_inr,
        budget_max_inr = excluded.budget_max_inr,
        move_in_date = excluded.move_in_date,
        occupancy = excluded.occupancy,
        property_types = excluded.property_types,
        furnishing = excluded.furnishing,
        lifestyle = excluded.lifestyle,
        status = excluded.status,
        bedrooms = excluded.bedrooms,
        food_rule = excluded.food_rule,
        pets_rule = excluded.pets_rule,
        household_rule = excluded.household_rule,
        wanted_amenities = excluded.wanted_amenities,
        updated_at = now();
    else
    insert into public.listing_requirements (
      id, user_id, city, localities, budget_min_inr, budget_max_inr,
      move_in_date, occupancy, property_types, furnishing, lifestyle, status,
      bedrooms, food_rule, pets_rule, household_rule, wanted_amenities
    )
    values (
      v_requirement,
      v_tenant,
      'Bengaluru',
      array['Koramangala', 'Whitefield', 'HSR Layout'],
      18000,
      28000,
      date '2026-11-20',
      2,
      array['apartment']::public.property_type[],
      'furnished'::public.furnishing,
      array['pets_ok']::text[],
      'published'::public.listing_status,
      2,
      'non_veg_ok',
      'required',
      'family',
      array['Lift', 'Power backup']
    )
    on conflict (id) do update
    set user_id = excluded.user_id,
        city = excluded.city,
        localities = excluded.localities,
        budget_min_inr = excluded.budget_min_inr,
        budget_max_inr = excluded.budget_max_inr,
        move_in_date = excluded.move_in_date,
        occupancy = excluded.occupancy,
        property_types = excluded.property_types,
        furnishing = excluded.furnishing,
        lifestyle = excluded.lifestyle,
        status = excluded.status,
        bedrooms = excluded.bedrooms,
        food_rule = excluded.food_rule,
        pets_rule = excluded.pets_rule,
        household_rule = excluded.household_rule,
        wanted_amenities = excluded.wanted_amenities,
        updated_at = now();
    end if;
  end if;

  if not exists (select 1 from public.users where id = v_host) then
    raise notice 'staging host missing; match listings skipped';
    return;
  end if;

  insert into public.properties (
    id, host_user_id, title, locality, city, property_type, furnishing,
    rent_inr, deposit_inr, maintenance_inr, occupancy_max, status,
    available_from, published_at, address_visibility,
    area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
    gated_society, floor_no, total_floors, approx_latitude, approx_longitude,
    listing_verified
  )
  values
    (
      'b1019101-0000-4000-8000-000000000101'::uuid, v_host,
      'Sunlit 2BHK in Koramangala', 'Koramangala', 'Bengaluru',
      'apartment'::public.property_type, 'furnished'::public.furnishing,
      22000, 80000, 1100, 3, 'published'::public.listing_status,
      date '2026-11-01', timestamptz '2026-10-16 09:00:00+00',
      'locality_only'::public.address_visibility,
      980, array['family']::text[], true, true, true, true, 3, 7,
      12.935, 77.624, true
    ),
    (
      'b1019102-0000-4000-8000-000000000102'::uuid, v_host,
      'Furnished 2BHK in Whitefield', 'Whitefield', 'Bengaluru',
      'apartment'::public.property_type, 'furnished'::public.furnishing,
      26000, 78000, 1200, 3, 'published'::public.listing_status,
      date '2026-11-05', timestamptz '2026-10-16 09:00:00+00',
      'locality_only'::public.address_visibility,
      1100, array['family']::text[], true, true, true, true, 4, 8,
      12.970, 77.750, true
    ),
    (
      'b1019103-0000-4000-8000-000000000103'::uuid, v_host,
      '2 BHK near HSR Layout BDA', 'HSR Layout', 'Bengaluru',
      'apartment'::public.property_type, 'semi_furnished'::public.furnishing,
      18500, 55000, 900, 2, 'published'::public.listing_status,
      date '2026-11-01', timestamptz '2026-10-16 09:00:00+00',
      'locality_only'::public.address_visibility,
      980, array['family']::text[], true, true, true, false, 2, 5,
      12.912, 77.645, true
    )
  on conflict (id) do update
  set host_user_id = excluded.host_user_id,
      title = excluded.title,
      locality = excluded.locality,
      city = excluded.city,
      property_type = excluded.property_type,
      furnishing = excluded.furnishing,
      rent_inr = excluded.rent_inr,
      deposit_inr = excluded.deposit_inr,
      status = 'published',
      available_from = excluded.available_from,
      published_at = excluded.published_at,
      preferred_tenants = excluded.preferred_tenants,
      pets_allowed = excluded.pets_allowed,
      non_veg_allowed = excluded.non_veg_allowed,
      listing_verified = excluded.listing_verified,
      approx_latitude = excluded.approx_latitude,
      approx_longitude = excluded.approx_longitude;

  insert into public.property_features (property_id, feature_key, value)
  values
    ('b1019101-0000-4000-8000-000000000101'::uuid, 'bedrooms', '2'),
    ('b1019101-0000-4000-8000-000000000101'::uuid, 'amenity:lift', 'yes'),
    ('b1019101-0000-4000-8000-000000000101'::uuid, 'amenity:power_backup', 'yes'),
    ('b1019102-0000-4000-8000-000000000102'::uuid, 'bedrooms', '2'),
    ('b1019102-0000-4000-8000-000000000102'::uuid, 'amenity:lift', 'yes'),
    ('b1019102-0000-4000-8000-000000000102'::uuid, 'amenity:power_backup', 'yes'),
    ('b1019103-0000-4000-8000-000000000103'::uuid, 'bedrooms', '2'),
    ('b1019103-0000-4000-8000-000000000103'::uuid, 'amenity:lift', 'yes'),
    ('b1019103-0000-4000-8000-000000000103'::uuid, 'amenity:power_backup', 'yes')
  on conflict (property_id, feature_key) do update
  set value = excluded.value;
end
$homizi_match_seed$;
