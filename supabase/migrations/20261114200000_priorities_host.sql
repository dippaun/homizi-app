-- Priorities + Host journey (Nov 14, 2026). NOT APPLIED: the owner applies it.
-- One row per user and side: the tenant's ranked search priorities, or the
-- host's preferred tenant profile. The app works without this table: both
-- are kept on the device and the older priority_rank order is still written.
-- No phone numbers or email addresses are stored here.

create table if not exists public.priority_preferences (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  side text not null check (side in ('tenant', 'host')),
  ranked text[] not null check (cardinality(ranked) between 1 and 8),
  must_have text[] not null default '{}',
  order_all text[] not null default '{}' check (cardinality(order_all) <= 8),
  prefs jsonb not null default '{}'::jsonb check (jsonb_typeof(prefs) = 'object'),
  updated_at timestamptz not null default now(),
  primary key (user_id, side),
  constraint priority_preferences_wires check (
    (side = 'tenant'
      and ranked <@ array['budget', 'occupancy', 'location', 'move_in', 'gender',
        'property_type', 'lifestyle', 'furnishing']::text[]
      and must_have <@ ranked
      and order_all <@ array['budget', 'occupancy', 'location', 'move_in', 'gender',
        'property_type', 'lifestyle', 'furnishing']::text[])
    or (side = 'host'
      and ranked <@ array['budget', 'move_in', 'working_professional', 'vegetarian',
        'gender_age', 'non_smoker', 'non_drinker', 'long_stay']::text[]
      and must_have <@ ranked
      and order_all <@ array['budget', 'move_in', 'working_professional', 'vegetarian',
        'gender_age', 'non_smoker', 'non_drinker', 'long_stay']::text[])
  ),
  constraint priority_preferences_no_contact check (
    (prefs - 'property_id')::text !~ '@'
    and (prefs - 'property_id')::text !~ '[0-9]{10}'
  )
);

alter table public.priority_preferences enable row level security;

drop policy if exists priority_preferences_own_read on public.priority_preferences;
create policy priority_preferences_own_read on public.priority_preferences
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists priority_preferences_own_insert on public.priority_preferences;
create policy priority_preferences_own_insert on public.priority_preferences
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists priority_preferences_own_update on public.priority_preferences;
create policy priority_preferences_own_update on public.priority_preferences
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists priority_preferences_own_delete on public.priority_preferences;
create policy priority_preferences_own_delete on public.priority_preferences
  for delete to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.priority_preferences_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists priority_preferences_touch on public.priority_preferences;
create trigger priority_preferences_touch
  before update on public.priority_preferences
  for each row execute function public.priority_preferences_touch();

revoke all on public.priority_preferences from anon;
grant select, insert, update, delete on public.priority_preferences to authenticated;
grant all on public.priority_preferences to service_role;
