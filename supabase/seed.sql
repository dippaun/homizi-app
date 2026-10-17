-- Fake local users only. Password for every account: local-dev-only
-- Do not point this file at a hosted project.

select tests.create_supabase_user('ananya', 'ananya@example.test', '+910000000001');
select tests.create_supabase_user('rohan', 'rohan@example.test', '+910000000002');
select tests.create_supabase_user('priya', 'priya@example.test', '+910000000003');
select tests.create_supabase_user('kabir', 'kabir@example.test', '+910000000004');

update public.users set primary_role = 'tenant' where id = tests.get_supabase_uid('ananya');
update public.users set primary_role = 'host' where id = tests.get_supabase_uid('rohan');
update public.users set primary_role = 'tenant' where id = tests.get_supabase_uid('priya');
update public.users set primary_role = 'host' where id = tests.get_supabase_uid('kabir');

update public.profiles
set display_name = 'Ananya Sharma', occupation = 'Product designer', public_bio = 'Looking in Koramangala.'
where user_id = tests.get_supabase_uid('ananya');
update public.profiles
set display_name = 'Rohan Mehta', occupation = 'Host', verification_status = 'mock_verified'
where user_id = tests.get_supabase_uid('rohan');
update public.profiles
set display_name = 'Priya Nair', occupation = 'Analyst'
where user_id = tests.get_supabase_uid('priya');
update public.profiles
set display_name = 'Kabir Sen', occupation = 'Host'
where user_id = tests.get_supabase_uid('kabir');

insert into public.host_profiles (user_id, host_category)
values
  (tests.get_supabase_uid('rohan'), 'owner'),
  (tests.get_supabase_uid('kabir'), 'flatmate');

insert into public.listing_requirements (
  id, user_id, city, localities, budget_min_inr, budget_max_inr, move_in_date, occupancy, property_types, furnishing, status
) values (
  '11111111-1111-4111-8111-111111111101',
  tests.get_supabase_uid('ananya'),
  'Bengaluru',
  array['Koramangala'],
  15000,
  25000,
  date '2026-11-01',
  1,
  array['apartment']::public.property_type[],
  'furnished',
  'published'
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, deposit_inr, status, published_at, approx_latitude, approx_longitude
) values (
  '22222222-2222-4222-8222-222222222201',
  tests.get_supabase_uid('rohan'),
  'Sunlit 2BHK in Koramangala',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  22000,
  80000,
  'published',
  now(),
  12.935,
  77.624
);

insert into public.property_private_details (
  property_id, address_line, latitude, longitude
)
values (
  '22222222-2222-4222-8222-222222222201',
  'Demo lane, not a real address',
  12.935812,
  77.625104
);

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('22222222-2222-4222-8222-222222222201', 'seed/living.jpg', 0, 'living'),
  ('22222222-2222-4222-8222-222222222201', 'seed/bedroom.jpg', 1, 'bedroom'),
  ('22222222-2222-4222-8222-222222222201', 'seed/kitchen.jpg', 2, 'kitchen');

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr,
  status, approx_latitude, approx_longitude
) values (
  '22222222-2222-4222-8222-222222222202',
  tests.get_supabase_uid('kabir'),
  'Draft room that must stay private',
  'Baner',
  'Pune',
  'private_room',
  'semi_furnished',
  14000,
  'draft',
  18.559,
  73.787
);

insert into public.interests (actor_user_id, target_type, target_id, action)
values
  (tests.get_supabase_uid('ananya'), 'property', '22222222-2222-4222-8222-222222222201', 'like'),
  (tests.get_supabase_uid('rohan'), 'listing_requirement', '11111111-1111-4111-8111-111111111101', 'like');

insert into public.matches (id, participant_a, participant_b)
select
  '33333333-3333-4333-8333-333333333301',
  least(tests.get_supabase_uid('ananya'), tests.get_supabase_uid('rohan')),
  greatest(tests.get_supabase_uid('ananya'), tests.get_supabase_uid('rohan'));

insert into public.consent_records (user_id, policy_type, policy_version)
select tests.get_supabase_uid('ananya'), 'terms'::public.consent_policy_type, '2026-10-11-draft'
union all
select tests.get_supabase_uid('ananya'), 'privacy'::public.consent_policy_type, '2026-10-11-draft';
