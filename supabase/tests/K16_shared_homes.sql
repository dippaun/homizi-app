-- Shared home details are readable on published homes and written only by
-- the host. Join requests are visible to the seeker and the host, and each
-- side can make only its own status change.
begin;
select no_plan();

select tests.create_supabase_user('sh_host', 'sh_host@example.test', '+910000000191');
select tests.create_supabase_user('sh_seeker', 'sh_seeker@example.test', '+910000000192');
select tests.create_supabase_user('sh_other', 'sh_other@example.test', '+910000000193');

reset role;
select set_config('request.jwt.claim.role', '', true);
select set_config('request.jwt.claim.sub', '', true);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, status, published_at
) values (
  'a1916000-0000-4000-8000-000000000001',
  tests.get_supabase_uid('sh_host'),
  '3 BHK shared home',
  'Andheri East',
  'Mumbai',
  'apartment',
  'semi_furnished',
  12000,
  'published',
  now()
);

select tests.authenticate_as('sh_host');
set local role authenticated;

select lives_ok(
  $$insert into public.shared_home_details (
      listing_id, property_label, total_rooms, currently_living, vacant_rooms,
      total_capacity, occupancy_type, housemates
    ) values (
      'a1916000-0000-4000-8000-000000000001', '3 BHK', 3, 1, 2, 3, 'separate',
      '[{"first_name":"Rohit","last_initial":"S","age":29,"occupation":"IT Professional"}]'
    )$$,
  'the host can add occupancy details to their home'
);

select throws_ok(
  $$update public.shared_home_details
    set housemates = '[{"first_name":"rohit@example.in"}]'
    where listing_id = 'a1916000-0000-4000-8000-000000000001'$$,
  '23514',
  NULL,
  'contact details are refused in housemates'
);

select throws_ok(
  $$update public.shared_home_details
    set vacant_rooms = 5
    where listing_id = 'a1916000-0000-4000-8000-000000000001'$$,
  '23514',
  NULL,
  'vacant rooms cannot exceed total rooms'
);

reset role;
select tests.authenticate_as('sh_seeker');
set local role authenticated;

select is(
  (select vacant_rooms::int from public.shared_home_details
    where listing_id = 'a1916000-0000-4000-8000-000000000001'),
  2,
  'a signed-in seeker reads details on a published home'
);

select throws_ok(
  $$insert into public.shared_home_details (
      listing_id, host_user_id, property_label, total_rooms, vacant_rooms, total_capacity
    ) values (
      'a1916000-0000-4000-8000-000000000001', auth.uid(), '3 BHK', 3, 1, 3
    )$$,
  '42501',
  NULL,
  'a seeker cannot write details for someone else''s home'
);

select lives_ok(
  $$insert into public.shared_home_join_requests (
      id, listing_id, requester_first_name, mode, people, share_inr
    ) values (
      'a1916000-0000-4000-8000-0000000000a1',
      'a1916000-0000-4000-8000-000000000001', 'Amit', 'individual', 1, 12000
    )$$,
  'a seeker can ask to join a published shared home'
);

select is(
  (select host_user_id from public.shared_home_join_requests
    where id = 'a1916000-0000-4000-8000-0000000000a1'),
  tests.get_supabase_uid('sh_host'),
  'the host is filled in from the listing'
);

select throws_ok(
  $$update public.shared_home_join_requests set status = 'accepted'
    where id = 'a1916000-0000-4000-8000-0000000000a1'$$,
  '42501',
  NULL,
  'the seeker cannot accept their own request'
);

select throws_ok(
  $$insert into public.shared_home_join_requests (listing_id, requester_first_name)
    values ('a1916000-0000-4000-8000-000000000001', 'Amit again')$$,
  '23505',
  NULL,
  'only one open request per home'
);

reset role;
select tests.authenticate_as('sh_other');
set local role authenticated;

select is(
  (select count(*) from public.shared_home_join_requests),
  0::bigint,
  'another person cannot read the request'
);

reset role;
select tests.authenticate_as('sh_host');
set local role authenticated;

select throws_ok(
  $$insert into public.shared_home_join_requests (listing_id, requester_first_name)
    values ('a1916000-0000-4000-8000-000000000001', 'Host')$$,
  '42501',
  NULL,
  'the host cannot join their own home'
);

select lives_ok(
  $$update public.shared_home_join_requests set status = 'accepted'
    where id = 'a1916000-0000-4000-8000-0000000000a1'$$,
  'the host accepts the request'
);

select throws_ok(
  $$update public.shared_home_join_requests set share_inr = 1
    where id = 'a1916000-0000-4000-8000-0000000000a1'$$,
  '42501',
  NULL,
  'the agreed share cannot be edited'
);

reset role;
select tests.authenticate_as('sh_seeker');
set local role authenticated;

select lives_ok(
  $$update public.shared_home_join_requests set status = 'moved_in'
    where id = 'a1916000-0000-4000-8000-0000000000a1'$$,
  'the seeker confirms the move-in after it was accepted'
);

select ok(
  (select moved_in_at is not null from public.shared_home_join_requests
    where id = 'a1916000-0000-4000-8000-0000000000a1'),
  'the move-in time is recorded'
);

reset role;
set local role anon;

select throws_ok(
  $$select count(*) from public.shared_home_join_requests$$,
  '42501',
  NULL,
  'anonymous clients cannot read join requests'
);

select * from finish();
rollback;
