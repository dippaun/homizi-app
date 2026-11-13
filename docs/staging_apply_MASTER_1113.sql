-- HOMIZI master paste for 13 Nov 2026. Paste this whole file once.
-- Order: priorities, profile details, office locations.
-- Each section uses IF NOT EXISTS, DROP POLICY IF EXISTS, or ON CONFLICT,
-- so running it again is safe. Do not apply it from the app or from CI.
-- No service role key, secret, phone, email, Aadhaar, or selfie is here.

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


-- Public profile-wizard answers. Legal name, date of birth, phone, email,
-- Aadhaar, and the selfie are not stored here.
-- Paste docs/staging_apply_B_1113.sql in the staging SQL editor. Do not apply
-- this from the app. The wizard keeps a device copy until this is pasted.

create table if not exists public.profile_details (
  user_id uuid primary key references public.users (id) on delete cascade,
  roles text[] not null default '{}',
  surname text,
  languages text[] not null default '{}',
  smoking text,
  drinking text,
  food text,
  cooking text,
  cleaning text,
  pets text,
  city text,
  company_name text,
  about text,
  tags text[] not null default '{}',
  documents text[] not null default '{}',
  budget_min_inr integer,
  budget_max_inr integer,
  localities text[] not null default '{}',
  looking_for text[] not null default '{}',
  move_in_label text,
  terms_accepted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profile_details_roles check (
    roles <@ array['tenant', 'host', 'partner', 'sharer']::text[]
  ),
  constraint profile_details_surname check (
    surname is null or char_length(surname) between 2 and 80
  ),
  constraint profile_details_about check (
    about is null or char_length(about) <= 500
  ),
  constraint profile_details_city check (
    city is null or char_length(city) <= 80
  ),
  constraint profile_details_company check (
    company_name is null or char_length(company_name) <= 120
  ),
  constraint profile_details_smoking check (
    smoking is null
    or smoking in ('Yes', 'No', 'Occasional', 'Prefer not to say')
  ),
  constraint profile_details_drinking check (
    drinking is null
    or drinking in ('Yes', 'No', 'Occasional', 'Prefer not to say')
  ),
  constraint profile_details_food check (
    food is null or food in ('Veg', 'Non-Veg', 'Both', 'Prefer not to say')
  ),
  constraint profile_details_cooking check (
    cooking is null
    or cooking in (
      'Cook myself',
      'Shared cooking',
      'Prefer to hire a cook'
    )
  ),
  constraint profile_details_cleaning check (
    cleaning is null
    or cleaning in (
      'Myself',
      'Shared cleaning',
      'Prefer to hire a house help'
    )
  ),
  constraint profile_details_pets check (
    pets is null or pets in ('Allowed', 'Not Allowed', 'Prefer not to say')
  ),
  constraint profile_details_budget check (
    budget_min_inr is null
    or budget_max_inr is null
    or budget_min_inr <= budget_max_inr
  )
);

alter table public.profile_details enable row level security;

drop policy if exists profile_details_self on public.profile_details;
create policy profile_details_self on public.profile_details
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.profile_details to authenticated;

-- Records the paste so a later migration run does not apply it twice.
insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261113121000',
  'profile_details',
  array['docs/staging_apply_B_1113.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


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
