-- Occupancy + Shared home. Unapplied. Paste docs/staging_apply_OCCUPANCY_1114.sql
-- in the Supabase SQL editor (staging) after the owner says yes. Safe to run twice.
-- Same text as supabase/migrations/20261114190000_shared_homes.sql.
-- The app works without it: sample homes and device copies are used.

-- Occupancy + Shared home (Nov 14, 2026). NOT APPLIED: the owner applies it.
-- Who already lives in a listed home and which rooms are free, plus join
-- requests from seekers. The app works without these tables: sample homes
-- and device copies are used, and a join request still sends the normal
-- interest the host sees under Interested seekers.
-- First names and last initials only. No phone, email, or ID numbers.

create table if not exists public.shared_home_details (
  listing_id uuid primary key references public.properties (id) on delete cascade,
  host_user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_label text not null check (char_length(btrim(property_label)) between 2 and 20),
  total_rooms smallint not null check (total_rooms between 1 and 10),
  currently_living smallint not null default 0 check (currently_living between 0 and 20),
  vacant_rooms smallint not null check (vacant_rooms between 0 and 10),
  total_capacity smallint not null check (total_capacity between 1 and 20),
  occupancy_type text not null default 'separate'
    check (occupancy_type in ('single', 'double', 'separate')),
  housemates jsonb not null default '[]'::jsonb
    check (jsonb_typeof(housemates) = 'array' and jsonb_array_length(housemates) <= 6),
  updated_at timestamptz not null default now(),
  constraint shared_home_details_rooms check (vacant_rooms <= total_rooms),
  constraint shared_home_details_capacity check (currently_living <= total_capacity),
  constraint shared_home_details_no_contact check (
    housemates::text !~ '@' and housemates::text !~ '[0-9]{10}'
  )
);

alter table public.shared_home_details enable row level security;

drop policy if exists shared_home_details_read on public.shared_home_details;
create policy shared_home_details_read on public.shared_home_details
  for select to authenticated
  using (
    host_user_id = auth.uid()
    or exists (
      select 1 from public.properties p
      where p.id = listing_id and p.status = 'published'
    )
  );

drop policy if exists shared_home_details_insert_own on public.shared_home_details;
create policy shared_home_details_insert_own on public.shared_home_details
  for insert to authenticated
  with check (
    host_user_id = auth.uid()
    and exists (
      select 1 from public.properties p
      where p.id = listing_id and p.host_user_id = auth.uid()
    )
  );

drop policy if exists shared_home_details_update_own on public.shared_home_details;
create policy shared_home_details_update_own on public.shared_home_details
  for update to authenticated
  using (host_user_id = auth.uid())
  with check (
    host_user_id = auth.uid()
    and exists (
      select 1 from public.properties p
      where p.id = listing_id and p.host_user_id = auth.uid()
    )
  );

drop policy if exists shared_home_details_delete_own on public.shared_home_details;
create policy shared_home_details_delete_own on public.shared_home_details
  for delete to authenticated
  using (host_user_id = auth.uid());

revoke all on public.shared_home_details from anon;
grant select, insert, update, delete on public.shared_home_details to authenticated;
grant all on public.shared_home_details to service_role;

create table if not exists public.shared_home_join_requests (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.properties (id) on delete cascade,
  requester_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  host_user_id uuid references auth.users (id) on delete cascade,
  requester_first_name text not null default 'A HOMIZI member'
    check (char_length(btrim(requester_first_name)) between 1 and 30
      and requester_first_name !~ '@'
      and requester_first_name !~ '[0-9]{6}'),
  mode text not null default 'individual' check (mode in ('individual', 'group')),
  people smallint not null default 1 check (people between 1 and 6),
  share_inr integer not null default 0 check (share_inr between 0 and 10000000),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'withdrawn', 'moved_in')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  moved_in_at timestamptz
);

create unique index if not exists shared_home_join_requests_open_idx
  on public.shared_home_join_requests (listing_id, requester_id)
  where status in ('pending', 'accepted', 'moved_in');

create index if not exists shared_home_join_requests_host_idx
  on public.shared_home_join_requests (host_user_id, created_at desc);

-- Fills the host from the listing and keeps status changes to the ones each
-- side may make: the host accepts or declines a pending request; the seeker
-- withdraws, or moves in after it was accepted. Nothing else changes.
create or replace function public.shared_home_join_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  host uuid;
begin
  if tg_op = 'INSERT' then
    select p.host_user_id into host
    from public.properties p
    where p.id = new.listing_id and p.status = 'published';
    if host is null then
      raise exception 'This home is not open for join requests.'
        using errcode = '42501';
    end if;
    if actor is not null and host = actor then
      raise exception 'You cannot join your own home.' using errcode = '42501';
    end if;
    new.host_user_id := host;
    new.status := 'pending';
    new.decided_at := null;
    new.moved_in_at := null;
    new.created_at := now();
    return new;
  end if;

  if new.listing_id is distinct from old.listing_id
    or new.requester_id is distinct from old.requester_id
    or new.host_user_id is distinct from old.host_user_id
    or new.requester_first_name is distinct from old.requester_first_name
    or new.mode is distinct from old.mode
    or new.people is distinct from old.people
    or new.share_inr is distinct from old.share_inr
    or new.created_at is distinct from old.created_at then
    raise exception 'Only the status of a join request can change.'
      using errcode = '42501';
  end if;

  if new.status = old.status or actor is null then
    return new;
  end if;

  if actor = old.host_user_id
    and old.status = 'pending'
    and new.status in ('accepted', 'declined') then
    new.decided_at := now();
    return new;
  end if;

  if actor = old.requester_id
    and (
      (old.status = 'pending' and new.status = 'withdrawn')
      or (old.status = 'accepted' and new.status in ('moved_in', 'withdrawn'))
    ) then
    if new.status = 'moved_in' then
      new.moved_in_at := now();
    end if;
    return new;
  end if;

  raise exception 'That status change is not allowed.' using errcode = '42501';
end;
$$;

revoke all on function public.shared_home_join_guard() from public, anon, authenticated;

drop trigger if exists shared_home_join_guard on public.shared_home_join_requests;
create trigger shared_home_join_guard
  before insert or update on public.shared_home_join_requests
  for each row execute function public.shared_home_join_guard();

alter table public.shared_home_join_requests enable row level security;

drop policy if exists shared_home_join_read on public.shared_home_join_requests;
create policy shared_home_join_read on public.shared_home_join_requests
  for select to authenticated
  using (requester_id = auth.uid() or host_user_id = auth.uid());

drop policy if exists shared_home_join_insert_own on public.shared_home_join_requests;
create policy shared_home_join_insert_own on public.shared_home_join_requests
  for insert to authenticated
  with check (requester_id = auth.uid());

drop policy if exists shared_home_join_update_party on public.shared_home_join_requests;
create policy shared_home_join_update_party on public.shared_home_join_requests
  for update to authenticated
  using (requester_id = auth.uid() or host_user_id = auth.uid())
  with check (requester_id = auth.uid() or host_user_id = auth.uid());

revoke all on public.shared_home_join_requests from anon;
grant select, insert, update on public.shared_home_join_requests to authenticated;
grant all on public.shared_home_join_requests to service_role;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261114190000',
  'shared_homes',
  array['docs/staging_apply_OCCUPANCY_1114.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
