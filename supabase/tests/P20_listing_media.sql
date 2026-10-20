-- Photo captions stay short and free of a phone number or email.
-- Clients still cannot approve a photo. Another account cannot write one.
-- The private bucket stays at 5 MB and does not accept video.
begin;
select no_plan();

select tests.create_supabase_user(
  'caption_owner',
  'caption_owner@example.test',
  '+910000000301'
);
select tests.create_supabase_user(
  'caption_stranger',
  'caption_stranger@example.test',
  '+910000000302'
);

select ok(
  has_column_privilege(
    'authenticated',
    'public.property_photos',
    'caption',
    'INSERT'
  ),
  'an owner may insert a caption'
);

select ok(
  has_column_privilege(
    'authenticated',
    'public.property_photos',
    'caption',
    'UPDATE'
  ),
  'an owner may update a caption'
);

select ok(
  not has_column_privilege(
    'authenticated',
    'public.property_photos',
    'moderation_status',
    'INSERT'
  ),
  'a client cannot insert moderation_status'
);

select ok(
  not has_column_privilege(
    'authenticated',
    'public.property_photos',
    'moderation_status',
    'UPDATE'
  ),
  'a client cannot update moderation_status'
);

select is(
  (select file_size_limit from storage.buckets where id = 'listing-photos'),
  5242880::bigint,
  'listing photos stay limited to 5 MB'
);

select ok(
  (
    select allowed_mime_types <@ array['image/jpeg', 'image/png', 'image/webp']::text[]
      and 'image/jpeg' = any (allowed_mime_types)
      and not ('video/mp4' = any (allowed_mime_types))
      and not ('image/gif' = any (allowed_mime_types))
    from storage.buckets
    where id = 'listing-photos'
  ),
  'the private bucket stays jpeg png and webp'
);

select is(
  public.listing_caption_issue('Morning light'),
  null,
  'a short caption is accepted'
);

select is(
  public.listing_caption_issue('Call 98765 43210'),
  'A caption cannot include a phone number.',
  'a spaced phone number is refused'
);

select is(
  public.listing_caption_issue('ada@example.test'),
  'A caption cannot include an email.',
  'an email is refused'
);

select tests.authenticate_as('caption_owner');
set local role authenticated;

insert into storage.objects (bucket_id, name)
values (
  'listing-photos',
  auth.uid()::text || '/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301/cover.jpg'
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
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301',
  auth.uid(),
  'Caption home',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  22000
);

insert into public.property_photos (
  property_id, storage_path, sort_order, photo_type, caption
) values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301',
  auth.uid()::text || '/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301/cover.jpg',
  0,
  'living',
  '  Morning light  '
);

insert into public.property_photos (
  property_id, storage_path, sort_order, photo_type
) values
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301',
    auth.uid()::text || '/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301/1.slot',
    1,
    'bedroom'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301',
    auth.uid()::text || '/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301/2.slot',
    2,
    'kitchen'
  );

select is(
  (
    select caption
    from public.property_photos
    where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
      and sort_order = 0
  ),
  'Morning light',
  'a caption is trimmed when it is saved'
);

select is(
  (
    select moderation_status::text
    from public.property_photos
    where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
      and sort_order = 0
  ),
  'pending',
  'a captioned photo stays pending'
);

select is(
  (
    select caption
    from public.property_photos
    where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
      and sort_order = 1
  ),
  null,
  'a photo without a caption stores null'
);

select throws_ok(
  $$update public.property_photos
    set moderation_status = 'approved'
    where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'$$,
  '42501',
  'permission denied for table property_photos',
  'the owner cannot approve their own photo'
);

select throws_ok(
  $$insert into public.property_photos (
      property_id, storage_path, sort_order, photo_type, moderation_status, caption
    ) values (
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301',
      auth.uid()::text || '/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301/extra.jpg',
      3,
      'bathroom',
      'approved',
      'Already checked'
    )$$,
  '42501',
  'permission denied for table property_photos',
  'a client cannot insert an approved photo'
);

select throws_ok(
  $$update public.property_photos
    set caption = 'Call +91 9876543210'
    where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
      and sort_order = 0$$,
  '22023',
  'phone number',
  'a caption cannot include a phone number'
);

select throws_ok(
  $$update public.property_photos
    set caption = 'Write to ada@example.test'
    where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
      and sort_order = 0$$,
  '22023',
  'email',
  'a caption cannot include an email'
);

select throws_ok(
  $$update public.property_photos
    set caption = repeat('a', 81)
    where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
      and sort_order = 0$$,
  '22023',
  '80 characters',
  'a caption longer than 80 characters is refused'
);

update public.property_photos
set caption = '   '
where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
  and sort_order = 1;

select is(
  (
    select caption
    from public.property_photos
    where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
      and sort_order = 1
  ),
  null,
  'a blank caption is stored as null'
);

update public.property_photos
set caption = 'Morning light'
where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
  and sort_order = 0;

select is(
  (
    public.publish_listing('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301') ->> 'ok'
  ),
  'true',
  'a caption does not block publish'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('caption_stranger');
set local role authenticated;

select is(
  (
    select caption
    from public.property_photos
    where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
      and sort_order = 0
  ),
  'Morning light',
  'a published caption can be read by another signed-in user'
);

update public.property_photos
set caption = 'Stolen line'
where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301';

select throws_ok(
  $$insert into public.property_photos (
      property_id, storage_path, sort_order, photo_type, caption
    ) values (
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301/nope.jpg',
      4,
      'other',
      'Not yours'
    )$$,
  '42501',
  'new row violates row-level security policy for table "property_photos"',
  'another account cannot insert a caption'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'listing-photos',
      'someone-else/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301/cover.jpg'
    )$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'another account cannot upload into a foreign folder'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('caption_owner');
set local role authenticated;

select is(
  (
    select caption
    from public.property_photos
    where property_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbb301'
      and sort_order = 0
  ),
  'Morning light',
  'another account cannot change the caption'
);

reset role;
select tests.clear_authentication();
set local role anon;

select throws_ok(
  $$select caption from public.property_photos$$,
  '42501',
  'permission denied for table property_photos',
  'an anonymous client cannot read captions'
);

select * from finish();
rollback;
