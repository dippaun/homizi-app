-- Publish rules for listings and requirements.
-- Clients can insert a draft and photo slots. They cannot write status or moderation.
begin;
select no_plan();

select tests.create_supabase_user(
  'host_list',
  'list_host@example.test',
  '+910000000061'
);
select tests.create_supabase_user(
  'stranger_list',
  'list_stranger@example.test',
  '+910000000062'
);

select tests.authenticate_as('host_list');
set local role authenticated;

insert into public.properties (
  id,
  host_user_id,
  title,
  locality,
  city,
  property_type,
  furnishing,
  rent_inr
) values (
  '66666666-6666-4666-8666-666666666601',
  auth.uid(),
  'Draft home',
  'Baner',
  'Pune',
  'apartment',
  'semi_furnished',
  18000
);

select is(
  (
    select status::text
    from public.properties
    where id = '66666666-6666-4666-8666-666666666601'
  ),
  'draft',
  'a new property stays draft when status is not supplied'
);

select throws_ok(
  $$update public.properties
    set status = 'published'
    where id = '66666666-6666-4666-8666-666666666601'$$,
  '42501',
  'permission denied for table properties',
  'the owner cannot set listing status directly'
);

select throws_ok(
  $$insert into public.properties (
      host_user_id, title, locality, city, property_type, furnishing, rent_inr, status
    ) values (
      auth.uid(), 'Nope', 'Baner', 'Pune', 'apartment', 'furnished', 1000, 'published'
    )$$,
  '42501',
  'permission denied for table properties',
  'clients cannot insert a listing status'
);

select is(
  (
    public.publish_listing('66666666-6666-4666-8666-666666666601') ->> 'error'
  ),
  'photos',
  'publish_listing refuses a listing with fewer than 3 photos'
);

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('66666666-6666-4666-8666-666666666601', 'slots/0.slot', 0, 'living'),
  ('66666666-6666-4666-8666-666666666601', 'slots/1.slot', 1, 'bedroom'),
  ('66666666-6666-4666-8666-666666666601', 'slots/2.slot', 2, 'kitchen');

select throws_ok(
  $$update public.property_photos
    set moderation_status = 'approved'
    where property_id = '66666666-6666-4666-8666-666666666601'$$,
  '42501',
  'permission denied for table property_photos',
  'photo moderation status is not client-writable'
);

select is(
  (
    public.publish_listing('66666666-6666-4666-8666-666666666601') ->> 'ok'
  ),
  'true',
  'publish_listing accepts three photo slots'
);

select is(
  (
    select status::text
    from public.properties
    where id = '66666666-6666-4666-8666-666666666601'
  ),
  'published',
  'the server function marks the listing published'
);

insert into public.properties (
  id,
  host_user_id,
  title,
  locality,
  city,
  property_type,
  furnishing,
  rent_inr
) values (
  '66666666-6666-4666-8666-666666666604',
  auth.uid(),
  'Free room',
  'Baner',
  'Pune',
  'apartment',
  'furnished',
  0
);

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('66666666-6666-4666-8666-666666666604', 'slots/0.slot', 0, 'living'),
  ('66666666-6666-4666-8666-666666666604', 'slots/1.slot', 1, 'bedroom'),
  ('66666666-6666-4666-8666-666666666604', 'slots/2.slot', 2, 'kitchen');

select is(
  (
    public.publish_listing('66666666-6666-4666-8666-666666666604') ->> 'error'
  ),
  'incomplete',
  'publish_listing rejects a zero rent'
);

insert into public.listing_requirements (
  id,
  user_id,
  city,
  localities,
  budget_min_inr,
  budget_max_inr,
  occupancy
) values (
  '66666666-6666-4666-8666-666666666602',
  auth.uid(),
  'Pune',
  array['Baner'],
  10000,
  20000,
  1
);

select is(
  (
    select status::text
    from public.listing_requirements
    where id = '66666666-6666-4666-8666-666666666602'
  ),
  'draft',
  'a new requirement stays draft'
);

select throws_ok(
  $$update public.listing_requirements
    set status = 'published'
    where id = '66666666-6666-4666-8666-666666666602'$$,
  '42501',
  'permission denied for table listing_requirements',
  'the owner cannot set requirement status directly'
);

select is(
  (
    public.publish_requirement('66666666-6666-4666-8666-666666666602') ->> 'ok'
  ),
  'true',
  'publish_requirement marks a complete requirement published'
);

insert into public.listing_requirements (
  id,
  user_id,
  city,
  localities,
  budget_min_inr,
  budget_max_inr
) values (
  '66666666-6666-4666-8666-666666666603',
  auth.uid(),
  '',
  array['Baner'],
  1000,
  2000
);

select is(
  (
    public.publish_requirement('66666666-6666-4666-8666-666666666603') ->> 'error'
  ),
  'incomplete',
  'publish_requirement rejects an empty city'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('stranger_list');
set local role authenticated;

select is(
  (
    public.publish_listing('66666666-6666-4666-8666-666666666601') ->> 'error'
  ),
  'not_owner',
  'a stranger cannot publish someone else''s listing'
);

select throws_ok(
  $$insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
    values (
      '66666666-6666-4666-8666-666666666601',
      'stranger.slot',
      9,
      'other'
    )$$,
  '42501',
  'new row violates row-level security policy for table "property_photos"',
  'a stranger cannot add photo slots to someone else''s listing'
);

select * from finish();
rollback;
