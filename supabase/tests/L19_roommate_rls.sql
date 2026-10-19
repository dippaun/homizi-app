-- Roommate discovery: opted-out people stay hidden, and private fields stay private.
begin;
select no_plan();

set local role anon;
select throws_ok(
  $$select public.roommate_compatibility(
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  )$$,
  '42501',
  'permission denied for function roommate_compatibility',
  'anonymous clients cannot score roommates'
);
select throws_ok(
  $$select public.roommate_compatibility_breakdown(
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  )$$,
  '42501',
  'permission denied for function roommate_compatibility_breakdown',
  'anonymous clients cannot read a roommate breakdown'
);
select throws_ok(
  $$select public.list_roommate_seekers()$$,
  '42501',
  'permission denied for function list_roommate_seekers',
  'anonymous clients cannot list roommates'
);
reset role;

select ok(
  exists (
    select 1 from auth.users where email = 'roommate-099@example.test'
  ),
  'the opted-out seed account exists'
);
select is(
  (
    select rp.discoverable
    from public.roommate_profiles rp
    join auth.users u on u.id = rp.user_id
    where u.email = 'roommate-099@example.test'
  ),
  false,
  'Hidden Seeker is not discoverable'
);
select is(
  (
    select rp.open_to_flatmates
    from public.roommate_profiles rp
    join auth.users u on u.id = rp.user_id
    where u.email = 'roommate-098@example.test'
  ),
  false,
  'Closed Tenant is not open to flatmates'
);

select tests.create_supabase_user('rm_viewer', 'rm-viewer@example.test');
select tests.create_supabase_user('rm_open', 'rm-open@example.test');
select tests.create_supabase_user('rm_hidden', 'rm-hidden@example.test');
select tests.create_supabase_user('rm_closed', 'rm-closed@example.test');
select tests.create_supabase_user('rm_tenant_open', 'rm-tenant-open@example.test');
select tests.create_supabase_user('rm_blocked', 'rm-blocked@example.test');
select tests.create_supabase_user('rm_suspended', 'rm-suspended@example.test');
select tests.create_supabase_user('rm_stranger', 'rm-stranger@example.test');
select tests.create_supabase_user('rm_staff', 'rm-staff@example.test');

insert into public.staff_roles (user_id)
select tests.get_supabase_uid('rm_staff');

update public.profiles
set display_name = 'Viewer Rao', occupation = 'Designer', primary_role = 'roommate'
where user_id = tests.get_supabase_uid('rm_viewer');
update public.profiles
set display_name = 'Open Shah', occupation = 'Architect', primary_role = 'roommate'
where user_id = tests.get_supabase_uid('rm_open');
update public.profiles
set display_name = 'Hidden Iyer', occupation = 'Researcher', primary_role = 'roommate'
where user_id = tests.get_supabase_uid('rm_hidden');
update public.profiles
set display_name = 'Closed Desai', occupation = 'Analyst', primary_role = 'tenant'
where user_id = tests.get_supabase_uid('rm_closed');
update public.profiles
set display_name = 'Open Tenant', occupation = 'Writer', primary_role = 'tenant'
where user_id = tests.get_supabase_uid('rm_tenant_open');
update public.profiles
set display_name = 'Blocked Mehta', occupation = 'Chef', primary_role = 'roommate'
where user_id = tests.get_supabase_uid('rm_blocked');
update public.profiles
set display_name = 'Paused Nair', occupation = 'Doctor', primary_role = 'roommate'
where user_id = tests.get_supabase_uid('rm_suspended');

update public.users
set status = 'suspended'
where id = tests.get_supabase_uid('rm_suspended');

update public.private_contacts
set phone = '+919800011122'
where user_id = tests.get_supabase_uid('rm_open');

insert into public.roommate_profiles (
  user_id, discoverable, open_to_flatmates, seeking_role, city, localities,
  budget_min_inr, budget_max_inr, move_in_date, gender, gender_preference,
  occupancy, food, food_dealbreaker, smoking, smoking_dealbreaker, pets,
  pets_dealbreaker, sleep, cleanliness, social, wfh, cooking, guests,
  languages, hobbies, thoughts, age
) values
  (
    tests.get_supabase_uid('rm_viewer'), true, true, 'roommate', 'Bengaluru',
    array['Koramangala'], 18000, 32000, date '2026-12-01', 'woman', 'any',
    'shared', array['veg'], true, array['never'], true, array['none'], false, array['early'], 4, array['quiet'],
    'hybrid', array['often'], array['rare'], array['English', 'Hindi'], array['reading'],
    'I want a quiet flatmate who cooks.', 27
  ),
  (
    tests.get_supabase_uid('rm_open'), true, true, 'roommate', 'Bengaluru',
    array['Koramangala'], 18000, 32000, date '2026-12-01', 'woman', 'any',
    'shared', array['veg'], false, array['never'], false, array['none'], false, array['early'], 4, array['quiet'],
    'hybrid', array['often'], array['rare'], array['English', 'Hindi'], array['reading'],
    'zzsecretnote stays on the private row', 26
  ),
  (
    tests.get_supabase_uid('rm_hidden'), false, true, 'roommate', 'Bengaluru',
    array['Koramangala'], 18000, 32000, date '2026-12-01', 'woman', 'any',
    'shared', array['veg'], false, array['never'], false, array['none'], false, array['early'], 4, array['quiet'],
    'hybrid', array['often'], array['rare'], array['English', 'Hindi'], array['reading'],
    'zzhiddentoken opted out of discovery', 28
  ),
  (
    tests.get_supabase_uid('rm_closed'), true, false, 'tenant', 'Bengaluru',
    array['Koramangala'], 18000, 32000, date '2026-12-01', 'woman', 'any',
    'shared', array['veg'], false, array['never'], false, array['none'], false, array['early'], 4, array['quiet'],
    'hybrid', array['often'], array['rare'], array['English', 'Hindi'], array['reading'],
    'A private rental search.', 29
  ),
  (
    tests.get_supabase_uid('rm_tenant_open'), true, true, 'tenant', 'Bengaluru',
    array['Indiranagar'], 18000, 32000, date '2026-12-01', 'woman', 'any',
    'shared', array['veg'], false, array['never'], false, array['none'], false, array['early'], 4, array['quiet'],
    'hybrid', array['often'], array['rare'], array['English', 'Hindi'], array['reading'],
    'Open to a flatmate in Bengaluru.', 28
  ),
  (
    tests.get_supabase_uid('rm_blocked'), true, true, 'roommate', 'Bengaluru',
    array['Koramangala'], 18000, 32000, date '2026-12-01', 'woman', 'any',
    'shared', array['veg'], false, array['never'], false, array['none'], false, array['early'], 4, array['quiet'],
    'hybrid', array['often'], array['rare'], array['English', 'Hindi'], array['reading'],
    'Blocked from the viewer.', 30
  ),
  (
    tests.get_supabase_uid('rm_suspended'), true, true, 'roommate', 'Bengaluru',
    array['Koramangala'], 18000, 32000, date '2026-12-01', 'woman', 'any',
    'shared', array['veg'], false, array['never'], false, array['none'], false, array['early'], 4, array['quiet'],
    'hybrid', array['often'], array['rare'], array['English', 'Hindi'], array['reading'],
    'This account is suspended.', 31
  );

insert into public.blocks (blocker_id, blocked_user_id)
values (
  tests.get_supabase_uid('rm_viewer'),
  tests.get_supabase_uid('rm_blocked')
);

select tests.authenticate_as('rm_viewer');
set local role authenticated;

select ok(
  exists (
    select 1
    from jsonb_array_elements(public.list_roommate_seekers()) as item
    where item->>'user_id' = tests.get_supabase_uid('rm_open')::text
  ),
  'a discoverable roommate is listed'
);
select ok(
  exists (
    select 1
    from jsonb_array_elements(public.list_roommate_seekers()) as item
    where item->>'user_id' = tests.get_supabase_uid('rm_tenant_open')::text
  ),
  'a tenant who is open to flatmates is listed'
);
select ok(
  exists (
    select 1
    from jsonb_array_elements(public.list_roommate_seekers()) as item
    where item->>'display_name' = 'Mira Shah'
  ),
  'the seeded discoverable roommate is listed'
);
select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.list_roommate_seekers()) as item
    where item->>'user_id' = tests.get_supabase_uid('rm_hidden')::text
       or item->>'display_name' = 'Hidden Seeker'
  ),
  'an opted-out roommate is not listed'
);
select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.list_roommate_seekers()) as item
    where item->>'user_id' = tests.get_supabase_uid('rm_closed')::text
       or item->>'display_name' = 'Closed Tenant'
  ),
  'a tenant who is not open to flatmates is not listed'
);
select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.list_roommate_seekers()) as item
    where item->>'user_id' = tests.get_supabase_uid('rm_blocked')::text
  ),
  'a blocked person is not listed'
);
select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.list_roommate_seekers()) as item
    where item->>'user_id' = tests.get_supabase_uid('rm_suspended')::text
  ),
  'a suspended account is not listed'
);
select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.list_roommate_seekers()) as item
    where item->>'user_id' = tests.get_supabase_uid('rm_viewer')::text
  ),
  'the caller is not listed'
);
select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.list_roommate_seekers()) as item
    where item ? 'thoughts'
       or item ? 'phone'
       or item ? 'email'
       or item ? 'food_dealbreaker'
       or item ? 'smoking'
  ),
  'the list omits private preference and contact fields'
);
select ok(
  position('zzsecretnote' in public.list_roommate_seekers()::text) = 0
  and position('zzhiddentoken' in public.list_roommate_seekers()::text) = 0
  and position('+919800011122' in public.list_roommate_seekers()::text) = 0
  and position('rm-open@example.test' in public.list_roommate_seekers()::text) = 0,
  'the list does not echo notes, phone, or email'
);
select ok(
  position('religion' in public.list_roommate_seekers()::text) = 0
  and position('caste' in public.list_roommate_seekers()::text) = 0,
  'the list does not mention religion or caste'
);

select is(
  public.roommate_compatibility(
    tests.get_supabase_uid('rm_viewer'),
    tests.get_supabase_uid('rm_open')
  ),
  public.roommate_compatibility(
    tests.get_supabase_uid('rm_open'),
    tests.get_supabase_uid('rm_viewer')
  ),
  'the score is the same in both directions'
);
select cmp_ok(
  public.roommate_compatibility(
    tests.get_supabase_uid('rm_viewer'),
    tests.get_supabase_uid('rm_open')
  ),
  '>',
  0,
  'two filled profiles score above zero'
);

create temp table rm_base_score as
select public.roommate_compatibility(
  tests.get_supabase_uid('rm_viewer'),
  tests.get_supabase_uid('rm_open')
) as score;

update public.roommate_profiles
set food = array['non_veg', 'veg'],
    sleep = array['night', 'early']
where user_id = auth.uid();

select is(
  public.roommate_compatibility(
    tests.get_supabase_uid('rm_viewer'),
    tests.get_supabase_uid('rm_open')
  ),
  (select score from rm_base_score),
  'any overlapping diet or sleep schedule still matches'
);

update public.roommate_profiles
set food = array['non_veg'],
    sleep = array['night']
where user_id = auth.uid();

select cmp_ok(
  public.roommate_compatibility(
    tests.get_supabase_uid('rm_viewer'),
    tests.get_supabase_uid('rm_open')
  ),
  '<',
  (select score from rm_base_score),
  'a diet and sleep schedule with no overlap score lower'
);

update public.roommate_profiles
set food = array['any'],
    sleep = '{}'::text[]
where user_id = auth.uid();

select is(
  public.roommate_compatibility(
    tests.get_supabase_uid('rm_viewer'),
    tests.get_supabase_uid('rm_open')
  ),
  (select score from rm_base_score),
  'an any diet and an empty sleep list match all'
);
select is(
  public.roommate_compatibility(
    tests.get_supabase_uid('rm_viewer'),
    tests.get_supabase_uid('rm_stranger')
  ),
  0,
  'a person with no roommate profile scores 0'
);
select ok(
  position(
    'zzsecretnote' in public.roommate_compatibility_breakdown(
      tests.get_supabase_uid('rm_viewer'),
      tests.get_supabase_uid('rm_open')
    )::text
  ) = 0,
  'the breakdown does not echo private flatmate notes'
);

select throws_ok(
  'select public._roommate_compatibility_detail('
    || quote_literal(tests.get_supabase_uid('rm_viewer'))
    || '::uuid, '
    || quote_literal(tests.get_supabase_uid('rm_open'))
    || '::uuid)',
  '42501',
  'permission denied for function _roommate_compatibility_detail',
  'members cannot call the private score helper'
);

update public.roommate_profiles
set thoughts = 'rewritten by the viewer'
where user_id = tests.get_supabase_uid('rm_open');

select is(
  (
    select count(*)
    from public.roommate_profiles
    where user_id = tests.get_supabase_uid('rm_open')
  ),
  0::bigint,
  'a member cannot read another roommate profile'
);
select is(
  (
    select count(*)
    from public.private_contacts
    where user_id = tests.get_supabase_uid('rm_open')
  ),
  0::bigint,
  'a member cannot read another person''s phone or email'
);

reset role;
select is(
  (
    select thoughts
    from public.roommate_profiles
    where user_id = tests.get_supabase_uid('rm_open')
  ),
  'zzsecretnote stays on the private row',
  'a member cannot rewrite another person''s roommate notes'
);

select tests.authenticate_as('rm_stranger');
set local role authenticated;

select throws_ok(
  'select public.roommate_compatibility('
    || quote_literal(tests.get_supabase_uid('rm_viewer'))
    || '::uuid, '
    || quote_literal(tests.get_supabase_uid('rm_open'))
    || '::uuid)',
  '42501',
  'permission denied for function roommate_compatibility',
  'a third person cannot score two other people'
);
select throws_ok(
  'insert into public.roommate_profiles (user_id, city, thoughts) values ('
    || quote_literal(tests.get_supabase_uid('rm_open'))
    || '::uuid, ''Pune'', ''inserted by a stranger'')',
  '42501',
  null,
  'a stranger cannot insert a roommate profile for someone else'
);

select is(
  (select count(*)::bigint from public.roommate_profiles),
  0::bigint,
  'a stranger sees no roommate profiles'
);

reset role;
select tests.authenticate_as('rm_open');
set local role authenticated;
select is(
  (
    select thoughts
    from public.roommate_profiles
    where user_id = auth.uid()
  ),
  'zzsecretnote stays on the private row',
  'the owner can read their own roommate notes'
);

reset role;
select tests.authenticate_as('rm_staff');
set local role authenticated;
select is(
  (
    select thoughts
    from public.roommate_profiles
    where user_id = tests.get_supabase_uid('rm_open')
  ),
  'zzsecretnote stays on the private row',
  'staff can read a roommate profile'
);
select lives_ok(
  'select public.roommate_compatibility('
    || quote_literal(tests.get_supabase_uid('rm_viewer'))
    || '::uuid, '
    || quote_literal(tests.get_supabase_uid('rm_open'))
    || '::uuid)',
  'staff can score two other people'
);

select finish();
rollback;
