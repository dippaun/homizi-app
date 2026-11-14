-- Property partner applications (Nov 14, 2026). NOT APPLIED: the owner applies it.
-- One application per signed-in user. The app stores the same record on the
-- device and only writes here when this table already exists. Document files
-- stay in the existing private listing-photos bucket. This file does not
-- create a bucket and does not store PAN or Aadhaar numbers.

create table if not exists public.property_partner_applications (
  user_id uuid primary key references auth.users (id) on delete cascade,
  application_code text not null check (
    application_code ~ '^PP[0-9]{8}-[0-9]{4}$'
  ),
  partner_type text not null check (
    partner_type in ('individual', 'builder', 'agency')
  ),
  full_name text not null check (char_length(btrim(full_name)) between 2 and 80),
  mobile text not null default '',
  email text not null default '',
  business_name text not null default '',
  address text not null default '',
  operating_areas text not null default '',
  about text not null default '' check (char_length(about) <= 500),
  verify_later boolean not null default true,
  pan_path text not null default '',
  aadhaar_path text not null default '',
  ownership_path text not null default '',
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now()
);

alter table public.property_partner_applications enable row level security;

drop policy if exists partner_applications_select_own
  on public.property_partner_applications;
create policy partner_applications_select_own
  on public.property_partner_applications
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists partner_applications_insert_own
  on public.property_partner_applications;
create policy partner_applications_insert_own
  on public.property_partner_applications
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists partner_applications_update_own
  on public.property_partner_applications;
create policy partner_applications_update_own
  on public.property_partner_applications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.property_partner_applications from anon, public;
grant select, insert, update on public.property_partner_applications to authenticated;
grant all on public.property_partner_applications to service_role;
