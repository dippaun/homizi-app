-- HOMIZI Set My Priorities. Paste this whole file into the dashboard SQL editor.
-- Running it again is safe. Do not apply it from the app or from CI.
-- The ranking stays on the device until this table exists.
-- No service role key, secret, phone, or email is here.

-- Saved Set My Priorities ranks. Not applied to staging from the app.
-- Paste docs/staging_apply_PRIORITIES_1113.sql in the SQL editor when ready.
-- No phone, email, secret, or password is stored here.

reset role;

do $$
begin
  if to_regclass('public.users') is null then
    raise exception 'Apply the earlier HOMIZI staging SQL before this file.';
  end if;
end $$;

create table if not exists public.priority_rank (
  user_id uuid not null references public.users (id) on delete cascade,
  side text not null,
  factor_key text not null,
  rank integer not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, side, factor_key)
);

do $priority_rank_checks$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'priority_rank_side'
  ) then
    alter table public.priority_rank
      add constraint priority_rank_side
      check (side in ('tenant', 'host'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'priority_rank_rank'
  ) then
    alter table public.priority_rank
      add constraint priority_rank_rank
      check (rank between 1 and 9);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'priority_rank_factor_key'
  ) then
    alter table public.priority_rank
      add constraint priority_rank_factor_key
      check (factor_key in (
        'budget',
        'location',
        'occupancy',
        'property_type',
        'gender',
        'lifestyle',
        'furnishing',
        'bathroom',
        'amenities',
        'tenant_profile',
        'lease',
        'rules'
      ));
  end if;
end
$priority_rank_checks$;

create unique index if not exists priority_rank_rank_uidx
  on public.priority_rank (user_id, side, rank);

comment on table public.priority_rank is
  'Set My Priorities order. Rank 1 is highest. Tenant covers flatmates. Host covers owners and property partners.';

alter table public.priority_rank enable row level security;

drop policy if exists priority_rank_all on public.priority_rank;
create policy priority_rank_all on public.priority_rank
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.priority_rank from public, anon;
grant select, insert, update, delete on public.priority_rank to authenticated;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261113120000',
  'priority_order',
  array['docs/staging_apply_PRIORITIES_1113.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
