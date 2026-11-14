-- Saved priorities are private to their owner, use known criteria only,
-- and refuse contact details.
begin;
select no_plan();

select tests.create_supabase_user('pr_tenant', 'pr_tenant@example.test', '+910000000201');
select tests.create_supabase_user('pr_host', 'pr_host@example.test', '+910000000202');

select tests.authenticate_as('pr_tenant');
set local role authenticated;

select lives_ok(
  $$insert into public.priority_preferences (side, ranked, must_have, order_all, prefs)
    values (
      'tenant',
      array['budget', 'location', 'occupancy', 'property_type', 'move_in'],
      array['budget', 'location'],
      array['budget', 'location', 'occupancy', 'property_type', 'move_in',
        'gender', 'lifestyle', 'furnishing'],
      '{"budget_min":10000,"budget_max":15000,"place_query":"Andheri East"}'
    )$$,
  'a tenant saves their own priorities'
);

select is(
  (select user_id from public.priority_preferences where side = 'tenant'),
  tests.get_supabase_uid('pr_tenant'),
  'the row belongs to the signed-in user'
);

select throws_ok(
  $$insert into public.priority_preferences (side, ranked) values ('host', array['budget', 'salary'])$$,
  '23514',
  NULL,
  'unknown criteria are refused'
);

select throws_ok(
  $$insert into public.priority_preferences (side, ranked, must_have)
    values ('host', array['budget', 'move_in'], array['vegetarian'])$$,
  '23514',
  NULL,
  'a must-have has to be one of the ranked priorities'
);

select throws_ok(
  $$update public.priority_preferences
    set prefs = '{"place_query":"call 9876543210"}'
    where side = 'tenant'$$,
  '23514',
  NULL,
  'phone numbers are refused'
);

select throws_ok(
  $$insert into public.priority_preferences (user_id, side, ranked)
    values (tests.get_supabase_uid('pr_host'), 'host', array['budget'])$$,
  '42501',
  NULL,
  'nobody writes another user''s priorities'
);

reset role;
select tests.authenticate_as('pr_host');
set local role authenticated;

select lives_ok(
  $$insert into public.priority_preferences (side, ranked, must_have, prefs)
    values (
      'host',
      array['budget', 'move_in', 'working_professional', 'vegetarian', 'gender_age'],
      array['budget'],
      '{"property_id":"a1916000-0000-4000-8000-000000000001","age_min":21,"age_max":35}'
    )$$,
  'a host saves a preferred tenant profile'
);

select is(
  (select count(*)::int from public.priority_preferences),
  1,
  'a host sees only their own row'
);

reset role;
set local role anon;

select throws_ok(
  $$select count(*) from public.priority_preferences$$,
  '42501',
  NULL,
  'anonymous clients cannot read priorities'
);

select * from finish();
rollback;
