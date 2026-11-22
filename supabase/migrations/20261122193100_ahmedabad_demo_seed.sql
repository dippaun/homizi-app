-- Not applied by the app.
-- Seeds one Ahmedabad demo host and three published homes.
-- Does not create an auth user and does not call a photo API.
-- Photos are the existing public files at homizi.netlify.app/demo_media.
-- Create the auth user demo-ahmedabad@homizi.app first (Dashboard or
-- the local tests.create_supabase_user helper). Until that user exists,
-- this file changes nothing.
-- Rows are marked demo: profiles.public_bio starts with "HOMIZI demo"
-- and property_features has wizard:demo = ahmedabad.

do $$
declare
  v_host uuid;
begin
  select id into v_host
  from auth.users
  where lower(email) = 'demo-ahmedabad@homizi.app'
  limit 1;

  if v_host is null then
    raise notice 'Skip Ahmedabad demo seed: no auth user demo-ahmedabad@homizi.app.';
    return;
  end if;

  insert into public.users (id, status, primary_role)
  values (v_host, 'active', 'host')
  on conflict (id) do update
    set status = 'active',
        primary_role = 'host',
        updated_at = now();

  insert into public.profiles (
    user_id, display_name, occupation, public_bio, avatar_path, primary_role
  ) values (
    v_host,
    'Meera Shah',
    'Product designer',
    'HOMIZI demo. Sample profile for Ahmedabad. Not a real person.',
    'https://homizi.netlify.app/demo_media/avatar_03.webp',
    'host'
  )
  on conflict (user_id) do update
    set display_name = excluded.display_name,
        occupation = excluded.occupation,
        public_bio = excluded.public_bio,
        avatar_path = excluded.avatar_path,
        primary_role = 'host',
        updated_at = now();

  insert into public.roommate_profiles (
    user_id, discoverable, open_to_flatmates, seeking_role, city, localities,
    budget_min_inr, budget_max_inr, gender, food, smoking, pets, sleep,
    languages, age, thoughts
  ) values (
    v_host, true, true, 'tenant', 'Ahmedabad', array['Satellite', 'Bopal'],
    12000, 22000, 'woman', 'veg', 'never', 'none', 'flexible',
    array['Gujarati', 'Hindi', 'English'], 27,
    'HOMIZI demo roommate profile in Ahmedabad.'
  )
  on conflict (user_id) do update
    set discoverable = true,
        open_to_flatmates = true,
        city = 'Ahmedabad',
        localities = array['Satellite', 'Bopal'],
        thoughts = excluded.thoughts,
        updated_at = now();

  insert into public.properties (
    id, host_user_id, title, locality, city, property_type, furnishing,
    rent_inr, deposit_inr, status, published_at, occupancy_max,
    approx_latitude, approx_longitude
  ) values
    (
      'a11d0001-0000-4000-8000-000000000001', v_host,
      'Furnished room in Satellite', 'Satellite', 'Ahmedabad',
      'private_room', 'furnished', 14500, 29000, 'published', now(), 1,
      23.030, 72.517
    ),
    (
      'a11d0001-0000-4000-8000-000000000002', v_host,
      'Shared flat near Bopal', 'Bopal', 'Ahmedabad',
      'shared_room', 'semi_furnished', 9800, 19600, 'published', now(), 2,
      23.031, 72.476
    ),
    (
      'a11d0001-0000-4000-8000-000000000003', v_host,
      '2BHK in Navrangpura', 'Navrangpura', 'Ahmedabad',
      'apartment', 'furnished', 28000, 56000, 'published', now(), 3,
      23.037, 72.561
    )
  on conflict (id) do update
    set title = excluded.title,
        locality = excluded.locality,
        city = excluded.city,
        rent_inr = excluded.rent_inr,
        status = 'published',
        published_at = coalesce(public.properties.published_at, now()),
        updated_at = now();

  insert into public.property_features (property_id, feature_key, value) values
    ('a11d0001-0000-4000-8000-000000000001', 'wizard:demo', 'ahmedabad'),
    ('a11d0001-0000-4000-8000-000000000002', 'wizard:demo', 'ahmedabad'),
    ('a11d0001-0000-4000-8000-000000000003', 'wizard:demo', 'ahmedabad')
  on conflict (property_id, feature_key) do update
    set value = excluded.value;

  insert into public.property_photos (
    id, property_id, storage_path, sort_order, photo_type, moderation_status
  ) values
    (
      'a11d0001-0000-4000-8000-000000000011',
      'a11d0001-0000-4000-8000-000000000001',
      'https://homizi.netlify.app/demo_media/bed_01.webp', 0, 'bedroom', 'approved'
    ),
    (
      'a11d0001-0000-4000-8000-000000000012',
      'a11d0001-0000-4000-8000-000000000001',
      'https://homizi.netlify.app/demo_media/living_01.webp', 1, 'living', 'approved'
    ),
    (
      'a11d0001-0000-4000-8000-000000000021',
      'a11d0001-0000-4000-8000-000000000002',
      'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living', 'approved'
    ),
    (
      'a11d0001-0000-4000-8000-000000000022',
      'a11d0001-0000-4000-8000-000000000002',
      'https://homizi.netlify.app/demo_media/kitchen_02.webp', 1, 'kitchen', 'approved'
    ),
    (
      'a11d0001-0000-4000-8000-000000000031',
      'a11d0001-0000-4000-8000-000000000003',
      'https://homizi.netlify.app/demo_media/exterior_03.webp', 0, 'exterior', 'approved'
    ),
    (
      'a11d0001-0000-4000-8000-000000000032',
      'a11d0001-0000-4000-8000-000000000003',
      'https://homizi.netlify.app/demo_media/living_03.webp', 1, 'living', 'approved'
    )
  on conflict (id) do update
    set storage_path = excluded.storage_path,
        moderation_status = 'approved';
end $$;
