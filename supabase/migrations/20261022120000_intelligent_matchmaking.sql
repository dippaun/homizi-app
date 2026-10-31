-- HOMIZI intelligent matchmaking for a project that already ran earlier staging SQL.
-- Paste this whole file into the dashboard SQL editor. Running it again is safe.
-- Do not apply it from the app, from CI, or from a migration runner in this step.
--
-- The demo scorer lives in lib/features/matching/domain/intelligent_match.dart.
-- This file is the matching schema only. It does not add verification, listing
-- freshness, or reply activity into a compatibility number.
--
-- Colour rule: 70-100 green (strong), 40-69 yellow (partial), 0-39 red (low).
-- A must-have miss forces red and the flag important_mismatch. A high percent
-- does not hide that flag.
--
-- Boosters (complete photos, a recent listing, a high rating) are tie-breaks
-- only. They are not columns on the score. A new listing is not penalised for
-- having no rating and no fresh-listing bonus.
-- Verification badges stay on the existing verification tables. They are not
-- written here and they are not an input to compatibility_colour.
-- Roomie compatibility is a different score. It is not stored on match_priority.
--
-- No service role key, secret key, database password, phone, or email is here.

reset role;

do $$
begin
  if to_regclass('public.users') is null
     or to_regprocedure('public.set_updated_at()') is null then
    raise exception 'Apply the earlier HOMIZI staging SQL before this file.';
  end if;
end $$;

create table if not exists public.match_priority (
  user_id uuid not null references public.users (id) on delete cascade,
  side text not null,
  factor_key text not null,
  rank integer not null,
  flexibility text not null default 'flexible',
  updated_at timestamptz not null default now(),
  primary key (user_id, side, factor_key)
);

do $match_priority_checks$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'match_priority_side'
  ) then
    alter table public.match_priority
      add constraint match_priority_side
      check (side in ('tenant', 'host'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'match_priority_rank'
  ) then
    alter table public.match_priority
      add constraint match_priority_rank
      check (rank between 1 and 10);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'match_priority_flexibility'
  ) then
    alter table public.match_priority
      add constraint match_priority_flexibility
      check (flexibility in ('must_have', 'flexible'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'match_priority_factor_key'
  ) then
    alter table public.match_priority
      add constraint match_priority_factor_key
      check (char_length(factor_key) between 1 and 40);
  end if;
end
$match_priority_checks$;

create unique index if not exists match_priority_rank_uidx
  on public.match_priority (user_id, side, rank);

comment on table public.match_priority is
  'Tenant or host ranks, 1 highest, at most 10. must_have mismatch caps colour at red. Verification is not a factor_key that feeds the score.';

create table if not exists public.match_office (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  label text not null,
  area text not null,
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz not null default now()
);

do $match_office_checks$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'match_office_label'
  ) then
    alter table public.match_office
      add constraint match_office_label
      check (char_length(label) between 1 and 80);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'match_office_area'
  ) then
    alter table public.match_office
      add constraint match_office_area
      check (char_length(area) between 1 and 40);
  end if;
end
$match_office_checks$;

comment on table public.match_office is
  'Area-level office pins for commute. A label is a neighbourhood, not a street address or a building.';

create table if not exists public.match_commute_setting (
  user_id uuid primary key references public.users (id) on delete cascade,
  transport_mode text not null default 'car',
  max_minutes integer not null default 30,
  active_office_id uuid references public.match_office (id) on delete set null,
  updated_at timestamptz not null default now()
);

do $match_commute_checks$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'match_commute_mode'
  ) then
    alter table public.match_commute_setting
      add constraint match_commute_mode
      check (transport_mode in ('car', 'two_wheeler', 'public', 'walk'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'match_commute_max'
  ) then
    alter table public.match_commute_setting
      add constraint match_commute_max
      check (max_minutes in (15, 30, 45, 60));
  end if;
end
$match_commute_checks$;

comment on table public.match_commute_setting is
  'Active office, mode, and max one-way minutes. Commute is a rankable priority only when the user adds it. It is not a verification signal.';

create table if not exists public.match_signal (
  user_id uuid not null references public.users (id) on delete cascade,
  factor_key text not null,
  nudge smallint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, factor_key)
);

do $match_signal_checks$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'match_signal_nudge'
  ) then
    alter table public.match_signal
      add constraint match_signal_nudge
      check (nudge between -3 and 3);
  end if;
end
$match_signal_checks$;

comment on table public.match_signal is
  'Likes, skips, and saves nudge a factor weight slightly. Reset deletes the user rows. Nudge cannot exceed 3 in either direction.';

create table if not exists public.match_decision (
  user_id uuid not null references public.users (id) on delete cascade,
  target_kind text not null,
  target_id text not null,
  decision text not null,
  saved boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, target_kind, target_id)
);

do $match_decision_checks$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'match_decision_kind'
  ) then
    alter table public.match_decision
      add constraint match_decision_kind
      check (target_kind in ('listing', 'tenant_lead'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'match_decision_value'
  ) then
    alter table public.match_decision
      add constraint match_decision_value
      check (decision in ('like', 'skip'));
  end if;
end
$match_decision_checks$;

comment on table public.match_decision is
  'Like, skip, and save for a listing or a tenant lead. Contact values are not stored on this row.';

create table if not exists public.match_visit (
  user_id uuid not null references public.users (id) on delete cascade,
  target_id text not null,
  slot_label text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, target_id)
);

do $match_visit_checks$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'match_visit_slot'
  ) then
    alter table public.match_visit
      add constraint match_visit_slot
      check (char_length(slot_label) between 1 and 40);
  end if;
end
$match_visit_checks$;

comment on table public.match_visit is
  'A visit slot label such as Saturday 11:00 AM. Not a street address.';

create table if not exists public.match_share (
  user_id uuid not null references public.users (id) on delete cascade,
  target_id text not null,
  contact_consent boolean not null default false,
  documents_shared boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, target_id)
);

comment on table public.match_share is
  'Consent flags only. The phone and email stay on private_contacts and are not copied here.';

drop trigger if exists match_priority_set_updated_at on public.match_priority;
create trigger match_priority_set_updated_at
  before update on public.match_priority
  for each row execute function public.set_updated_at();

drop trigger if exists match_commute_setting_set_updated_at
  on public.match_commute_setting;
create trigger match_commute_setting_set_updated_at
  before update on public.match_commute_setting
  for each row execute function public.set_updated_at();

drop trigger if exists match_signal_set_updated_at on public.match_signal;
create trigger match_signal_set_updated_at
  before update on public.match_signal
  for each row execute function public.set_updated_at();

drop trigger if exists match_decision_set_updated_at on public.match_decision;
create trigger match_decision_set_updated_at
  before update on public.match_decision
  for each row execute function public.set_updated_at();

drop trigger if exists match_share_set_updated_at on public.match_share;
create trigger match_share_set_updated_at
  before update on public.match_share
  for each row execute function public.set_updated_at();

-- Colour only. Verification, photos, freshness, and rating are not arguments.
create or replace function public.compatibility_colour(
  score integer,
  important_mismatch boolean
) returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when coalesce(important_mismatch, false) then 'red'
    when score >= 70 then 'green'
    when score >= 40 then 'yellow'
    else 'red'
  end;
$$;

comment on function public.compatibility_colour(integer, boolean) is
  'Green 70-100, yellow 40-69, red 0-39. A must-have miss returns red. Verification is not an argument.';

revoke all on function public.compatibility_colour(integer, boolean)
  from public, anon;
grant execute on function public.compatibility_colour(integer, boolean)
  to authenticated;

alter table public.match_priority enable row level security;
alter table public.match_office enable row level security;
alter table public.match_commute_setting enable row level security;
alter table public.match_signal enable row level security;
alter table public.match_decision enable row level security;
alter table public.match_visit enable row level security;
alter table public.match_share enable row level security;

drop policy if exists match_priority_all on public.match_priority;
create policy match_priority_all on public.match_priority
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists match_office_all on public.match_office;
create policy match_office_all on public.match_office
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists match_commute_setting_all on public.match_commute_setting;
create policy match_commute_setting_all on public.match_commute_setting
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists match_signal_all on public.match_signal;
create policy match_signal_all on public.match_signal
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists match_decision_all on public.match_decision;
create policy match_decision_all on public.match_decision
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists match_visit_all on public.match_visit;
create policy match_visit_all on public.match_visit
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists match_share_all on public.match_share;
create policy match_share_all on public.match_share
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.match_priority from public, anon;
revoke all on public.match_office from public, anon;
revoke all on public.match_commute_setting from public, anon;
revoke all on public.match_signal from public, anon;
revoke all on public.match_decision from public, anon;
revoke all on public.match_visit from public, anon;
revoke all on public.match_share from public, anon;

grant select, insert, update, delete on public.match_priority to authenticated;
grant select, insert, update, delete on public.match_office to authenticated;
grant select, insert, update, delete on public.match_commute_setting to authenticated;
grant select, insert, update, delete on public.match_signal to authenticated;
grant select, insert, update, delete on public.match_decision to authenticated;
grant select, insert, update, delete on public.match_visit to authenticated;
grant select, insert, update, delete on public.match_share to authenticated;

