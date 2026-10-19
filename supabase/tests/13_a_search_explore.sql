-- Localities are public. View rows are private. Counts are aggregates.
-- A photo request notifies the host once per person per day.
begin;
select no_plan();

select tests.create_supabase_user(
  'search_host',
  'search_host@example.test',
  '+910000000081'
);
select tests.create_supabase_user(
  'search_tenant',
  'search_tenant@example.test',
  '+910000000082'
);
select tests.create_supabase_user(
  'search_other',
  'search_other@example.test',
  '+910000000083'
);

select cmp_ok(
  (select count(*) from public.localities),
  '>=',
  50::bigint,
  'curated localities are seeded'
);

set local role anon;
select cmp_ok(
  (select count(*) from public.localities where city = 'Chennai'),
  '>=',
  8::bigint,
  'anonymous clients can read localities'
);

select throws_ok(
  $$insert into public.localities (city, name, slug, popularity)
    values ('Chennai', 'Fake Nagar', 'fake-nagar', 1)$$,
  '42501',
  'permission denied for table localities'
);

reset role;
select set_config('request.jwt.claim.role', '', true);
select set_config('request.jwt.claim.sub', '', true);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, status, published_at, area_sqft, preferred_tenants, parking,
  pets_allowed, gated_society, floor_no, total_floors
) values (
  '88888888-8888-4888-8888-888888888811',
  tests.get_supabase_uid('search_host'),
  'Koramangala walk-up',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  24000,
  'published',
  now(),
  980,
  array['family'],
  true,
  false,
  true,
  2,
  5
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, status, area_sqft
) values (
  '88888888-8888-4888-8888-888888888812',
  tests.get_supabase_uid('search_host'),
  'Draft with checks',
  'Baner',
  'Pune',
  'apartment',
  'semi_furnished',
  15000,
  'draft',
  700
);

select tests.authenticate_as('search_host');
set local role authenticated;

select throws_ok(
  $$update public.properties
    set area_sqft = 10
    where id = '88888888-8888-4888-8888-888888888812'$$,
  '23514',
  'new row for relation "properties" violates check constraint "properties_area_sqft"',
  'built-up area below 50 sq ft is rejected'
);

select throws_ok(
  $$update public.properties
    set preferred_tenants = array['students']
    where id = '88888888-8888-4888-8888-888888888812'$$,
  '23514',
  'new row for relation "properties" violates check constraint "properties_preferred_tenants"',
  'an unknown preferred tenant is rejected'
);

select throws_ok(
  $$update public.properties
    set floor_no = 9, total_floors = 4
    where id = '88888888-8888-4888-8888-888888888812'$$,
  '23514',
  'new row for relation "properties" violates check constraint "properties_floor_within"',
  'a floor above the building height is rejected'
);

reset role;
select tests.authenticate_as('search_tenant');
set local role authenticated;

select is(
  (public.record_listing_view('88888888-8888-4888-8888-888888888811')) ->> 'ok',
  'true',
  'a published home records a view'
);

select is(
  (select count(*)::integer
   from public.listing_views
   where property_id = '88888888-8888-4888-8888-888888888811'),
  1,
  'the viewer can read their own view row'
);

select is(
  (public.record_listing_view('88888888-8888-4888-8888-888888888811')) ->> 'recorded',
  'true',
  'recording again the same day still succeeds'
);

select is(
  (select count(*)::integer
   from public.listing_views
   where property_id = '88888888-8888-4888-8888-888888888811'),
  1,
  'one view row per viewer per day'
);

select ok(
  position(
    'viewer' in pg_get_function_result(
      'public.get_listing_view_counts(uuid[])'::regprocedure
    )
  ) = 0,
  'view count columns do not name a viewer'
);

select results_eq(
  $$select views_today, views_total
    from public.get_listing_view_counts(
      array['88888888-8888-4888-8888-888888888811']::uuid[]
    )$$,
  $$values (1, 1)$$,
  'today and total counts come from stored rows'
);

reset role;
select tests.authenticate_as('search_other');
set local role authenticated;

select is(
  (select count(*)::integer from public.listing_views),
  0,
  'another person cannot read view rows'
);

set local role anon;
select results_eq(
  $$select views_today, views_total
    from public.get_listing_view_counts(
      array['88888888-8888-4888-8888-888888888811']::uuid[]
    )$$,
  $$values (1, 1)$$,
  'anonymous clients get counts and not viewer ids'
);

reset role;
select tests.authenticate_as('search_tenant');
set local role authenticated;

select is(
  (public.request_listing_photos('88888888-8888-4888-8888-888888888811')) ->> 'ok',
  'true',
  'a home with fewer than 3 photos accepts a request'
);

select is(
  (public.request_listing_photos('88888888-8888-4888-8888-888888888811')) ->> 'error',
  'rate_limited',
  'a second photo request the same day is refused'
);

reset role;
select tests.authenticate_as('search_host');
set local role authenticated;

select is(
  (select count(*)::integer
   from public.notifications
   where type = 'photo_request'
     and payload_minimal ->> 'property_id' = '88888888-8888-4888-8888-888888888811'),
  1,
  'the host receives one photo request and no viewer identity beyond the property id'
);

select is(
  (public.notification_payload_ok(
    '{"property_id":"88888888-8888-4888-8888-888888888811"}'::jsonb
  )),
  true,
  'a property id remains a valid notification payload'
);

insert into public.property_photos (
  property_id, storage_path, sort_order, photo_type
) values
  ('88888888-8888-4888-8888-888888888812', 'search/0.slot', 0, 'living'),
  ('88888888-8888-4888-8888-888888888812', 'search/1.slot', 1, 'bedroom'),
  ('88888888-8888-4888-8888-888888888812', 'search/2.slot', 2, 'kitchen');

reset role;
select set_config('request.jwt.claim.role', '', true);
update public.properties
set status = 'published', published_at = now() - interval '2 days'
where id = '88888888-8888-4888-8888-888888888812';

select tests.authenticate_as('search_tenant');
set local role authenticated;

select is(
  (public.request_listing_photos('88888888-8888-4888-8888-888888888812')) ->> 'error',
  'enough_photos',
  'three usable photos do not send a request'
);

insert into public.saved_searches (
  id, user_id, label, city, locality, filters, last_checked_at
) values (
  '88888888-8888-4888-8888-888888888821',
  auth.uid(),
  'Koramangala',
  'Bengaluru',
  'Koramangala',
  '{"budget_max_inr": 30000}'::jsonb,
  now() - interval '30 days'
);

select cmp_ok(
  public.saved_search_new_count('88888888-8888-4888-8888-888888888821'),
  '>=',
  1,
  'homes published after the last check are counted'
);

reset role;
select tests.authenticate_as('search_other');
set local role authenticated;

select is(
  (select count(*)::integer from public.saved_searches),
  0,
  'saved searches are visible only to their owner'
);

select is(
  public.saved_search_new_count('88888888-8888-4888-8888-888888888821'),
  0,
  'another person cannot count someone else''s saved search'
);

select * from finish();
rollback;
