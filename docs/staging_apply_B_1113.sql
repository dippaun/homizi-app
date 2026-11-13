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
  '20261113120000',
  'profile_details',
  array['docs/staging_apply_B_1113.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
