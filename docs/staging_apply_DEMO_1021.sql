-- Demo mode: host "What seekers need" must list published briefs even when
-- the caller has no listing yet. The function is security definer so a host
-- can read opted-in briefs without a policy that exposes phone or email.
-- Apply in the Supabase SQL editor after the 2026-10-19 requirement migration.
-- No secrets. Seed rows attach only to qa+ mailboxes that already exist.
-- The block below asks staging to create qa+demo01 … qa+demo12 when that
-- helper is enabled, then writes 12 briefs, 12 listings, and 12 flatmate
-- profiles across Bengaluru, Pune, Mumbai, Ahmedabad, and Delhi.

create or replace function public.seekers_for_my_listings()
returns table (
  requirement_id uuid,
  listing_id uuid,
  display_name text,
  city text,
  localities text[],
  budget_min_inr integer,
  budget_max_inr integer,
  room_type text,
  seeker_kind text,
  about_me text,
  profession text,
  match_percent integer
)
language sql
stable
security definer
set search_path = public
as $$
  with mine as (
    select p.id
    from public.properties as p
    where p.host_user_id = auth.uid()
      and p.status in ('published', 'draft')
  ),
  scored as (
    select distinct on (r.id)
      r.id as requirement_id,
      p.id as listing_id,
      pr.display_name,
      r.city,
      r.localities,
      r.budget_min_inr,
      r.budget_max_inr,
      array_to_string(coalesce(r.room_type, '{}'::text[]), ', ') as room_type,
      r.seeker_kind,
      r.about_me,
      array_to_string(coalesce(r.profession, '{}'::text[]), ', ') as profession,
      fit.match_percent
    from mine
    join public.properties as p on p.id = mine.id
    join public.listing_requirements as r
      on r.status = 'published'
     and r.discoverable
     and r.user_id is distinct from auth.uid()
    left join public.profiles as pr on pr.user_id = r.user_id
    cross join lateral (
      select public.requirement_listing_match(p.id, r.id) as match_percent
    ) as fit
    order by r.id, fit.match_percent desc, p.id
  )
  select * from scored
  union all
  select
    r.id,
    null::uuid,
    coalesce(pr.display_name, 'Seeker'),
    r.city,
    r.localities,
    r.budget_min_inr,
    r.budget_max_inr,
    array_to_string(coalesce(r.room_type, '{}'::text[]), ', '),
    r.seeker_kind,
    r.about_me,
    array_to_string(coalesce(r.profession, '{}'::text[]), ', '),
    72
  from public.listing_requirements as r
  left join public.profiles as pr on pr.user_id = r.user_id
  where r.status = 'published'
    and r.discoverable
    and r.user_id is distinct from auth.uid()
    and not exists (select 1 from mine);
$$;

comment on function public.seekers_for_my_listings() is
  'Published opted-in briefs for the caller. Uses listing scores when the caller has a home, otherwise a baseline. No phone or email.';

revoke all on function public.seekers_for_my_listings() from public, anon;
grant execute on function public.seekers_for_my_listings() to authenticated;

insert into public.listing_requirements (
  user_id,
  city,
  localities,
  budget_min_inr,
  budget_max_inr,
  status,
  seeker_kind,
  room_type,
  about_me,
  discoverable,
  profession
)
select
  u.id,
  'Bengaluru',
  array['Koramangala', 'Indiranagar'],
  20000,
  35000,
  'published',
  'tenant',
  array['2bhk'],
  'Architect in Indiranagar. I want a bright 2 BHK on an 11 month lease.',
  true,
  array['working']
from public.users as u
join auth.users as a on a.id = u.id
where lower(a.email) = 'qa+tenant@homizi.in'
  and not exists (
    select 1
    from public.listing_requirements as existing
    where existing.user_id = u.id
      and existing.about_me = 'Architect in Indiranagar. I want a bright 2 BHK on an 11 month lease.'
  );

insert into public.listing_requirements (
  user_id,
  city,
  localities,
  budget_min_inr,
  budget_max_inr,
  status,
  seeker_kind,
  room_type,
  about_me,
  discoverable,
  profession
)
select
  u.id,
  'Mumbai',
  array['Bandra West', 'Andheri West'],
  18000,
  28000,
  'published',
  'roommate',
  array['private_room'],
  'Product designer looking for a quiet flatmate near Bandra West.',
  true,
  array['working']
from public.users as u
join auth.users as a on a.id = u.id
where lower(a.email) = 'qa+flatmate@homizi.in'
  and not exists (
    select 1
    from public.listing_requirements as existing
    where existing.user_id = u.id
      and existing.about_me = 'Product designer looking for a quiet flatmate near Bandra West.'
  );

-- Twelve opted-in briefs, twelve published homes, and twelve flatmate profiles.
-- Idempotent. Skips a row when the same about text or title is already stored.
-- Creates qa+demo01@homizi.in … qa+demo12@homizi.in only when the staging
-- helper is installed and test accounts are enabled. No passwords are written here.

do $demo_mailboxes$
declare
  i integer;
begin
  if to_regprocedure('public.staging_create_test_user(text)') is null then
    return;
  end if;
  for i in 1..12 loop
    begin
      perform public.staging_create_test_user(
        'qa+demo' || lpad(i::text, 2, '0') || '@homizi.in'
      );
    exception
      when others then
        null;
    end;
  end loop;
end
$demo_mailboxes$;

insert into public.users (id)
select a.id
from auth.users as a
where lower(a.email) ~ '^qa\+demo[0-9]{2}@homizi\.in$'
  and not exists (
    select 1 from public.users as u where u.id = a.id
  );

insert into public.profiles (user_id, display_name, occupation, public_bio)
select
  a.id,
  seed.display_name,
  seed.occupation,
  seed.bio
from (
  values
    ('qa+demo01@homizi.in', 'Ananya Iyer', 'Architect', 'Bright 2 BHK in Bengaluru, 11 month lease.'),
    ('qa+demo02@homizi.in', 'Rohan Mehta', 'Product designer', 'Quiet flatmate near Bandra West.'),
    ('qa+demo03@homizi.in', 'Priya Nair', 'Teacher', '1 BHK near the bus in Kothrud.'),
    ('qa+demo04@homizi.in', 'Kabir Singh', 'Analyst', 'Shared room in Dwarka with a desk.'),
    ('qa+demo05@homizi.in', 'Dev Patel', 'Student', 'Furnished 1 RK near Vastrapur.'),
    ('qa+demo06@homizi.in', 'Meera Krishnan', 'Architect', 'Private room in Jayanagar, tidy kitchen.'),
    ('qa+demo07@homizi.in', 'Ishita Banerjee', 'Student', 'Shared room in Karve Nagar, vegetarian.'),
    ('qa+demo08@homizi.in', 'Fatima Sheikh', 'Engineer', '1 BHK in Andheri East, short commute.'),
    ('qa+demo09@homizi.in', 'Nikhil Rao', 'Engineer', 'Private room in Whitefield, work from home.'),
    ('qa+demo10@homizi.in', 'Nisha Patel', 'Architect', '2 BHK in Satellite with a lift.'),
    ('qa+demo11@homizi.in', 'Aditya Kulkarni', 'Intern', '1 BHK in Kharadi from November.'),
    ('qa+demo12@homizi.in', 'Diya Kapoor', 'Accountant', 'Family 3 BHK in Vasant Kunj.')
) as seed(email, display_name, occupation, bio)
join auth.users as a on lower(a.email) = seed.email
join public.users as u on u.id = a.id
on conflict (user_id) do update
set display_name = excluded.display_name,
    occupation = excluded.occupation,
    public_bio = excluded.public_bio
where public.profiles.display_name = '';

insert into public.listing_requirements (
  user_id, city, localities, budget_min_inr, budget_max_inr, status,
  seeker_kind, room_type, about_me, discoverable, profession
)
select
  person.id,
  seed.city,
  seed.localities,
  seed.budget_min,
  seed.budget_max,
  'published',
  seed.kind,
  seed.room_type,
  seed.about_me,
  true,
  seed.profession
from (
  values
    (1, 'Bengaluru', array['Koramangala', 'Indiranagar']::text[], 20000, 35000, 'tenant', array['2bhk']::text[], array['working']::text[], 'Ananya Iyer wants a bright 2 BHK in Koramangala on an 11 month lease.'),
    (2, 'Mumbai', array['Bandra West', 'Andheri West']::text[], 18000, 28000, 'roommate', array['private_room']::text[], array['working']::text[], 'Rohan Mehta wants a quiet private room near Bandra West.'),
    (3, 'Pune', array['Kothrud', 'Karve Nagar']::text[], 12000, 20000, 'tenant', array['1bhk']::text[], array['working']::text[], 'Priya Nair wants a 1 BHK near the bus in Kothrud.'),
    (4, 'Delhi', array['Dwarka', 'Vasant Kunj']::text[], 14000, 24000, 'roommate', array['shared']::text[], array['working']::text[], 'Kabir Singh wants a shared room and a desk in Dwarka.'),
    (5, 'Ahmedabad', array['Vastrapur', 'Satellite']::text[], 8000, 14000, 'tenant', array['1rk']::text[], array['student']::text[], 'Dev Patel wants a furnished 1 RK near Vastrapur.'),
    (6, 'Bengaluru', array['Jayanagar', 'JP Nagar']::text[], 14000, 24000, 'roommate', array['private_room']::text[], array['working']::text[], 'Meera Krishnan wants a private room in Jayanagar and a tidy kitchen.'),
    (7, 'Pune', array['Baner', 'Aundh']::text[], 16000, 26000, 'tenant', array['2bhk']::text[], array['working']::text[], 'Ishita Banerjee wants a 2 BHK in Baner for a working household.'),
    (8, 'Mumbai', array['Powai', 'Andheri East']::text[], 25000, 40000, 'tenant', array['2bhk']::text[], array['working']::text[], 'Fatima Sheikh wants a 2 BHK in Powai with a lift.'),
    (9, 'Bengaluru', array['Whitefield', 'Marathahalli']::text[], 18000, 30000, 'roommate', array['private_room']::text[], array['working']::text[], 'Nikhil Rao wants a private room in Whitefield and works from home.'),
    (10, 'Ahmedabad', array['Navrangpura', 'Paldi']::text[], 12000, 22000, 'tenant', array['1bhk']::text[], array['working']::text[], 'Nisha Patel wants a 1 BHK near Navrangpura with a lift.'),
    (11, 'Pune', array['Kharadi', 'Viman Nagar']::text[], 15000, 24000, 'roommate', array['private_room']::text[], array['student']::text[], 'Aditya Kulkarni wants a private room in Kharadi from November.'),
    (12, 'Delhi', array['Vasant Kunj', 'Saket']::text[], 28000, 45000, 'tenant', array['3bhk']::text[], array['working']::text[], 'Diya Kapoor wants a 3 BHK in Vasant Kunj for the family.')
) as seed(n, city, localities, budget_min, budget_max, kind, room_type, profession, about_me)
join lateral (
  select u.id
  from public.users as u
  join auth.users as a on a.id = u.id
  where lower(a.email) ~ '^qa\+(demo|tenant|flatmate|host)'
     or lower(a.email) ~ '^test[0-9]*@homizi\.in$'
  order by
    case
      when lower(a.email) = 'qa+demo' || lpad(seed.n::text, 2, '0') || '@homizi.in' then 0
      when lower(a.email) = 'qa+tenant@homizi.in' then 1
      when lower(a.email) = 'qa+flatmate@homizi.in' then 2
      else 3
    end,
    a.email
  limit 1
) as person on true
where not exists (
  select 1
  from public.listing_requirements as existing
  where existing.about_me = seed.about_me
);

insert into public.properties (
  host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, deposit_inr, maintenance_inr, status, occupancy_max, published_at
)
select
  host.id,
  seed.title,
  seed.locality,
  seed.city,
  seed.property_type::public.property_type,
  seed.furnishing::public.furnishing,
  seed.rent_inr,
  seed.deposit_inr,
  seed.maintenance_inr,
  'published',
  seed.occupancy_max,
  now()
from (
  values
    ('Sunlit 2BHK in Koramangala', 'Koramangala', 'Bengaluru', 'apartment', 'furnished', 28000, 84000, 2000, 3),
    ('Private room in Baner', 'Baner', 'Pune', 'private_room', 'semi_furnished', 14000, 28000, 500, 1),
    ('2BHK in Bandra West', 'Bandra West', 'Mumbai', 'apartment', 'semi_furnished', 42000, 126000, 3000, 3),
    ('1BHK in Vastrapur', 'Vastrapur', 'Ahmedabad', 'apartment', 'furnished', 16000, 32000, 800, 2),
    ('3BHK in Vasant Kunj', 'Vasant Kunj', 'Delhi', 'apartment', 'furnished', 45000, 135000, 3500, 4),
    ('2BHK near Whitefield metro', 'Whitefield', 'Bengaluru', 'apartment', 'semi_furnished', 26000, 78000, 1800, 3),
    ('1BHK in Kothrud', 'Kothrud', 'Pune', 'apartment', 'semi_furnished', 18000, 36000, 900, 2),
    ('Room in Andheri West', 'Andheri West', 'Mumbai', 'private_room', 'furnished', 22000, 44000, 1000, 1),
    ('2BHK in Satellite', 'Satellite', 'Ahmedabad', 'apartment', 'semi_furnished', 20000, 40000, 1200, 3),
    ('2BHK in Dwarka Sector 12', 'Dwarka', 'Delhi', 'apartment', 'semi_furnished', 30000, 60000, 2000, 3),
    ('3BHK in Kharadi', 'Kharadi', 'Pune', 'apartment', 'furnished', 34000, 68000, 2200, 4),
    ('1BHK in Indiranagar', 'Indiranagar', 'Bengaluru', 'apartment', 'furnished', 32000, 96000, 2500, 2)
) as seed(title, locality, city, property_type, furnishing, rent_inr, deposit_inr, maintenance_inr, occupancy_max)
join lateral (
  select u.id
  from public.users as u
  join auth.users as a on a.id = u.id
  where lower(a.email) in (
    'qa+host@homizi.in',
    'qa+tenant@homizi.in',
    'qa+demo01@homizi.in'
  )
     or lower(a.email) ~ '^qa\+'
  order by
    case lower(a.email)
      when 'qa+host@homizi.in' then 0
      when 'qa+tenant@homizi.in' then 1
      else 2
    end
  limit 1
) as host on true
where not exists (
  select 1 from public.properties as existing where existing.title = seed.title
);

do $demo_flatmates$
declare
  food_is_array boolean;
begin
  select c.data_type = 'ARRAY'
  into food_is_array
  from information_schema.columns as c
  where c.table_schema = 'public'
    and c.table_name = 'roommate_profiles'
    and c.column_name = 'food';
  if food_is_array is null then
    return;
  end if;

  if food_is_array then
    insert into public.roommate_profiles (
      user_id, discoverable, open_to_flatmates, seeking_role, city, localities,
      budget_min_inr, budget_max_inr, gender, gender_preference, occupancy,
      food, smoking, pets, sleep, cleanliness, social, wfh, cooking, guests,
      languages, hobbies, thoughts, age
    )
    select
      a.id, true, true, 'roommate', seed.city, seed.localities,
      seed.budget_min, seed.budget_max, seed.gender, 'any', 'shared',
      array['veg']::text[], array['never']::text[], array['none']::text[],
      array['early']::text[], 4, array['quiet']::text[], 'hybrid',
      array['often']::text[], array['rare']::text[],
      array['English', 'Hindi']::text[], array['reading']::text[],
      seed.thoughts, seed.age
    from (
      values
        ('qa+demo01@homizi.in', 'Bengaluru', array['Koramangala']::text[], 20000, 35000, 'woman', 27, 'Quiet flat in Koramangala. I cook most nights.'),
        ('qa+demo02@homizi.in', 'Mumbai', array['Bandra West']::text[], 18000, 28000, 'man', 29, 'Private room near Bandra West after a late shift.'),
        ('qa+demo03@homizi.in', 'Pune', array['Kothrud']::text[], 12000, 20000, 'woman', 26, 'Early mornings and a vegetarian kitchen in Kothrud.'),
        ('qa+demo04@homizi.in', 'Delhi', array['Dwarka']::text[], 14000, 24000, 'man', 28, 'Shared room in Dwarka with a desk for work.'),
        ('qa+demo05@homizi.in', 'Ahmedabad', array['Vastrapur']::text[], 8000, 14000, 'man', 22, 'College near Vastrapur. I cook on weekends.'),
        ('qa+demo06@homizi.in', 'Bengaluru', array['Jayanagar']::text[], 14000, 24000, 'woman', 27, 'Tidy kitchen in Jayanagar, three office days.'),
        ('qa+demo07@homizi.in', 'Pune', array['Baner']::text[], 16000, 26000, 'woman', 24, 'Baner flat, calm weeknights.'),
        ('qa+demo08@homizi.in', 'Mumbai', array['Andheri East']::text[], 22000, 36000, 'woman', 30, 'Short commute from Andheri East.'),
        ('qa+demo09@homizi.in', 'Bengaluru', array['Whitefield']::text[], 18000, 30000, 'man', 31, 'Work from home in Whitefield, headphones on calls.'),
        ('qa+demo10@homizi.in', 'Ahmedabad', array['Satellite']::text[], 15000, 26000, 'woman', 29, 'Lift and a bright room in Satellite.'),
        ('qa+demo11@homizi.in', 'Pune', array['Kharadi']::text[], 14000, 22000, 'man', 23, 'Internship in Kharadi from November.'),
        ('qa+demo12@homizi.in', 'Delhi', array['Vasant Kunj']::text[], 25000, 40000, 'woman', 32, 'Family stay in Vasant Kunj for a year.')
    ) as seed(email, city, localities, budget_min, budget_max, gender, age, thoughts)
    join auth.users as a on lower(a.email) = seed.email
    join public.users as u on u.id = a.id
    on conflict (user_id) do update
    set discoverable = true,
        open_to_flatmates = true,
        city = excluded.city,
        localities = excluded.localities,
        thoughts = excluded.thoughts;
  else
    insert into public.roommate_profiles (
      user_id, discoverable, open_to_flatmates, seeking_role, city, localities,
      budget_min_inr, budget_max_inr, gender, gender_preference, occupancy,
      food, smoking, pets, sleep, cleanliness, social, wfh, cooking, guests,
      languages, hobbies, thoughts, age
    )
    select
      a.id, true, true, 'roommate', seed.city, seed.localities,
      seed.budget_min, seed.budget_max, seed.gender, 'any', 'shared',
      'veg', 'never', 'none', 'early', 4, 'quiet', 'hybrid', 'often', 'rare',
      array['English', 'Hindi']::text[], array['reading']::text[],
      seed.thoughts, seed.age
    from (
      values
        ('qa+demo01@homizi.in', 'Bengaluru', array['Koramangala']::text[], 20000, 35000, 'woman', 27, 'Quiet flat in Koramangala. I cook most nights.'),
        ('qa+demo02@homizi.in', 'Mumbai', array['Bandra West']::text[], 18000, 28000, 'man', 29, 'Private room near Bandra West after a late shift.'),
        ('qa+demo03@homizi.in', 'Pune', array['Kothrud']::text[], 12000, 20000, 'woman', 26, 'Early mornings and a vegetarian kitchen in Kothrud.'),
        ('qa+demo04@homizi.in', 'Delhi', array['Dwarka']::text[], 14000, 24000, 'man', 28, 'Shared room in Dwarka with a desk for work.'),
        ('qa+demo05@homizi.in', 'Ahmedabad', array['Vastrapur']::text[], 8000, 14000, 'man', 22, 'College near Vastrapur. I cook on weekends.'),
        ('qa+demo06@homizi.in', 'Bengaluru', array['Jayanagar']::text[], 14000, 24000, 'woman', 27, 'Tidy kitchen in Jayanagar, three office days.'),
        ('qa+demo07@homizi.in', 'Pune', array['Baner']::text[], 16000, 26000, 'woman', 24, 'Baner flat, calm weeknights.'),
        ('qa+demo08@homizi.in', 'Mumbai', array['Andheri East']::text[], 22000, 36000, 'woman', 30, 'Short commute from Andheri East.'),
        ('qa+demo09@homizi.in', 'Bengaluru', array['Whitefield']::text[], 18000, 30000, 'man', 31, 'Work from home in Whitefield, headphones on calls.'),
        ('qa+demo10@homizi.in', 'Ahmedabad', array['Satellite']::text[], 15000, 26000, 'woman', 29, 'Lift and a bright room in Satellite.'),
        ('qa+demo11@homizi.in', 'Pune', array['Kharadi']::text[], 14000, 22000, 'man', 23, 'Internship in Kharadi from November.'),
        ('qa+demo12@homizi.in', 'Delhi', array['Vasant Kunj']::text[], 25000, 40000, 'woman', 32, 'Family stay in Vasant Kunj for a year.')
    ) as seed(email, city, localities, budget_min, budget_max, gender, age, thoughts)
    join auth.users as a on lower(a.email) = seed.email
    join public.users as u on u.id = a.id
    on conflict (user_id) do update
    set discoverable = true,
        open_to_flatmates = true,
        city = excluded.city,
        localities = excluded.localities,
        thoughts = excluded.thoughts;
  end if;
end
$demo_flatmates$;
