-- Two signed-in people, plus an anonymous reader.
-- Published homes are visible without verification. A like is private to
-- the two people. The second like creates one match. Contact stays hidden.
begin;
select no_plan();

select ok(
  (
    select relreplident = 'f'
    from pg_class
    where oid = 'public.properties'::regclass
  ),
  'properties use full replica identity'
);

select ok(
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'properties'
  ),
  'properties are in the realtime publication'
);

select ok(
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'interests'
  ),
  'interests are in the realtime publication'
);

select ok(
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'matches'
  ),
  'matches are in the realtime publication'
);

select ok(
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ),
  'messages stay in the realtime publication'
);

select tests.create_supabase_user('live_host', 'live_host@example.test');
select tests.create_supabase_user('live_guest', 'live_guest@example.test');
select tests.create_supabase_user('live_other', 'live_other@example.test');

select tests.authenticate_as('live_host');
set local role authenticated;

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr
) values (
  '15151515-1515-4151-8151-151515151501',
  tests.get_supabase_uid('live_host'),
  'Live PG',
  'Navrangpura',
  'Ahmedabad',
  'pg',
  'furnished',
  9000
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr
) values (
  '15151515-1515-4151-8151-151515151502',
  tests.get_supabase_uid('live_host'),
  'Draft PG',
  'Navrangpura',
  'Ahmedabad',
  'pg',
  'furnished',
  8000
);

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('15151515-1515-4151-8151-151515151501', 'live/1.jpg', 0, 'living'),
  ('15151515-1515-4151-8151-151515151501', 'live/2.jpg', 1, 'bedroom'),
  ('15151515-1515-4151-8151-151515151501', 'live/3.jpg', 2, 'kitchen');

select ok(
  (public.publish_listing('15151515-1515-4151-8151-151515151501'::uuid) ->> 'ok')::boolean,
  'an unverified host can publish a PG'
);

reset role;
select tests.clear_authentication();
set local role anon;

select throws_ok(
  $$select * from public.properties$$,
  '42501',
  'permission denied for table properties',
  'anon still cannot select the properties table'
);

select is(
  (
    select count(*)::int from public.public_listings()
    where id = '15151515-1515-4151-8151-151515151501'
  ),
  1,
  'anon can read the published PG without a verification check'
);

select is(
  (
    select count(*)::int from public.public_listings()
    where id = '15151515-1515-4151-8151-151515151502'
  ),
  0,
  'anon cannot read a draft through public_listings'
);

select throws_ok(
  $$select * from public.private_contacts$$,
  '42501',
  'permission denied for table private_contacts',
  'anon cannot read contact details'
);

reset role;
select tests.authenticate_as('live_guest');
set local role authenticated;

insert into public.listing_requirements (
  id, user_id, city, localities, budget_min_inr, budget_max_inr
) values (
  '15151515-1515-4151-8151-151515151503',
  tests.get_supabase_uid('live_guest'),
  'Ahmedabad',
  array['Navrangpura'],
  5000,
  15000
);

select ok(
  (public.publish_requirement('15151515-1515-4151-8151-151515151503'::uuid) ->> 'ok')::boolean,
  'the second person can publish a roommate brief'
);

select is(
  (
    select count(*)::int from public.public_listings()
    where property_type = 'pg'
      and id = '15151515-1515-4151-8151-151515151501'
  ),
  1,
  'a signed-in unverified person can read the published PG'
);

select is(
  (public.create_interest(
    'user',
    tests.get_supabase_uid('live_host'),
    'like'
  ) -> 'match' ->> 'error'),
  'no_reciprocal',
  'one like does not create a match'
);

reset role;
select tests.authenticate_as('live_other');
set local role authenticated;

select is(
  (
    select count(*)::int from public.interests
    where actor_user_id = tests.get_supabase_uid('live_guest')
      and action = 'like'
  ),
  0,
  'a third person cannot read the like'
);

reset role;
select tests.authenticate_as('live_host');
set local role authenticated;

select is(
  (
    select count(*)::int from public.interests
    where actor_user_id = tests.get_supabase_uid('live_guest')
      and target_id = tests.get_supabase_uid('live_host')
      and action = 'like'
  ),
  1,
  'the person who was liked can read that like'
);

select is(
  (public.create_interest(
    'user',
    tests.get_supabase_uid('live_guest'),
    'like'
  ) -> 'match' ->> 'ok')::boolean,
  true,
  'the mutual like creates a match'
);

select is(
  (
    select count(*)::int
    from public.matches
    where participant_a = least(
        tests.get_supabase_uid('live_host'),
        tests.get_supabase_uid('live_guest')
      )
      and participant_b = greatest(
        tests.get_supabase_uid('live_host'),
        tests.get_supabase_uid('live_guest')
      )
  ),
  1,
  'the trigger and the interest function leave one match'
);

select is(
  (
    select public.get_contact_visibility(m.id) ->> 'reason'
    from public.matches m
    where m.participant_a = least(
        tests.get_supabase_uid('live_host'),
        tests.get_supabase_uid('live_guest')
      )
      and m.participant_b = greatest(
        tests.get_supabase_uid('live_host'),
        tests.get_supabase_uid('live_guest')
      )
  ),
  'consent_required',
  'contact stays hidden until someone shares it'
);

reset role;
insert into public.interests (actor_user_id, target_type, target_id, action)
values (
  tests.get_supabase_uid('live_guest'),
  'user',
  tests.get_supabase_uid('live_other'),
  'like'
);

insert into public.interests (actor_user_id, target_type, target_id, action)
values (
  tests.get_supabase_uid('live_other'),
  'user',
  tests.get_supabase_uid('live_guest'),
  'like'
);

select is(
  (
    select count(*)::int
    from public.matches
    where participant_a = least(
        tests.get_supabase_uid('live_guest'),
        tests.get_supabase_uid('live_other')
      )
      and participant_b = greatest(
        tests.get_supabase_uid('live_guest'),
        tests.get_supabase_uid('live_other')
      )
  ),
  1,
  'a direct mutual like insert creates one match'
);

select * from finish();
rollback;
