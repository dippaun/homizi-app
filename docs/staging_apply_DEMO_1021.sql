-- Demo mode: host "What seekers need" must list published briefs even when
-- the caller has no listing yet. The function is security definer so a host
-- can read opted-in briefs without a policy that exposes phone or email.
-- Apply in the Supabase SQL editor after the 2026-10-19 requirement migration.
-- No secrets. Seed rows attach only to qa+tenant and qa+flatmate mailboxes
-- that already exist.

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
