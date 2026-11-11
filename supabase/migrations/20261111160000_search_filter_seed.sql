-- One published home for each room-in-flat type, plus couple and LGBTQ+ tags.
-- Safe to run again. Skips when the staging catalog host is not present.
-- Paste after 20261106160000. Do not apply to staging from an agent.

do $homizi_filter_seed$
declare
  v_host uuid := 'c0ffee00-0000-4000-8000-000000000001';
  missing text := '';
begin
  if to_regclass('public.properties') is null
     or not exists (select 1 from public.users where id = v_host) then
    raise notice 'staging host missing; room-in-flat seed skipped';
    return;
  end if;

  insert into public.properties (
    id, host_user_id, title, locality, city, property_type, furnishing,
    rent_inr, deposit_inr, maintenance_inr, occupancy_max, status,
    available_from, published_at, address_visibility,
    area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
    gated_society, floor_no, total_floors, approx_latitude, approx_longitude
  )
  select
    id,
    v_host,
    title, locality, city, property_type, furnishing,
    rent_inr, deposit_inr, maintenance_inr, occupancy_max,
    'published'::public.listing_status,
    available_from, published_at, 'locality_only'::public.address_visibility,
    area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
    gated_society, floor_no, total_floors, approx_latitude, approx_longitude
  from (
    values
    ('d1000301-0000-4000-8000-000000000301'::uuid, '1 room in a 2BHK, Satellite', 'Satellite', 'Ahmedabad', 'room_in_2bhk'::public.property_type, 'semi_furnished'::public.furnishing, 9000, 18000, 0, 1, date '2026-11-05', timestamptz '2026-11-01 09:00:00+00', 180, array['bachelors']::text[], false, false, false, false, 2, 8, 23.028, 72.511),
    ('d1000302-0000-4000-8000-000000000302'::uuid, '1 room in a 3BHK, Bodakdev', 'Bodakdev', 'Ahmedabad', 'room_in_3bhk'::public.property_type, 'furnished'::public.furnishing, 18000, 36000, 0, 1, date '2026-11-10', timestamptz '2026-11-01 09:00:00+00', 220, array['any']::text[], true, true, false, false, 4, 10, 23.042, 72.510),
    ('d1000303-0000-4000-8000-000000000303'::uuid, '1 room in a 4BHK, Thaltej', 'Thaltej', 'Ahmedabad', 'room_in_4bhk'::public.property_type, 'unfurnished'::public.furnishing, 12500, 25000, 0, 1, date '2026-11-14', timestamptz '2026-11-01 09:00:00+00', 200, array['bachelors']::text[], false, false, true, false, 1, 4, 23.050, 72.496)
  ) as seed (
    id, title, locality, city, property_type, furnishing,
    rent_inr, deposit_inr, maintenance_inr, occupancy_max,
    available_from, published_at,
    area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
    gated_society, floor_no, total_floors, approx_latitude, approx_longitude
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
      address_visibility = 'locality_only',
      area_sqft = excluded.area_sqft,
      preferred_tenants = excluded.preferred_tenants,
      parking = excluded.parking,
      pets_allowed = excluded.pets_allowed,
      non_veg_allowed = excluded.non_veg_allowed,
      gated_society = excluded.gated_society,
      floor_no = excluded.floor_no,
      total_floors = excluded.total_floors,
      approx_latitude = excluded.approx_latitude,
      approx_longitude = excluded.approx_longitude;

  insert into public.property_features (property_id, feature_key, value)
  select property_id, feature_key, value
  from (
    values
    ('d1000301-0000-4000-8000-000000000301'::uuid, 'bedrooms', '2'),
    ('d1000301-0000-4000-8000-000000000301'::uuid, 'tag:couple_friendly', 'yes'),
    ('d1000302-0000-4000-8000-000000000302'::uuid, 'bedrooms', '3'),
    ('d1000302-0000-4000-8000-000000000302'::uuid, 'tag:couple_friendly', 'yes'),
    ('d1000302-0000-4000-8000-000000000302'::uuid, 'tag:lgbtq_friendly', 'yes'),
    ('d1000303-0000-4000-8000-000000000303'::uuid, 'bedrooms', '4'),
    ('d1000303-0000-4000-8000-000000000303'::uuid, 'tag:lgbtq_friendly', 'yes')
  ) as seed (property_id, feature_key, value)
  on conflict (property_id, feature_key) do update
  set value = excluded.value;

  insert into public.property_photos (
    id, property_id, storage_path, sort_order, photo_type, moderation_status
  )
  select
    id, property_id, storage_path, sort_order,
    photo_type::public.photo_type, 'approved'::public.moderation_status
  from (
    values
    ('e1000301-0000-4000-8000-000000000000'::uuid, 'd1000301-0000-4000-8000-000000000301'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
    ('e1000301-0000-4000-8000-000000000001'::uuid, 'd1000301-0000-4000-8000-000000000301'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
    ('e1000301-0000-4000-8000-000000000002'::uuid, 'd1000301-0000-4000-8000-000000000301'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
    ('e1000302-0000-4000-8000-000000000000'::uuid, 'd1000302-0000-4000-8000-000000000302'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
    ('e1000302-0000-4000-8000-000000000001'::uuid, 'd1000302-0000-4000-8000-000000000302'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
    ('e1000302-0000-4000-8000-000000000002'::uuid, 'd1000302-0000-4000-8000-000000000302'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
    ('e1000303-0000-4000-8000-000000000000'::uuid, 'd1000303-0000-4000-8000-000000000303'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
    ('e1000303-0000-4000-8000-000000000001'::uuid, 'd1000303-0000-4000-8000-000000000303'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
    ('e1000303-0000-4000-8000-000000000002'::uuid, 'd1000303-0000-4000-8000-000000000303'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen')
  ) as seed (id, property_id, storage_path, sort_order, photo_type)
  on conflict (id) do update
  set property_id = excluded.property_id,
      storage_path = excluded.storage_path,
      sort_order = excluded.sort_order,
      photo_type = excluded.photo_type,
      moderation_status = 'approved';

  if not exists (
    select 1 from public.properties
    where status = 'published' and property_type = 'room_in_2bhk'
  ) then
    missing := missing || 'room_in_2bhk; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and property_type = 'room_in_3bhk'
  ) then
    missing := missing || 'room_in_3bhk; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and property_type = 'room_in_4bhk'
  ) then
    missing := missing || 'room_in_4bhk; ';
  end if;
  if not exists (
    select 1
    from public.properties p
    join public.property_features f on f.property_id = p.id
    where p.status = 'published'
      and p.city = 'Ahmedabad'
      and f.feature_key = 'tag:couple_friendly'
  ) then
    missing := missing || 'Ahmedabad couple friendly; ';
  end if;
  if not exists (
    select 1
    from public.properties p
    join public.property_features f on f.property_id = p.id
    where p.status = 'published'
      and p.city = 'Ahmedabad'
      and f.feature_key = 'tag:lgbtq_friendly'
  ) then
    missing := missing || 'Ahmedabad LGBTQ+ friendly; ';
  end if;
  if not exists (
    select 1
    from public.properties p
    join public.property_features couple
      on couple.property_id = p.id and couple.feature_key = 'tag:couple_friendly'
    join public.property_features lgbtq
      on lgbtq.property_id = p.id and lgbtq.feature_key = 'tag:lgbtq_friendly'
    where p.status = 'published'
  ) then
    missing := missing || 'both friendly tags; ';
  end if;

  if missing <> '' then
    raise exception 'filter coverage gaps: %', missing;
  end if;
end
$homizi_filter_seed$;
