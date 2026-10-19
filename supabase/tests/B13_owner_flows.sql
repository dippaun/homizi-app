-- Owner lifecycle, stats, mock badges, and reply time.
-- A stranger cannot read stats or change another person's listing.
begin;
select no_plan();

select tests.create_supabase_user(
  'own_host',
  'own_host@example.test',
  '+910000000081'
);
select tests.create_supabase_user(
  'own_tenant',
  'own_tenant@example.test',
  '+910000000082'
);

select is(
  (
    select count(*)::int
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'listing_status'
      and e.enumlabel in ('in_review', 'rented')
  ),
  2,
  'in_review and rented are listing statuses'
);

select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_badges'
      and column_name in ('email', 'phone', 'address_line', 'aadhaar')
  ),
  'user_badges exposes flags only'
);

select tests.authenticate_as('own_host');
set local role authenticated;

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr
) values (
  '77777777-7777-4777-8777-777777777710',
  auth.uid(),
  'Koramangala 2BHK',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  28000
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr
) values (
  '77777777-7777-4777-8777-777777777711',
  auth.uid(),
  'Draft in Baner',
  'Baner',
  'Pune',
  'apartment',
  'semi_furnished',
  15000
);

select is(
  (public.set_my_listing_status(
    '77777777-7777-4777-8777-777777777710',
    'submit_review'
  ) ->> 'status'),
  'in_review',
  'the owner can submit a complete draft for review'
);

select is(
  (public.set_my_listing_status(
    '77777777-7777-4777-8777-777777777710',
    'delete_draft'
  ) ->> 'error'),
  'not_draft',
  'a listing in review cannot be deleted as a draft'
);

select is(
  (public.set_my_listing_status(
    '77777777-7777-4777-8777-777777777711',
    'delete_draft'
  ) ->> 'deleted')::boolean,
  true,
  'the owner can delete a draft'
);

select is(
  (
    select count(*)::int
    from public.properties
    where id = '77777777-7777-4777-8777-777777777711'
  ),
  0,
  'the deleted draft row is gone'
);

select throws_ok(
  $$update public.properties
    set status = 'rented'
    where id = '77777777-7777-4777-8777-777777777710'$$,
  '42501',
  'permission denied for table properties',
  'the client still cannot write listing status directly'
);

select is(
  (public.get_my_listing_stats(
    '77777777-7777-4777-8777-777777777710'
  ) ->> 'ok')::boolean,
  true,
  'the owner can read listing stats before the home is live'
);

select is(
  jsonb_array_length(
    public.get_my_listing_stats(
      '77777777-7777-4777-8777-777777777710'
    ) -> 'days'
  ),
  30,
  'stats include thirty days'
);

select is(
  (public.get_my_listing_stats(
    '77777777-7777-4777-8777-777777777710'
  ) ? 'phone'),
  false,
  'stats do not include a phone'
);

select is(
  (select phone_verified
   from public.user_badges
   where user_id = tests.get_supabase_uid('own_host')),
  true,
  'a stored phone becomes the phone badge'
);

select is(
  (select id_verified_demo
   from public.user_badges
   where user_id = tests.get_supabase_uid('own_host')),
  false,
  'the demo ID badge starts off'
);

select is(
  (public.set_demo_id_badge(true) ->> 'id_verified_demo')::boolean,
  true,
  'the staging toggle sets the mock badge'
);

select is(
  (select verification_status::text
   from public.profiles
   where user_id = tests.get_supabase_uid('own_host')),
  'mock_verified',
  'the toggle stores mock_verified and no document'
);

reset role;
select tests.authenticate_as('own_tenant');
set local role authenticated;

select is(
  (public.get_my_listing_stats(
    '77777777-7777-4777-8777-777777777710'
  ) ->> 'error'),
  'not_owner',
  'another account cannot read listing stats'
);

select is(
  (public.set_my_listing_status(
    '77777777-7777-4777-8777-777777777710',
    'pause'
  ) ->> 'error'),
  'not_owner',
  'another account cannot pause the listing'
);

select is(
  (public.list_my_listings() -> 'listings')::text,
  '[]',
  'the tenant dashboard does not list the host homes'
);

reset role;
select set_config('request.jwt.claim.role', '', true);
select set_config('request.jwt.claim.sub', '', true);

insert into public.property_photos (
  property_id, storage_path, sort_order, photo_type
) values
  ('77777777-7777-4777-8777-777777777710', 'own/0.slot', 0, 'living'),
  ('77777777-7777-4777-8777-777777777710', 'own/1.slot', 1, 'bedroom'),
  ('77777777-7777-4777-8777-777777777710', 'own/2.slot', 2, 'kitchen');

insert into public.listing_views (viewer_id, property_id, viewed_on)
values (
  tests.get_supabase_uid('own_tenant'),
  '77777777-7777-4777-8777-777777777710',
  current_date
);

select throws_ok(
  $$insert into public.listing_views (viewer_id, property_id, viewed_on)
    values (
      tests.get_supabase_uid('own_tenant'),
      '77777777-7777-4777-8777-777777777710',
      current_date
    )$$,
  '23505',
  null,
  'one view per person per listing per day'
);

select tests.authenticate_as('own_host');
set local role authenticated;

select is(
  (public.publish_listing(
    '77777777-7777-4777-8777-777777777710'
  ) ->> 'ok')::boolean,
  true,
  'publish still requires the photo guard and then goes live'
);

select ok(
  (
    select published_until > now()
    from public.properties
    where id = '77777777-7777-4777-8777-777777777710'
  ),
  'publish opens a 30 day window'
);

select is(
  (
    public.get_my_listing_stats(
      '77777777-7777-4777-8777-777777777710'
    ) -> 'days' -> -1 ->> 'views'
  )::int,
  1,
  'today counts the recorded view'
);

select is(
  (public.set_my_listing_status(
    '77777777-7777-4777-8777-777777777710',
    'pause'
  ) ->> 'status'),
  'paused',
  'the owner can pause a live listing'
);

select is(
  (public.set_my_listing_status(
    '77777777-7777-4777-8777-777777777710',
    'resume'
  ) ->> 'status'),
  'published',
  'the owner can resume a paused listing'
);

select is(
  (public.set_my_listing_status(
    '77777777-7777-4777-8777-777777777710',
    'renew'
  ) ->> 'ok')::boolean,
  true,
  'renew extends the published window'
);

select is(
  (public.set_my_listing_status(
    '77777777-7777-4777-8777-777777777710',
    'mark_rented'
  ) ->> 'status'),
  'rented',
  'the owner can mark a listing rented'
);

select is(
  (
    select status::text
    from public.properties
    where id = '77777777-7777-4777-8777-777777777710'
  ),
  'rented',
  'rented is stored on the row'
);

reset role;
select set_config('request.jwt.claim.role', '', true);
select set_config('request.jwt.claim.sub', '', true);

do $$
declare
  v_host uuid := tests.get_supabase_uid('own_host');
  v_tenant uuid := tests.get_supabase_uid('own_tenant');
  v_left uuid;
  v_right uuid;
  v_match uuid := '77777777-7777-4777-8777-777777777701';
  v_conversation uuid := '77777777-7777-4777-8777-777777777702';
begin
  if v_host < v_tenant then
    v_left := v_host;
    v_right := v_tenant;
  else
    v_left := v_tenant;
    v_right := v_host;
  end if;
  insert into public.matches (id, participant_a, participant_b, status)
  values (v_match, v_left, v_right, 'active');
  select id into v_conversation
  from public.conversations
  where match_id = v_match;
  insert into public.messages (
    conversation_id, sender_id, body, status, created_at
  ) values
    (
      v_conversation,
      v_tenant,
      'Is the flat still free',
      'sent',
      now() - interval '4 hours'
    ),
    (
      v_conversation,
      v_host,
      'Yes it is free this month',
      'sent',
      now() - interval '2 hours'
    );
end $$;

select is(
  public.owner_reply_hours(tests.get_supabase_uid('own_host')),
  2,
  'reply hours are the rounded gap and do not return message text'
);

select is(
  public.owner_reply_hours(tests.get_supabase_uid('own_tenant')),
  null,
  'a person who has not replied has no reply badge'
);

select * from finish();
rollback;
