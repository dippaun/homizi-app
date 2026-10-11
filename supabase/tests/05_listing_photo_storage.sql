-- Listing photo objects stay in the owner's folder. Moderation is not client-writable.
begin;
select no_plan();

select tests.create_supabase_user(
  'photo_owner',
  'photo_owner@example.test',
  '+910000000081'
);
select tests.create_supabase_user(
  'photo_stranger',
  'photo_stranger@example.test',
  '+910000000082'
);

select is(
  (select public from storage.buckets where id = 'listing-photos'),
  false,
  'listing-photos is a private bucket'
);

select is(
  (select file_size_limit from storage.buckets where id = 'listing-photos'),
  5242880::bigint,
  'listing photos are limited to 5 MB'
);

select ok(
  'image/jpeg' = any (
    select allowed_mime_types
    from storage.buckets
    where id = 'listing-photos'
  ),
  'listing photos accept jpeg'
);

select tests.authenticate_as('photo_owner');
set local role authenticated;

insert into storage.objects (bucket_id, name)
values (
  'listing-photos',
  auth.uid()::text || '/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/cover.jpg'
);

insert into storage.objects (bucket_id, name)
values (
  'listing-photos',
  auth.uid()::text || '/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/private.jpg'
);

select is(
  (
    select count(*)::int
    from storage.objects
    where bucket_id = 'listing-photos'
      and name like '%/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/cover.jpg'
  ),
  1,
  'the owner can read their own listing photo'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'listing-photos',
      'someone-else/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/cover.jpg'
    )$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'a photo upload cannot use another account folder'
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
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  auth.uid(),
  'Photo home',
  'Baner',
  'Pune',
  'apartment',
  'semi_furnished',
  18000
);

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    auth.uid()::text || '/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/cover.jpg',
    0,
    'living'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    auth.uid()::text || '/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/1.slot',
    1,
    'bedroom'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    auth.uid()::text || '/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/2.slot',
    2,
    'kitchen'
  );

select is(
  (
    select moderation_status::text
    from public.property_photos
    where property_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
      and sort_order = 0
  ),
  'pending',
  'a new listing photo stays pending when moderation is not supplied'
);

select throws_ok(
  $$update public.property_photos
    set moderation_status = 'approved'
    where property_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'$$,
  '42501',
  'permission denied for table property_photos',
  'the owner cannot approve their own photo'
);

select is(
  (
    public.publish_listing('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') ->> 'ok'
  ),
  'true',
  'publish_listing accepts the owner photo slots'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('photo_stranger');
set local role authenticated;

select is(
  (
    select count(*)::int
    from storage.objects
    where bucket_id = 'listing-photos'
      and name like '%/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/cover.jpg'
  ),
  1,
  'a published listing photo can be read by another signed-in user'
);

select is(
  (
    select count(*)::int
    from storage.objects
    where bucket_id = 'listing-photos'
      and name like '%/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/private.jpg'
  ),
  0,
  'an unpublished object stays hidden from another account'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'listing-photos',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1/nope.jpg'
    )$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'another account cannot upload into a foreign folder'
);

select * from finish();
rollback;
