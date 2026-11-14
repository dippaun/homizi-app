-- Rent Split (Nov 14, 2026). NOT APPLIED: the owner applies it.
-- Finished rent splits a person saved. The app keeps a device copy and
-- works without this table; when it exists, the split is also saved here.
-- Only first names and rupee amounts. No phone, email, or ID numbers.

create table if not exists public.rent_splits (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_label text not null check (char_length(btrim(property_label)) between 1 and 40),
  locality text not null check (char_length(btrim(locality)) between 2 and 160),
  total_rent_inr integer not null check (total_rent_inr between 1 and 10000000),
  bills_inr integer not null default 0 check (bills_inr between 0 and 10000000),
  mode text not null check (mode in ('smart', 'equal', 'custom')),
  rooms jsonb not null default '[]'::jsonb check (jsonb_typeof(rooms) = 'array'),
  shares jsonb not null check (jsonb_typeof(shares) = 'array' and jsonb_array_length(shares) between 1 and 18),
  agreed jsonb not null default '[]'::jsonb check (jsonb_typeof(agreed) = 'array'),
  finalized_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint rent_splits_no_contact check (
    (rooms::text || shares::text || agreed::text || locality) !~ '@'
    and (rooms::text || shares::text || agreed::text || locality) !~ '[0-9]{10}'
  )
);

create index if not exists rent_splits_owner_idx
  on public.rent_splits (owner_id, finalized_at desc);

alter table public.rent_splits enable row level security;

drop policy if exists rent_splits_select_own on public.rent_splits;
create policy rent_splits_select_own on public.rent_splits
  for select to authenticated
  using (auth.uid() = owner_id);

drop policy if exists rent_splits_insert_own on public.rent_splits;
create policy rent_splits_insert_own on public.rent_splits
  for insert to authenticated
  with check (auth.uid() = owner_id);

drop policy if exists rent_splits_delete_own on public.rent_splits;
create policy rent_splits_delete_own on public.rent_splits
  for delete to authenticated
  using (auth.uid() = owner_id);

revoke all on public.rent_splits from anon;
grant select, insert, delete on public.rent_splits to authenticated;
grant all on public.rent_splits to service_role;
