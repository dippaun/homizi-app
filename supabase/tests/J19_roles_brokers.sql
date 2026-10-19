-- Broker visibility and requirement edits.
-- A published discoverable brief is readable. A hidden or draft brief is not.
-- seekers_for_my_listings returns no phone or email.
-- Only the owner can change a requirement.
begin;
select no_plan();

select tests.create_supabase_user(
  'j_visible',
  'j_visible@example.test',
  '+919800000001'
);
select tests.create_supabase_user(
  'j_hidden',
  'j_hidden@example.test',
  '+919800000002'
);
select tests.create_supabase_user(
  'j_draft',
  'j_draft@example.test',
  '+919800000003'
);
select tests.create_supabase_user(
  'j_broker',
  'j_broker@example.test',
  '+919800000004'
);
select tests.create_supabase_user(
  'j_host',
  'j_host@example.test',
  '+919800000005'
);
select tests.create_supabase_user('j_stranger', 'j_stranger@example.test');

select tests.authenticate_as('j_visible');
set local role authenticated;

update public.profiles
set display_name = 'Ananya Iyer'
where user_id = auth.uid();

insert into public.listing_requirements (
  id,
  user_id,
  city,
  localities,
  budget_min_inr,
  budget_max_inr,
  room_type,
  furnishing,
  about_me,
  discoverable,
  gender_preference,
  seeker_kind
) values (
  'b1919301-0000-4000-8000-000000000001',
  auth.uid(),
  'Bengaluru',
  array['Koramangala', 'Indiranagar'],
  20000,
  35000,
  '2bhk',
  'semi_furnished',
  'Bright 2 BHK in Koramangala.',
  true,
  'women',
  'tenant'
);

select is(
  (
    public.publish_requirement('b1919301-0000-4000-8000-000000000001') ->> 'ok'
  ),
  'true',
  'the seeker can publish their own brief'
);

reset role;
select tests.authenticate_as('j_hidden');
set local role authenticated;

update public.profiles
set display_name = 'Neelam Chopra'
where user_id = auth.uid();

insert into public.listing_requirements (
  id,
  user_id,
  city,
  localities,
  budget_min_inr,
  budget_max_inr,
  room_type,
  furnishing,
  about_me,
  discoverable,
  seeker_kind
) values (
  'b1919302-0000-4000-8000-000000000002',
  auth.uid(),
  'Mumbai',
  array['Dadar'],
  25000,
  40000,
  '2bhk',
  'semi_furnished',
  'This brief stays private.',
  false,
  'tenant'
);

select is(
  (
    public.publish_requirement('b1919302-0000-4000-8000-000000000002') ->> 'ok'
  ),
  'true',
  'opting out still lets the owner publish'
);

reset role;
select tests.authenticate_as('j_draft');
set local role authenticated;

insert into public.listing_requirements (
  id,
  user_id,
  city,
  localities,
  budget_min_inr,
  budget_max_inr,
  about_me
) values (
  'b1919303-0000-4000-8000-000000000003',
  auth.uid(),
  'Pune',
  array['Baner'],
  10000,
  18000,
  'Still a draft.'
);

reset role;
select tests.authenticate_as('j_broker');
set local role authenticated;

insert into public.broker_profiles (
  user_id,
  full_name,
  agency_name,
  rera_number,
  cities,
  localities,
  phone,
  years_experience
) values (
  auth.uid(),
  'Meenal Deshpande',
  'Deshpande Realty',
  'PRM/KA/RERA/1251/446/AG/171018/000441',
  array['Bengaluru'],
  array['Koramangala'],
  '+919876543210',
  8
);

insert into public.properties (
  id,
  host_user_id,
  title,
  locality,
  city,
  property_type,
  furnishing,
  rent_inr,
  listed_by,
  brokerage_terms
) values (
  'b1919101-0000-4000-8000-000000000001',
  auth.uid(),
  '2 BHK in Koramangala',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'semi_furnished',
  28000,
  'broker',
  'One month rent, paid when the agreement is signed'
);

select is(
  (
    select about_me
    from public.listing_requirements
    where id = 'b1919301-0000-4000-8000-000000000001'
  ),
  'Bright 2 BHK in Koramangala.',
  'a broker can read a published discoverable brief'
);

select is(
  (
    select count(*)
    from public.listing_requirements
    where id = 'b1919302-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'a broker cannot read a brief that opted out'
);

select is(
  (
    select count(*)
    from public.listing_requirements
    where id = 'b1919303-0000-4000-8000-000000000003'
  ),
  0::bigint,
  'a broker cannot read another person''s draft'
);

select is(
  (
    select count(*)
    from public.private_contacts
    where user_id = tests.get_supabase_uid('j_visible')
  ),
  0::bigint,
  'a broker cannot read the seeker phone or email'
);

select is(
  public.requirement_listing_match(
    'b1919101-0000-4000-8000-000000000001',
    'b1919301-0000-4000-8000-000000000001'
  ),
  100,
  'gender is stored and is not part of the match score'
);

select is(
  public.requirement_listing_match(
    'b1919101-0000-4000-8000-000000000001',
    'b1919302-0000-4000-8000-000000000002'
  ),
  0,
  'a hidden brief scores 0 for a broker'
);

select is(
  (
    select count(*)
    from public.seekers_for_my_listings()
    where requirement_id = 'b1919301-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'matching seekers includes the opted-in brief'
);

select is(
  (
    select display_name
    from public.seekers_for_my_listings()
    where requirement_id = 'b1919301-0000-4000-8000-000000000001'
  ),
  'Ananya Iyer',
  'matching seekers shows the display name'
);

select is(
  (
    select match_percent
    from public.seekers_for_my_listings()
    where requirement_id = 'b1919301-0000-4000-8000-000000000001'
  ),
  100,
  'matching seekers uses the listing score'
);

select is(
  (
    select count(*)
    from public.seekers_for_my_listings()
    where requirement_id in (
      'b1919302-0000-4000-8000-000000000002',
      'b1919303-0000-4000-8000-000000000003'
    )
  ),
  0::bigint,
  'matching seekers hides opted-out briefs and drafts'
);

select ok(
  not exists (
    select 1
    from pg_proc as proc
    join pg_namespace as ns on ns.oid = proc.pronamespace
    where ns.nspname = 'public'
      and proc.proname = 'seekers_for_my_listings'
      and pg_get_function_result(proc.oid) ~* 'email|phone'
  ),
  'seekers_for_my_listings does not return email or phone'
);

update public.listing_requirements
set about_me = 'Edited by a broker'
where id = 'b1919301-0000-4000-8000-000000000001';

select is(
  (
    select about_me
    from public.listing_requirements
    where id = 'b1919301-0000-4000-8000-000000000001'
  ),
  'Bright 2 BHK in Koramangala.',
  'a broker cannot edit another person''s requirement'
);

update public.listing_requirements
set about_me = 'Edited by a broker'
where id = 'b1919302-0000-4000-8000-000000000002';

reset role;
select is(
  (
    select about_me
    from public.listing_requirements
    where id = 'b1919302-0000-4000-8000-000000000002'
  ),
  'This brief stays private.',
  'a broker cannot edit a hidden requirement'
);

select tests.authenticate_as('j_stranger');
set local role authenticated;

select is(
  (
    select count(*)
    from public.broker_profiles
    where user_id = tests.get_supabase_uid('j_broker')
  ),
  0::bigint,
  'a stranger cannot read a broker phone'
);

update public.listing_requirements
set city = 'Chennai'
where id = 'b1919301-0000-4000-8000-000000000001';

select is(
  (
    select city
    from public.listing_requirements
    where id = 'b1919301-0000-4000-8000-000000000001'
  ),
  'Bengaluru',
  'a stranger cannot edit another person''s requirement'
);

select throws_ok(
  $$insert into public.listing_requirements (
      user_id, city, budget_min_inr, budget_max_inr, about_me
    ) values (
      tests.get_supabase_uid('j_visible'),
      'Pune',
      10000,
      20000,
      'Not mine'
    )$$,
  '42501',
  NULL,
  'nobody can insert a requirement for another person'
);

select is(
  (select count(*) from public.seekers_for_my_listings()),
  0::bigint,
  'someone with no listing gets an empty seeker list'
);

reset role;
select tests.authenticate_as('j_host');
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
  'b1919102-0000-4000-8000-000000000002',
  auth.uid(),
  '1 BHK in Baner',
  'Baner',
  'Pune',
  'apartment',
  'furnished',
  16000
);

select is(
  (
    select count(*)
    from public.listing_requirements
    where id = 'b1919301-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'a host can read a published discoverable brief'
);

select is(
  (
    select count(*)
    from public.listing_requirements
    where id = 'b1919302-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'a host cannot read a brief that opted out'
);

update public.listing_requirements
set about_me = 'Edited by a host'
where id = 'b1919301-0000-4000-8000-000000000001';

select is(
  (
    select about_me
    from public.listing_requirements
    where id = 'b1919301-0000-4000-8000-000000000001'
  ),
  'Bright 2 BHK in Koramangala.',
  'a host cannot edit another person''s requirement'
);

reset role;
select tests.authenticate_as('j_visible');
set local role authenticated;

update public.listing_requirements
set about_me = 'Updated by me'
where id = 'b1919301-0000-4000-8000-000000000001';

select is(
  (
    select about_me
    from public.listing_requirements
    where id = 'b1919301-0000-4000-8000-000000000001'
  ),
  'Updated by me',
  'the owner can edit their own requirement'
);

update public.listing_requirements
set about_me = 'Taken over'
where id = 'b1919302-0000-4000-8000-000000000002';

reset role;
select is(
  (
    select about_me
    from public.listing_requirements
    where id = 'b1919302-0000-4000-8000-000000000002'
  ),
  'This brief stays private.',
  'one seeker cannot edit another seeker''s requirement'
);

select tests.authenticate_as('j_visible');
set local role authenticated;

insert into public.blocks (blocker_id, blocked_user_id)
values (auth.uid(), tests.get_supabase_uid('j_broker'));

reset role;
select tests.authenticate_as('j_broker');
set local role authenticated;

select is(
  (
    select count(*)
    from public.listing_requirements
    where id = 'b1919301-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'a blocked broker cannot read the brief'
);

select is(
  (
    select count(*)
    from public.seekers_for_my_listings()
    where requirement_id = 'b1919301-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'a blocked broker does not see that seeker in the match list'
);

select is(
  (
    select phone
    from public.broker_profiles
    where user_id = auth.uid()
  ),
  '+919876543210',
  'a broker can still read their own registration phone'
);

reset role;
set local role anon;

select throws_ok(
  $$select * from public.seekers_for_my_listings()$$,
  '42501',
  NULL,
  'anonymous callers cannot list seekers'
);

select * from finish();
rollback;
