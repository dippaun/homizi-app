-- Office locations for a signed-in person.
-- Unapplied. Paste docs/staging_apply_OFFICE_1113.sql in the SQL editor.
-- The app keeps a device copy until this table exists.
-- No phone, email, or door number. The label is the place the person typed.

create table if not exists public.office_locations (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  label text not null check (char_length(btrim(label)) between 2 and 160),
  place_id text,
  latitude double precision,
  longitude double precision,
  transport_mode text not null check (
    transport_mode in ('car', 'two_wheeler', 'public_transport', 'walk')
  ),
  max_commute_minutes integer not null check (
    max_commute_minutes in (15, 30, 45, 60)
  ),
  is_primary boolean not null default false,
  nearby_notes text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.office_locations enable row level security;

drop policy if exists office_locations_own on public.office_locations;
create policy office_locations_own
  on public.office_locations
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create unique index if not exists office_locations_one_primary
  on public.office_locations (user_id)
  where is_primary;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261113130000',
  'office_locations',
  array['docs/staging_apply_OFFICE_1113.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
