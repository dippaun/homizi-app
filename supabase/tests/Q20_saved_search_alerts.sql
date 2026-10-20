-- A newly published home notifies each matching saved search once.
-- The payload is the saved-search id. Another person cannot see it.
-- Clear removes only the signed-in person's viewed rows.
begin;
select no_plan();

select tests.create_supabase_user(
  'q20_host',
  'q20_host@example.test',
  '+910000000221'
);
select tests.create_supabase_user(
  'q20_seeker',
  'q20_seeker@example.test',
  '+910000000222'
);
select tests.create_supabase_user(
  'q20_other',
  'q20_other@example.test',
  '+910000000223'
);

select is(
  public.notification_category('saved_search_match'),
  'listings',
  'a saved-search notice follows the listings preference'
);

select is(
  public.notification_payload_ok(
    '{"saved_search_id":"a20a20a2-a20a-420a-820a-a20a20a20b01"}'::jsonb
  ),
  true,
  'a saved-search id is a valid payload'
);

select is(
  public.notification_payload_ok(
    '{"saved_search_id":"a20a20a2-a20a-420a-820a-a20a20a20b01","title":"Koramangala walk-up"}'::jsonb
  ),
  false,
  'a title is not a valid saved-search payload'
);

select is(
  public.notification_payload_ok(
    '{"saved_search_id":"a20a20a2-a20a-420a-820a-a20a20a20b01","phone":"9876543210"}'::jsonb
  ),
  false,
  'a phone is not a valid saved-search payload'
);

select is(
  public.notification_payload_ok(
    '{"saved_search_id":"a20a20a2-a20a-420a-820a-a20a20a20b01","email":"ada@example.test"}'::jsonb
  ),
  false,
  'an email is not a valid saved-search payload'
);

select is(
  public.notification_payload_ok(
    '{"saved_search_id":"a20a20a2-a20a-420a-820a-a20a20a20b01","address_line":"12 MG Road"}'::jsonb
  ),
  false,
  'a street address is not a valid saved-search payload'
);

select is(
  public.push_allowed(
    tests.get_supabase_uid('q20_seeker'),
    'saved_search_match'
  ),
  false,
  'a saved-search notice is not sent to FCM'
);

select throws_ok(
  $$insert into public.notifications (user_id, type, payload_minimal)
    values (
      tests.get_supabase_uid('q20_seeker'),
      'saved_search_match',
      '{"saved_search_id":"a20a20a2-a20a-420a-820a-a20a20a20b01","title":"Koramangala walk-up"}'::jsonb
    )$$,
  '23514',
  'new row for relation "notifications" violates check constraint "notifications_payload"',
  'a saved-search notice cannot store a title'
);

select throws_ok(
  $$insert into public.notifications (user_id, type, payload_minimal)
    values (
      tests.get_supabase_uid('q20_seeker'),
      'saved_search_match',
      '{"phone":"9876543210","email":"ada@example.test","address_line":"12 MG Road"}'::jsonb
    )$$,
  '23514',
  'new row for relation "notifications" violates check constraint "notifications_payload"',
  'a saved-search notice cannot store contact or an address'
);

insert into public.saved_searches (
  id, user_id, label, city, locality, filters, last_checked_at
) values (
  'a20a20a2-a20a-420a-820a-a20a20a20b01',
  tests.get_supabase_uid('q20_seeker'),
  'Koramangala',
  'Bengaluru',
  'Koramangala',
  '{"budget_max_inr": 30000}'::jsonb,
  now() - interval '1 hour'
);

insert into public.saved_searches (
  id, user_id, label, city, locality, filters, last_checked_at
) values (
  'a20a20a2-a20a-420a-820a-a20a20a20b03',
  tests.get_supabase_uid('q20_other'),
  'Baner',
  'Pune',
  'Baner',
  '{"budget_max_inr": 30000}'::jsonb,
  now() - interval '1 hour'
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, status, published_at
) values (
  'a20a20a2-a20a-420a-820a-a20a20a20a01',
  tests.get_supabase_uid('q20_host'),
  'Older Koramangala walk-up',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  24000,
  'published',
  now() - interval '40 days'
);

select is(
  (
    select count(*)::integer
    from public.notifications
    where type = 'saved_search_match'
  ),
  0,
  'a home published before the search was checked does not notify'
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, status, published_at
) values (
  'a20a20a2-a20a-420a-820a-a20a20a20a02',
  tests.get_supabase_uid('q20_host'),
  'Koramangala walk-up',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  24000,
  'published',
  now()
);

select is(
  (
    select count(*)::integer
    from public.notifications
    where user_id = tests.get_supabase_uid('q20_seeker')
      and type = 'saved_search_match'
      and payload_minimal = '{"saved_search_id":"a20a20a2-a20a-420a-820a-a20a20a20b01"}'::jsonb
  ),
  1,
  'one notice is inserted for the matching saved search'
);

select is(
  (
    select count(*)::integer
    from public.notifications
    where user_id = tests.get_supabase_uid('q20_other')
      and type = 'saved_search_match'
  ),
  0,
  'a Pune search is not notified about a Bengaluru home'
);

update public.properties
set title = 'Koramangala walk-up renamed'
where id = 'a20a20a2-a20a-420a-820a-a20a20a20a02';

update public.properties
set status = 'paused'
where id = 'a20a20a2-a20a-420a-820a-a20a20a20a02';

update public.properties
set status = 'published'
where id = 'a20a20a2-a20a-420a-820a-a20a20a20a02';

select is(
  (
    select count(*)::integer
    from public.notifications
    where user_id = tests.get_supabase_uid('q20_seeker')
      and type = 'saved_search_match'
  ),
  1,
  'renaming or pausing the same home does not insert a second notice'
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, status, published_at
) values
  (
    'a20a20a2-a20a-420a-820a-a20a20a20a03',
    tests.get_supabase_uid('q20_host'),
    'Pricey Koramangala home',
    'Koramangala',
    'Bengaluru',
    'apartment',
    'furnished',
    90000,
    'published',
    now()
  ),
  (
    'a20a20a2-a20a-420a-820a-a20a20a20a04',
    tests.get_supabase_uid('q20_host'),
    'Bandra west flat',
    'Bandra West',
    'Mumbai',
    'apartment',
    'furnished',
    24000,
    'published',
    now()
  );

select is(
  (
    select count(*)::integer
    from public.notifications
    where type = 'saved_search_match'
  ),
  1,
  'a home outside the budget or the city does not notify'
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, status, published_at
) values (
  'a20a20a2-a20a-420a-820a-a20a20a20a07',
  tests.get_supabase_uid('q20_host'),
  'Baner two bedroom',
  'Baner',
  'Pune',
  'apartment',
  'semi_furnished',
  18000,
  'published',
  now()
);

select is(
  (
    select count(*)::integer
    from public.notifications
    where user_id = tests.get_supabase_uid('q20_other')
      and type = 'saved_search_match'
      and payload_minimal = '{"saved_search_id":"a20a20a2-a20a-420a-820a-a20a20a20b03"}'::jsonb
  ),
  1,
  'the other person is notified only for their own saved search'
);

insert into public.notification_preferences (user_id, listings, system)
values (tests.get_supabase_uid('q20_seeker'), false, true);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, status, published_at
) values (
  'a20a20a2-a20a-420a-820a-a20a20a20a05',
  tests.get_supabase_uid('q20_host'),
  'Koramangala home while listings are off',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  21000,
  'published',
  now()
);

select is(
  (
    select count(*)::integer
    from public.notifications
    where user_id = tests.get_supabase_uid('q20_seeker')
      and type = 'saved_search_match'
  ),
  1,
  'listings off inserts no saved-search notice'
);

select is(
  (
    select count(*)::integer
    from public.saved_search_alert_log
    where property_id = 'a20a20a2-a20a-420a-820a-a20a20a20a05'
  ),
  0,
  'a skipped notice is not remembered as sent'
);

update public.notification_preferences
set listings = true, system = false
where user_id = tests.get_supabase_uid('q20_seeker');

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, status, published_at
) values (
  'a20a20a2-a20a-420a-820a-a20a20a20a06',
  tests.get_supabase_uid('q20_host'),
  'Koramangala home after listings are on',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  22000,
  'published',
  now()
);

select is(
  (
    select count(*)::integer
    from public.notifications
    where user_id = tests.get_supabase_uid('q20_seeker')
      and type = 'saved_search_match'
  ),
  2,
  'listings on inserts one notice and system off does not block it'
);

insert into public.saved_searches (
  id, user_id, label, city, filters, last_checked_at
) values (
  'a20a20a2-a20a-420a-820a-a20a20a20b02',
  tests.get_supabase_uid('q20_seeker'),
  'Bengaluru',
  'Bengaluru',
  '{"budget_max_inr": 50000}'::jsonb,
  now() - interval '1 hour'
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, status, published_at
) values (
  'a20a20a2-a20a-420a-820a-a20a20a20a08',
  tests.get_supabase_uid('q20_host'),
  'Another Koramangala home',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  20000,
  'published',
  now()
);

select is(
  (
    select count(*)::integer
    from public.notifications
    where user_id = tests.get_supabase_uid('q20_seeker')
      and type = 'saved_search_match'
  ),
  4,
  'one notice is inserted for each saved search the new home matches'
);

select is(
  (
    select bool_and(
      (payload_minimal - 'saved_search_id') = '{}'::jsonb
      and not (
        payload_minimal ?| array[
          'title',
          'phone',
          'email',
          'address_line',
          'landmark',
          'property_id'
        ]
      )
    )
    from public.notifications
    where type = 'saved_search_match'
  ),
  true,
  'every saved-search notice stores only the saved-search id'
);

select tests.authenticate_as('q20_other');
set local role authenticated;

select is(
  (
    select count(*)::integer
    from public.notifications
    where payload_minimal ->> 'saved_search_id'
      = 'a20a20a2-a20a-420a-820a-a20a20a20b01'
  ),
  0,
  'another person cannot see the first person''s notice'
);

select is(
  (select count(*)::integer from public.notifications),
  1,
  'another person can see only their own notice'
);

select throws_ok(
  $$select * from public.saved_search_alert_log$$,
  '42501',
  'permission denied for table saved_search_alert_log',
  'the alert log is not visible to clients'
);

select throws_ok(
  $$insert into public.notifications (user_id, type, payload_minimal)
    values (
      tests.get_supabase_uid('q20_other'),
      'saved_search_match',
      '{"saved_search_id":"a20a20a2-a20a-420a-820a-a20a20a20b03"}'::jsonb
    )$$,
  '42501',
  'permission denied for table notifications',
  'a client cannot insert a saved-search notice'
);

select is(
  (public.record_listing_view('a20a20a2-a20a-420a-820a-a20a20a20a02')) ->> 'recorded',
  'true',
  'the other person records a view'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('q20_seeker');
set local role authenticated;

select is(
  (public.record_listing_view('a20a20a2-a20a-420a-820a-a20a20a20a02')) ->> 'recorded',
  'true',
  'the seeker records a view'
);

select is(
  (select count(*)::integer from public.listing_views),
  1,
  'the seeker cannot read the other person''s viewed rows'
);

select is(
  public.clear_recently_viewed(),
  1,
  'clear deletes only this person''s viewed rows'
);

select is(
  (select count(*)::integer from public.listing_views),
  0,
  'the seeker has no viewed rows after clear'
);

select throws_ok(
  $$delete from public.listing_views$$,
  '42501',
  'permission denied for table listing_views',
  'viewed rows cannot be deleted except through clear_recently_viewed'
);

reset role;
select tests.clear_authentication();

select is(
  (
    select count(*)::integer
    from public.listing_views
    where viewer_id = tests.get_supabase_uid('q20_other')
  ),
  1,
  'clearing one person leaves the other person''s history'
);

select is(
  (
    select count(*)::integer
    from public.listing_views
    where viewer_id = tests.get_supabase_uid('q20_seeker')
  ),
  0,
  'the cleared history is gone'
);

select tests.authenticate_as('q20_other');
set local role authenticated;

select is(
  (select count(*)::integer from public.listing_views),
  1,
  'the other person still sees their own viewed row'
);

select is(
  public.clear_recently_viewed(),
  1,
  'the other person can clear only their own viewed rows'
);

reset role;
select tests.clear_authentication();

select throws_ok(
  $$select public.clear_recently_viewed()$$,
  'P0001',
  'Sign in before clearing viewed homes.',
  'clearing viewed homes requires a session'
);

set local role anon;
select throws_ok(
  $$select public.clear_recently_viewed()$$,
  '42501',
  'permission denied for function clear_recently_viewed',
  'anonymous clients cannot clear viewed homes'
);

select * from finish();
rollback;
