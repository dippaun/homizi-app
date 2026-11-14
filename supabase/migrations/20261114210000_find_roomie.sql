-- Find Your Roomie (Nov 14, 2026). NOT APPLIED: the owner applies it.
-- Homes a pair saved together, and a joint request that each person confirms
-- for themselves. The app works without these tables: sample people and
-- homes stay on the device. No phone, email, or street address is stored.
-- Does not change shared_home_join_requests.

create table if not exists public.roommate_shortlists (
  id uuid primary key default gen_random_uuid(),
  match_id uuid references public.matches (id) on delete set null,
  member_a uuid not null references auth.users (id) on delete cascade,
  member_b uuid not null references auth.users (id) on delete cascade,
  listing_id text not null,
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default pg_catalog.now(),
  constraint roommate_shortlists_ordered check (member_a < member_b),
  constraint roommate_shortlists_actor check (
    created_by = member_a or created_by = member_b
  ),
  constraint roommate_shortlists_listing check (
    char_length(btrim(listing_id)) between 1 and 80
    and listing_id !~ '@'
    and listing_id !~ '\+'
  ),
  constraint roommate_shortlists_pair_listing unique (member_a, member_b, listing_id)
);

comment on table public.roommate_shortlists is
  'Homes a roommate pair saved to look at together. No contact details.';

alter table public.roommate_shortlists enable row level security;

drop policy if exists roommate_shortlists_read on public.roommate_shortlists;
create policy roommate_shortlists_read on public.roommate_shortlists
  for select to authenticated
  using (member_a = auth.uid() or member_b = auth.uid());

drop policy if exists roommate_shortlists_insert on public.roommate_shortlists;
create policy roommate_shortlists_insert on public.roommate_shortlists
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and (member_a = auth.uid() or member_b = auth.uid())
  );

drop policy if exists roommate_shortlists_delete on public.roommate_shortlists;
create policy roommate_shortlists_delete on public.roommate_shortlists
  for delete to authenticated
  using (member_a = auth.uid() or member_b = auth.uid());

revoke all on public.roommate_shortlists from anon;
grant select, insert, delete on public.roommate_shortlists to authenticated;
grant all on public.roommate_shortlists to service_role;

create index if not exists roommate_shortlists_member_b_idx
  on public.roommate_shortlists (member_b);

create table if not exists public.roommate_joint_requests (
  id uuid primary key default gen_random_uuid(),
  match_id uuid references public.matches (id) on delete set null,
  member_a uuid not null references auth.users (id) on delete cascade,
  member_b uuid not null references auth.users (id) on delete cascade,
  listing_id text not null,
  member_a_confirmed boolean not null default false,
  member_b_confirmed boolean not null default false,
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint roommate_joint_requests_ordered check (member_a < member_b),
  constraint roommate_joint_requests_actor check (
    created_by = member_a or created_by = member_b
  ),
  constraint roommate_joint_requests_listing check (
    char_length(btrim(listing_id)) between 1 and 80
    and listing_id !~ '@'
    and listing_id !~ '\+'
  ),
  constraint roommate_joint_requests_pair_listing unique (member_a, member_b, listing_id)
);

comment on table public.roommate_joint_requests is
  'One home a pair asked for. Each person can confirm only their own flag.';

-- Keeps a person from confirming for their roommate, and from rewriting
-- who the pair is. Runs as the table owner so the client cannot call it.
create or replace function public.roommate_joint_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null
    or (actor is distinct from new.member_a and actor is distinct from new.member_b) then
    raise exception 'Only the two people in this pair can change it.'
      using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    new.created_by := actor;
    new.created_at := pg_catalog.now();
    new.updated_at := pg_catalog.now();
    if actor = new.member_a then
      new.member_b_confirmed := false;
    else
      new.member_a_confirmed := false;
    end if;
    return new;
  end if;

  if new.id is distinct from old.id
    or new.member_a is distinct from old.member_a
    or new.member_b is distinct from old.member_b
    or new.listing_id is distinct from old.listing_id
    or new.match_id is distinct from old.match_id
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at then
    raise exception 'Only a confirmation flag can change.'
      using errcode = '42501';
  end if;

  if actor = old.member_a
    and new.member_b_confirmed is distinct from old.member_b_confirmed then
    raise exception 'You can only confirm for yourself.'
      using errcode = '42501';
  end if;

  if actor = old.member_b
    and new.member_a_confirmed is distinct from old.member_a_confirmed then
    raise exception 'You can only confirm for yourself.'
      using errcode = '42501';
  end if;

  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

revoke all on function public.roommate_joint_guard() from public, anon, authenticated;

drop trigger if exists roommate_joint_guard on public.roommate_joint_requests;
create trigger roommate_joint_guard
  before insert or update on public.roommate_joint_requests
  for each row execute function public.roommate_joint_guard();

alter table public.roommate_joint_requests enable row level security;

drop policy if exists roommate_joint_read on public.roommate_joint_requests;
create policy roommate_joint_read on public.roommate_joint_requests
  for select to authenticated
  using (member_a = auth.uid() or member_b = auth.uid());

drop policy if exists roommate_joint_insert on public.roommate_joint_requests;
create policy roommate_joint_insert on public.roommate_joint_requests
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and (member_a = auth.uid() or member_b = auth.uid())
  );

drop policy if exists roommate_joint_update on public.roommate_joint_requests;
create policy roommate_joint_update on public.roommate_joint_requests
  for update to authenticated
  using (member_a = auth.uid() or member_b = auth.uid())
  with check (member_a = auth.uid() or member_b = auth.uid());

drop policy if exists roommate_joint_delete on public.roommate_joint_requests;
create policy roommate_joint_delete on public.roommate_joint_requests
  for delete to authenticated
  using (member_a = auth.uid() or member_b = auth.uid());

revoke all on public.roommate_joint_requests from anon;
grant select, insert, update, delete on public.roommate_joint_requests to authenticated;
grant all on public.roommate_joint_requests to service_role;

create index if not exists roommate_joint_requests_member_b_idx
  on public.roommate_joint_requests (member_b);
