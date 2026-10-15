-- HOMIZI staging schema for a fresh hosted Supabase project.
-- Paste this whole file into the dashboard SQL editor (one run).
--
-- It applies every file in supabase/migrations, in filename order.
-- It creates the private listing-photos bucket and its policies.
-- It records each version in supabase_migrations.schema_migrations so a
-- later `supabase db push` treats those files as already applied.
--
-- supabase/seed.sql is not included. No demo users are inserted.
-- Re-running this file is safe: tables, types, and indexes are created
-- only when missing, policies and triggers are replaced, and version rows
-- are upserted.
--
-- Hosted Supabase rejects a few superuser steps. Those are attempted and
-- skipped with a notice instead of aborting the script:
--   * create extension pgcrypto, when the platform already owns it
--   * grant execute on auth.uid()
--   * the trigger on auth.users
--   * storage policies, when this role does not own storage.objects
-- The listing-photos bucket insert is kept even if the policies are skipped.

create schema if not exists supabase_migrations;

create table if not exists supabase_migrations.schema_migrations (
  version text not null primary key
);

alter table supabase_migrations.schema_migrations
  add column if not exists statements text[];

alter table supabase_migrations.schema_migrations
  add column if not exists name text;

-- -------------------------------------------------------------------------
-- 20261011120000_homizi_schema.sql
-- -------------------------------------------------------------------------

do $homizi_ext$
begin
  -- HOMIZI foundation schema.
-- Contact fields live only in private_contacts. No Aadhaar or payment card columns.
-- Payments tables are deferred placeholders: clients cannot write them.

create extension if not exists pgcrypto with schema extensions;
exception
  when insufficient_privilege or duplicate_object then
    raise notice 'pgcrypto skipped: %', sqlerrm;
end
$homizi_ext$;

do $homizi_type$
begin
  -- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.user_status as enum ('active', 'suspended', 'deleted');
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.primary_role as enum ('unset', 'tenant', 'host', 'both');
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.verification_status as enum (
  'not_started',
  'mock_pending',
  'mock_verified',
  'rejected'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.host_category as enum (
  'owner',
  'broker',
  'company',
  'flatmate',
  'other'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.property_type as enum (
  'apartment',
  'independent_house',
  'villa',
  'pg',
  'studio',
  'shared_room',
  'private_room'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.furnishing as enum (
  'unfurnished',
  'semi_furnished',
  'furnished'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.listing_status as enum (
  'draft',
  'published',
  'paused',
  'removed',
  'expired'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.address_visibility as enum (
  'locality_only',
  'after_match',
  'after_visit_accept'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.photo_type as enum (
  'exterior',
  'living',
  'bedroom',
  'kitchen',
  'bathroom',
  'other'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.moderation_status as enum ('pending', 'approved', 'rejected');
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.interest_target_type as enum (
  'property',
  'listing_requirement',
  'user'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.interest_action as enum ('like', 'pass', 'save');
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.match_status as enum ('active', 'unmatched', 'blocked');
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.contact_scope as enum ('phone', 'email', 'phone_and_email');
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.conversation_status as enum ('open', 'closed');
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.message_status as enum ('sent', 'hidden');
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.visit_status as enum (
  'requested',
  'accepted',
  'declined',
  'rescheduled',
  'cancelled',
  'completed'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.report_target_type as enum (
  'user',
  'property',
  'listing_requirement',
  'message'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.report_reason as enum (
  'spam',
  'harassment',
  'scam',
  'fake_listing',
  'inappropriate',
  'other'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.report_status as enum (
  'open',
  'reviewing',
  'resolved',
  'dismissed'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.subscription_status as enum (
  'inactive',
  'active',
  'expired',
  'cancelled'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.payment_status as enum (
  'pending',
  'succeeded',
  'failed',
  'refunded'
);
exception
  when duplicate_object then
    null;
end
$homizi_type$;

do $homizi_type$
begin
  create type public.consent_policy_type as enum ('terms', 'privacy');
exception
  when duplicate_object then
    null;
end
$homizi_type$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status public.user_status not null default 'active',
  primary_role public.primary_role not null default 'unset'
);

create table if not exists public.profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  display_name text not null default '',
  occupation text,
  public_bio text,
  avatar_path text,
  verification_status public.verification_status not null default 'not_started',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_len check (char_length(display_name) <= 80),
  constraint profiles_bio_len check (public_bio is null or char_length(public_bio) <= 500)
);

comment on column public.profiles.verification_status is
  'Mock states only. Do not store Aadhaar, passport, or biometric data.';

create table if not exists public.private_contacts (
  user_id uuid primary key references public.users (id) on delete cascade,
  email text,
  phone text,
  date_of_birth date,
  updated_at timestamptz not null default now(),
  constraint private_contacts_email check (
    email is null or email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  ),
  constraint private_contacts_phone check (
    phone is null or phone ~ '^\+[0-9]{8,15}$'
  )
);

comment on table public.private_contacts is
  'Owner-only. Other users receive these fields only from get_contact_visibility.';

create table if not exists public.host_profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  host_category public.host_category not null,
  company_name text,
  company_details text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint host_profiles_company_len check (
    company_name is null or char_length(company_name) <= 120
  )
);

create table if not exists public.tenant_preferences (
  user_id uuid primary key references public.users (id) on delete cascade,
  budget_min_inr integer check (budget_min_inr is null or budget_min_inr >= 0),
  budget_max_inr integer,
  move_in_date date,
  localities text[] not null default '{}',
  occupancy smallint not null default 1,
  property_types public.property_type[] not null default '{}',
  lifestyle text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tenant_preferences_budget check (
    budget_min_inr is null
    or budget_max_inr is null
    or budget_min_inr <= budget_max_inr
  ),
  constraint tenant_preferences_occupancy check (occupancy between 1 and 20),
  constraint tenant_preferences_lifestyle check (
    lifestyle <@ array[
      'pets_ok',
      'non_smoker',
      'early_riser',
      'night_owl',
      'wfh'
    ]::text[]
  )
);

comment on table public.tenant_preferences is
  'Private matching inputs. Scoring must not use gender, religion, caste, or age.';

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  host_user_id uuid not null references public.users (id),
  title text not null,
  locality text not null,
  city text not null,
  address_visibility public.address_visibility not null default 'locality_only',
  property_type public.property_type not null,
  furnishing public.furnishing not null,
  rent_inr integer not null,
  deposit_inr integer not null default 0,
  brokerage_inr integer not null default 0,
  maintenance_inr integer not null default 0,
  status public.listing_status not null default 'draft',
  occupancy_max smallint not null default 1,
  available_from date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  constraint properties_title_len check (char_length(title) between 3 and 120),
  constraint properties_rent check (rent_inr >= 0 and rent_inr <= 10000000),
  constraint properties_deposit check (deposit_inr >= 0),
  constraint properties_brokerage check (brokerage_inr >= 0),
  constraint properties_maintenance check (maintenance_inr >= 0),
  constraint properties_occupancy check (occupancy_max between 1 and 20)
);

comment on table public.properties is
  'Street address is not stored here. See property_private_details.';

create table if not exists public.property_private_details (
  property_id uuid primary key references public.properties (id) on delete cascade,
  address_line text,
  landmark text,
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  updated_at timestamptz not null default now()
);

create table if not exists public.property_features (
  property_id uuid not null references public.properties (id) on delete cascade,
  feature_key text not null,
  value text not null,
  primary key (property_id, feature_key),
  constraint property_features_key_len check (char_length(feature_key) between 1 and 40)
);

create table if not exists public.property_photos (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  storage_path text not null,
  sort_order integer not null,
  photo_type public.photo_type not null default 'other',
  moderation_status public.moderation_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, sort_order),
  constraint property_photos_sort check (sort_order >= 0)
);

create table if not exists public.listing_requirements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  city text not null,
  localities text[] not null default '{}',
  budget_min_inr integer not null,
  budget_max_inr integer not null,
  move_in_date date,
  occupancy smallint not null default 1,
  property_types public.property_type[] not null default '{}',
  furnishing public.furnishing,
  lifestyle text[] not null default '{}',
  status public.listing_status not null default 'draft',
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint listing_requirements_budget check (
    budget_min_inr >= 0 and budget_min_inr <= budget_max_inr
  ),
  constraint listing_requirements_occupancy check (occupancy between 1 and 20),
  constraint listing_requirements_lifestyle check (
    lifestyle <@ array[
      'pets_ok',
      'non_smoker',
      'early_riser',
      'night_owl',
      'wfh'
    ]::text[]
  )
);

create table if not exists public.interests (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null references public.users (id) on delete cascade,
  target_type public.interest_target_type not null,
  target_id uuid not null,
  action public.interest_action not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (actor_user_id, target_type, target_id, action)
);

create unique index if not exists interests_one_stance
  on public.interests (actor_user_id, target_type, target_id)
  where action in ('like', 'pass');

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  participant_a uuid not null references public.users (id),
  participant_b uuid not null references public.users (id),
  status public.match_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint matches_ordered check (participant_a < participant_b),
  constraint matches_distinct check (participant_a <> participant_b),
  unique (participant_a, participant_b)
);

create table if not exists public.contact_consents (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  granted_by uuid not null references public.users (id),
  scope public.contact_scope not null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (match_id, granted_by)
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references public.matches (id) on delete cascade,
  status public.conversation_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.users (id),
  body text not null,
  status public.message_status not null default 'sent',
  created_at timestamptz not null default now(),
  constraint messages_body_len check (char_length(body) between 1 and 4000)
);

create table if not exists public.visit_requests (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  requester_id uuid not null references public.users (id),
  proposed_slots jsonb not null default '[]'::jsonb,
  status public.visit_status not null default 'requested',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  type text not null,
  payload_minimal jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint notifications_payload check (
    not (
      payload_minimal ? 'phone'
      or payload_minimal ? 'email'
      or payload_minimal ? 'aadhaar'
    )
  )
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id),
  target_type public.report_target_type not null,
  target_id uuid not null,
  reason public.report_reason not null,
  details text,
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  constraint reports_details_len check (details is null or char_length(details) <= 1000)
);

create table if not exists public.blocks (
  blocker_id uuid not null references public.users (id) on delete cascade,
  blocked_user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id),
  constraint blocks_no_self check (blocker_id <> blocked_user_id)
);

create table if not exists public.staff_roles (
  user_id uuid primary key references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  plan_code text not null,
  status public.subscription_status not null default 'inactive',
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.subscriptions is
  'Deferred. Clients may read their own row. Only a future server webhook may write it.';

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  provider_ref text,
  amount_inr integer not null check (amount_inr >= 0),
  currency text not null default 'INR' check (currency = 'INR'),
  status public.payment_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.payments is
  'Deferred. No card data. No client writes. Webhook reconciliation is not implemented.';

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  action text not null,
  target text,
  metadata_minimal jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint audit_events_metadata check (
    not (
      metadata_minimal ? 'phone'
      or metadata_minimal ? 'email'
      or metadata_minimal ? 'aadhaar'
    )
  )
);

create table if not exists public.consent_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  policy_type public.consent_policy_type not null,
  policy_version text not null,
  accepted_at timestamptz not null default now(),
  revoked_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index if not exists users_status_idx on public.users (status);

create index if not exists properties_host_idx on public.properties (host_user_id);

create index if not exists properties_discovery_idx
  on public.properties (status, city, locality);

create index if not exists properties_rent_idx
  on public.properties (rent_inr)
  where status = 'published';

create index if not exists property_photos_property_idx on public.property_photos (property_id);

create index if not exists listing_requirements_owner_idx
  on public.listing_requirements (user_id, status);

create index if not exists interests_actor_idx on public.interests (actor_user_id, created_at desc);

create index if not exists interests_target_idx on public.interests (target_type, target_id);

create index if not exists matches_participant_a_idx on public.matches (participant_a);

create index if not exists matches_participant_b_idx on public.matches (participant_b);

create index if not exists blocks_blocked_idx on public.blocks (blocked_user_id);

create index if not exists reports_status_idx on public.reports (status, created_at);

create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

create index if not exists messages_conversation_idx
  on public.messages (conversation_id, created_at);

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists private_contacts_set_updated_at on public.private_contacts;
create trigger private_contacts_set_updated_at
  before update on public.private_contacts
  for each row execute function public.set_updated_at();

drop trigger if exists host_profiles_set_updated_at on public.host_profiles;
create trigger host_profiles_set_updated_at
  before update on public.host_profiles
  for each row execute function public.set_updated_at();

drop trigger if exists tenant_preferences_set_updated_at on public.tenant_preferences;
create trigger tenant_preferences_set_updated_at
  before update on public.tenant_preferences
  for each row execute function public.set_updated_at();

drop trigger if exists properties_set_updated_at on public.properties;
create trigger properties_set_updated_at
  before update on public.properties
  for each row execute function public.set_updated_at();

drop trigger if exists property_private_details_set_updated_at on public.property_private_details;
create trigger property_private_details_set_updated_at
  before update on public.property_private_details
  for each row execute function public.set_updated_at();

drop trigger if exists property_photos_set_updated_at on public.property_photos;
create trigger property_photos_set_updated_at
  before update on public.property_photos
  for each row execute function public.set_updated_at();

drop trigger if exists listing_requirements_set_updated_at on public.listing_requirements;
create trigger listing_requirements_set_updated_at
  before update on public.listing_requirements
  for each row execute function public.set_updated_at();

drop trigger if exists interests_set_updated_at on public.interests;
create trigger interests_set_updated_at
  before update on public.interests
  for each row execute function public.set_updated_at();

drop trigger if exists matches_set_updated_at on public.matches;
create trigger matches_set_updated_at
  before update on public.matches
  for each row execute function public.set_updated_at();

drop trigger if exists conversations_set_updated_at on public.conversations;
create trigger conversations_set_updated_at
  before update on public.conversations
  for each row execute function public.set_updated_at();

drop trigger if exists visit_requests_set_updated_at on public.visit_requests;
create trigger visit_requests_set_updated_at
  before update on public.visit_requests
  for each row execute function public.set_updated_at();

drop trigger if exists subscriptions_set_updated_at on public.subscriptions;
create trigger subscriptions_set_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- New auth user -> app rows. Email is copied; phone is filled by the owner later.
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id) values (new.id) on conflict do nothing;
  insert into public.profiles (user_id) values (new.id) on conflict do nothing;
  insert into public.private_contacts (user_id, email)
  values (new.id, new.email)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

do $homizi_auth_trigger$
begin
  drop trigger if exists on_auth_user_created on auth.users;
  create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
exception
  when insufficient_privilege then
    raise notice 'auth.users trigger skipped: %', sqlerrm;
end
$homizi_auth_trigger$;



insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261011120000',
  'homizi_schema',
  array[
    $homizi_20261011120000_1$-- HOMIZI foundation schema.
-- Contact fields live only in private_contacts. No Aadhaar or payment card columns.
-- Payments tables are deferred placeholders: clients cannot write them.

create extension if not exists pgcrypto with schema extensions;$homizi_20261011120000_1$,
    $homizi_20261011120000_2$-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.user_status as enum ('active', 'suspended', 'deleted');$homizi_20261011120000_2$,
    $homizi_20261011120000_3$create type public.primary_role as enum ('unset', 'tenant', 'host', 'both');$homizi_20261011120000_3$,
    $homizi_20261011120000_4$create type public.verification_status as enum (
  'not_started',
  'mock_pending',
  'mock_verified',
  'rejected'
);$homizi_20261011120000_4$,
    $homizi_20261011120000_5$create type public.host_category as enum (
  'owner',
  'broker',
  'company',
  'flatmate',
  'other'
);$homizi_20261011120000_5$,
    $homizi_20261011120000_6$create type public.property_type as enum (
  'apartment',
  'independent_house',
  'villa',
  'pg',
  'studio',
  'shared_room',
  'private_room'
);$homizi_20261011120000_6$,
    $homizi_20261011120000_7$create type public.furnishing as enum (
  'unfurnished',
  'semi_furnished',
  'furnished'
);$homizi_20261011120000_7$,
    $homizi_20261011120000_8$create type public.listing_status as enum (
  'draft',
  'published',
  'paused',
  'removed',
  'expired'
);$homizi_20261011120000_8$,
    $homizi_20261011120000_9$create type public.address_visibility as enum (
  'locality_only',
  'after_match',
  'after_visit_accept'
);$homizi_20261011120000_9$,
    $homizi_20261011120000_10$create type public.photo_type as enum (
  'exterior',
  'living',
  'bedroom',
  'kitchen',
  'bathroom',
  'other'
);$homizi_20261011120000_10$,
    $homizi_20261011120000_11$create type public.moderation_status as enum ('pending', 'approved', 'rejected');$homizi_20261011120000_11$,
    $homizi_20261011120000_12$create type public.interest_target_type as enum (
  'property',
  'listing_requirement',
  'user'
);$homizi_20261011120000_12$,
    $homizi_20261011120000_13$create type public.interest_action as enum ('like', 'pass', 'save');$homizi_20261011120000_13$,
    $homizi_20261011120000_14$create type public.match_status as enum ('active', 'unmatched', 'blocked');$homizi_20261011120000_14$,
    $homizi_20261011120000_15$create type public.contact_scope as enum ('phone', 'email', 'phone_and_email');$homizi_20261011120000_15$,
    $homizi_20261011120000_16$create type public.conversation_status as enum ('open', 'closed');$homizi_20261011120000_16$,
    $homizi_20261011120000_17$create type public.message_status as enum ('sent', 'hidden');$homizi_20261011120000_17$,
    $homizi_20261011120000_18$create type public.visit_status as enum (
  'requested',
  'accepted',
  'declined',
  'rescheduled',
  'cancelled',
  'completed'
);$homizi_20261011120000_18$,
    $homizi_20261011120000_19$create type public.report_target_type as enum (
  'user',
  'property',
  'listing_requirement',
  'message'
);$homizi_20261011120000_19$,
    $homizi_20261011120000_20$create type public.report_reason as enum (
  'spam',
  'harassment',
  'scam',
  'fake_listing',
  'inappropriate',
  'other'
);$homizi_20261011120000_20$,
    $homizi_20261011120000_21$create type public.report_status as enum (
  'open',
  'reviewing',
  'resolved',
  'dismissed'
);$homizi_20261011120000_21$,
    $homizi_20261011120000_22$create type public.subscription_status as enum (
  'inactive',
  'active',
  'expired',
  'cancelled'
);$homizi_20261011120000_22$,
    $homizi_20261011120000_23$create type public.payment_status as enum (
  'pending',
  'succeeded',
  'failed',
  'refunded'
);$homizi_20261011120000_23$,
    $homizi_20261011120000_24$create type public.consent_policy_type as enum ('terms', 'privacy');$homizi_20261011120000_24$,
    $homizi_20261011120000_25$-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status public.user_status not null default 'active',
  primary_role public.primary_role not null default 'unset'
);$homizi_20261011120000_25$,
    $homizi_20261011120000_26$create table public.profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  display_name text not null default '',
  occupation text,
  public_bio text,
  avatar_path text,
  verification_status public.verification_status not null default 'not_started',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_len check (char_length(display_name) <= 80),
  constraint profiles_bio_len check (public_bio is null or char_length(public_bio) <= 500)
);$homizi_20261011120000_26$,
    $homizi_20261011120000_27$comment on column public.profiles.verification_status is
  'Mock states only. Do not store Aadhaar, passport, or biometric data.';$homizi_20261011120000_27$,
    $homizi_20261011120000_28$create table public.private_contacts (
  user_id uuid primary key references public.users (id) on delete cascade,
  email text,
  phone text,
  date_of_birth date,
  updated_at timestamptz not null default now(),
  constraint private_contacts_email check (
    email is null or email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  ),
  constraint private_contacts_phone check (
    phone is null or phone ~ '^\+[0-9]{8,15}$'
  )
);$homizi_20261011120000_28$,
    $homizi_20261011120000_29$comment on table public.private_contacts is
  'Owner-only. Other users receive these fields only from get_contact_visibility.';$homizi_20261011120000_29$,
    $homizi_20261011120000_30$create table public.host_profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  host_category public.host_category not null,
  company_name text,
  company_details text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint host_profiles_company_len check (
    company_name is null or char_length(company_name) <= 120
  )
);$homizi_20261011120000_30$,
    $homizi_20261011120000_31$create table public.tenant_preferences (
  user_id uuid primary key references public.users (id) on delete cascade,
  budget_min_inr integer check (budget_min_inr is null or budget_min_inr >= 0),
  budget_max_inr integer,
  move_in_date date,
  localities text[] not null default '{}',
  occupancy smallint not null default 1,
  property_types public.property_type[] not null default '{}',
  lifestyle text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tenant_preferences_budget check (
    budget_min_inr is null
    or budget_max_inr is null
    or budget_min_inr <= budget_max_inr
  ),
  constraint tenant_preferences_occupancy check (occupancy between 1 and 20),
  constraint tenant_preferences_lifestyle check (
    lifestyle <@ array[
      'pets_ok',
      'non_smoker',
      'early_riser',
      'night_owl',
      'wfh'
    ]::text[]
  )
);$homizi_20261011120000_31$,
    $homizi_20261011120000_32$comment on table public.tenant_preferences is
  'Private matching inputs. Scoring must not use gender, religion, caste, or age.';$homizi_20261011120000_32$,
    $homizi_20261011120000_33$create table public.properties (
  id uuid primary key default gen_random_uuid(),
  host_user_id uuid not null references public.users (id),
  title text not null,
  locality text not null,
  city text not null,
  address_visibility public.address_visibility not null default 'locality_only',
  property_type public.property_type not null,
  furnishing public.furnishing not null,
  rent_inr integer not null,
  deposit_inr integer not null default 0,
  brokerage_inr integer not null default 0,
  maintenance_inr integer not null default 0,
  status public.listing_status not null default 'draft',
  occupancy_max smallint not null default 1,
  available_from date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  constraint properties_title_len check (char_length(title) between 3 and 120),
  constraint properties_rent check (rent_inr >= 0 and rent_inr <= 10000000),
  constraint properties_deposit check (deposit_inr >= 0),
  constraint properties_brokerage check (brokerage_inr >= 0),
  constraint properties_maintenance check (maintenance_inr >= 0),
  constraint properties_occupancy check (occupancy_max between 1 and 20)
);$homizi_20261011120000_33$,
    $homizi_20261011120000_34$comment on table public.properties is
  'Street address is not stored here. See property_private_details.';$homizi_20261011120000_34$,
    $homizi_20261011120000_35$create table public.property_private_details (
  property_id uuid primary key references public.properties (id) on delete cascade,
  address_line text,
  landmark text,
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  updated_at timestamptz not null default now()
);$homizi_20261011120000_35$,
    $homizi_20261011120000_36$create table public.property_features (
  property_id uuid not null references public.properties (id) on delete cascade,
  feature_key text not null,
  value text not null,
  primary key (property_id, feature_key),
  constraint property_features_key_len check (char_length(feature_key) between 1 and 40)
);$homizi_20261011120000_36$,
    $homizi_20261011120000_37$create table public.property_photos (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  storage_path text not null,
  sort_order integer not null,
  photo_type public.photo_type not null default 'other',
  moderation_status public.moderation_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, sort_order),
  constraint property_photos_sort check (sort_order >= 0)
);$homizi_20261011120000_37$,
    $homizi_20261011120000_38$create table public.listing_requirements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  city text not null,
  localities text[] not null default '{}',
  budget_min_inr integer not null,
  budget_max_inr integer not null,
  move_in_date date,
  occupancy smallint not null default 1,
  property_types public.property_type[] not null default '{}',
  furnishing public.furnishing,
  lifestyle text[] not null default '{}',
  status public.listing_status not null default 'draft',
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint listing_requirements_budget check (
    budget_min_inr >= 0 and budget_min_inr <= budget_max_inr
  ),
  constraint listing_requirements_occupancy check (occupancy between 1 and 20),
  constraint listing_requirements_lifestyle check (
    lifestyle <@ array[
      'pets_ok',
      'non_smoker',
      'early_riser',
      'night_owl',
      'wfh'
    ]::text[]
  )
);$homizi_20261011120000_38$,
    $homizi_20261011120000_39$create table public.interests (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null references public.users (id) on delete cascade,
  target_type public.interest_target_type not null,
  target_id uuid not null,
  action public.interest_action not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (actor_user_id, target_type, target_id, action)
);$homizi_20261011120000_39$,
    $homizi_20261011120000_40$create unique index interests_one_stance
  on public.interests (actor_user_id, target_type, target_id)
  where action in ('like', 'pass');$homizi_20261011120000_40$,
    $homizi_20261011120000_41$create table public.matches (
  id uuid primary key default gen_random_uuid(),
  participant_a uuid not null references public.users (id),
  participant_b uuid not null references public.users (id),
  status public.match_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint matches_ordered check (participant_a < participant_b),
  constraint matches_distinct check (participant_a <> participant_b),
  unique (participant_a, participant_b)
);$homizi_20261011120000_41$,
    $homizi_20261011120000_42$create table public.contact_consents (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  granted_by uuid not null references public.users (id),
  scope public.contact_scope not null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (match_id, granted_by)
);$homizi_20261011120000_42$,
    $homizi_20261011120000_43$create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references public.matches (id) on delete cascade,
  status public.conversation_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);$homizi_20261011120000_43$,
    $homizi_20261011120000_44$create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.users (id),
  body text not null,
  status public.message_status not null default 'sent',
  created_at timestamptz not null default now(),
  constraint messages_body_len check (char_length(body) between 1 and 4000)
);$homizi_20261011120000_44$,
    $homizi_20261011120000_45$create table public.visit_requests (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  requester_id uuid not null references public.users (id),
  proposed_slots jsonb not null default '[]'::jsonb,
  status public.visit_status not null default 'requested',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);$homizi_20261011120000_45$,
    $homizi_20261011120000_46$create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  type text not null,
  payload_minimal jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint notifications_payload check (
    not (
      payload_minimal ? 'phone'
      or payload_minimal ? 'email'
      or payload_minimal ? 'aadhaar'
    )
  )
);$homizi_20261011120000_46$,
    $homizi_20261011120000_47$create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id),
  target_type public.report_target_type not null,
  target_id uuid not null,
  reason public.report_reason not null,
  details text,
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  constraint reports_details_len check (details is null or char_length(details) <= 1000)
);$homizi_20261011120000_47$,
    $homizi_20261011120000_48$create table public.blocks (
  blocker_id uuid not null references public.users (id) on delete cascade,
  blocked_user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id),
  constraint blocks_no_self check (blocker_id <> blocked_user_id)
);$homizi_20261011120000_48$,
    $homizi_20261011120000_49$create table public.staff_roles (
  user_id uuid primary key references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);$homizi_20261011120000_49$,
    $homizi_20261011120000_50$create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  plan_code text not null,
  status public.subscription_status not null default 'inactive',
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);$homizi_20261011120000_50$,
    $homizi_20261011120000_51$comment on table public.subscriptions is
  'Deferred. Clients may read their own row. Only a future server webhook may write it.';$homizi_20261011120000_51$,
    $homizi_20261011120000_52$create table public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  provider_ref text,
  amount_inr integer not null check (amount_inr >= 0),
  currency text not null default 'INR' check (currency = 'INR'),
  status public.payment_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);$homizi_20261011120000_52$,
    $homizi_20261011120000_53$comment on table public.payments is
  'Deferred. No card data. No client writes. Webhook reconciliation is not implemented.';$homizi_20261011120000_53$,
    $homizi_20261011120000_54$create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  action text not null,
  target text,
  metadata_minimal jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint audit_events_metadata check (
    not (
      metadata_minimal ? 'phone'
      or metadata_minimal ? 'email'
      or metadata_minimal ? 'aadhaar'
    )
  )
);$homizi_20261011120000_54$,
    $homizi_20261011120000_55$create table public.consent_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  policy_type public.consent_policy_type not null,
  policy_version text not null,
  accepted_at timestamptz not null default now(),
  revoked_at timestamptz
);$homizi_20261011120000_55$,
    $homizi_20261011120000_56$-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index users_status_idx on public.users (status);$homizi_20261011120000_56$,
    $homizi_20261011120000_57$create index properties_host_idx on public.properties (host_user_id);$homizi_20261011120000_57$,
    $homizi_20261011120000_58$create index properties_discovery_idx
  on public.properties (status, city, locality);$homizi_20261011120000_58$,
    $homizi_20261011120000_59$create index properties_rent_idx
  on public.properties (rent_inr)
  where status = 'published';$homizi_20261011120000_59$,
    $homizi_20261011120000_60$create index property_photos_property_idx on public.property_photos (property_id);$homizi_20261011120000_60$,
    $homizi_20261011120000_61$create index listing_requirements_owner_idx
  on public.listing_requirements (user_id, status);$homizi_20261011120000_61$,
    $homizi_20261011120000_62$create index interests_actor_idx on public.interests (actor_user_id, created_at desc);$homizi_20261011120000_62$,
    $homizi_20261011120000_63$create index interests_target_idx on public.interests (target_type, target_id);$homizi_20261011120000_63$,
    $homizi_20261011120000_64$create index matches_participant_a_idx on public.matches (participant_a);$homizi_20261011120000_64$,
    $homizi_20261011120000_65$create index matches_participant_b_idx on public.matches (participant_b);$homizi_20261011120000_65$,
    $homizi_20261011120000_66$create index blocks_blocked_idx on public.blocks (blocked_user_id);$homizi_20261011120000_66$,
    $homizi_20261011120000_67$create index reports_status_idx on public.reports (status, created_at);$homizi_20261011120000_67$,
    $homizi_20261011120000_68$create index notifications_user_idx
  on public.notifications (user_id, created_at desc);$homizi_20261011120000_68$,
    $homizi_20261011120000_69$create index messages_conversation_idx
  on public.messages (conversation_id, created_at);$homizi_20261011120000_69$,
    $homizi_20261011120000_70$-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;$homizi_20261011120000_70$,
    $homizi_20261011120000_71$create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();$homizi_20261011120000_71$,
    $homizi_20261011120000_72$create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();$homizi_20261011120000_72$,
    $homizi_20261011120000_73$create trigger private_contacts_set_updated_at
  before update on public.private_contacts
  for each row execute function public.set_updated_at();$homizi_20261011120000_73$,
    $homizi_20261011120000_74$create trigger host_profiles_set_updated_at
  before update on public.host_profiles
  for each row execute function public.set_updated_at();$homizi_20261011120000_74$,
    $homizi_20261011120000_75$create trigger tenant_preferences_set_updated_at
  before update on public.tenant_preferences
  for each row execute function public.set_updated_at();$homizi_20261011120000_75$,
    $homizi_20261011120000_76$create trigger properties_set_updated_at
  before update on public.properties
  for each row execute function public.set_updated_at();$homizi_20261011120000_76$,
    $homizi_20261011120000_77$create trigger property_private_details_set_updated_at
  before update on public.property_private_details
  for each row execute function public.set_updated_at();$homizi_20261011120000_77$,
    $homizi_20261011120000_78$create trigger property_photos_set_updated_at
  before update on public.property_photos
  for each row execute function public.set_updated_at();$homizi_20261011120000_78$,
    $homizi_20261011120000_79$create trigger listing_requirements_set_updated_at
  before update on public.listing_requirements
  for each row execute function public.set_updated_at();$homizi_20261011120000_79$,
    $homizi_20261011120000_80$create trigger interests_set_updated_at
  before update on public.interests
  for each row execute function public.set_updated_at();$homizi_20261011120000_80$,
    $homizi_20261011120000_81$create trigger matches_set_updated_at
  before update on public.matches
  for each row execute function public.set_updated_at();$homizi_20261011120000_81$,
    $homizi_20261011120000_82$create trigger conversations_set_updated_at
  before update on public.conversations
  for each row execute function public.set_updated_at();$homizi_20261011120000_82$,
    $homizi_20261011120000_83$create trigger visit_requests_set_updated_at
  before update on public.visit_requests
  for each row execute function public.set_updated_at();$homizi_20261011120000_83$,
    $homizi_20261011120000_84$create trigger subscriptions_set_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();$homizi_20261011120000_84$,
    $homizi_20261011120000_85$create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();$homizi_20261011120000_85$,
    $homizi_20261011120000_86$-- ---------------------------------------------------------------------------
-- New auth user -> app rows. Email is copied; phone is filled by the owner later.
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id) values (new.id) on conflict do nothing;
  insert into public.profiles (user_id) values (new.id) on conflict do nothing;
  insert into public.private_contacts (user_id, email)
  values (new.id, new.email)
  on conflict (user_id) do nothing;
  return new;
end;
$$;$homizi_20261011120000_86$,
    $homizi_20261011120000_87$create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();$homizi_20261011120000_87$
  ]::text[]
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261011120100_homizi_access.sql
-- -------------------------------------------------------------------------

-- Access rules and server functions.
-- create_interest, create_mutual_match, and get_contact_visibility are authoritative.
-- A like becomes a match only when each person has an active like toward the other
-- (their user id, a published property they host, or a published requirement they own).
-- Passing after a match does not dissolve it. That behavior is an owner decision.

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff_roles where user_id = auth.uid()
  );
$$;

create or replace function public.is_blocked_with(other_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.blocks
    where (blocker_id = auth.uid() and blocked_user_id = other_user)
       or (blocker_id = other_user and blocked_user_id = auth.uid())
  );
$$;

create or replace function public._has_like_toward_user(p_actor uuid, p_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.interests i
    where i.actor_user_id = p_actor
      and i.action = 'like'
      and (
        (i.target_type = 'user' and i.target_id = p_owner)
        or (
          i.target_type = 'property'
          and exists (
            select 1
            from public.properties p
            where p.id = i.target_id
              and p.host_user_id = p_owner
              and p.status = 'published'
          )
        )
        or (
          i.target_type = 'listing_requirement'
          and exists (
            select 1
            from public.listing_requirements r
            where r.id = i.target_id
              and r.user_id = p_owner
              and r.status = 'published'
          )
        )
      )
  );
$$;

create or replace function public._try_mutual_match(p_left uuid, p_right uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_low uuid;
  v_high uuid;
  v_match public.matches;
begin
  if p_left is null or p_right is null or p_left = p_right then
    return jsonb_build_object('ok', false, 'error', 'invalid_pair');
  end if;

  if p_left < p_right then
    v_low := p_left;
    v_high := p_right;
  else
    v_low := p_right;
    v_high := p_left;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_low::text || ':' || v_high::text, 0));

  select * into v_match
  from public.matches
  where participant_a = v_low and participant_b = v_high;

  if found then
    return jsonb_build_object(
      'ok', true,
      'match_id', v_match.id,
      'status', v_match.status,
      'idempotent', true
    );
  end if;

  if exists (
    select 1 from public.users
    where id in (p_left, p_right) and status <> 'active'
  ) then
    return jsonb_build_object('ok', false, 'error', 'inactive_user');
  end if;

  if exists (
    select 1 from public.blocks
    where (blocker_id = p_left and blocked_user_id = p_right)
       or (blocker_id = p_right and blocked_user_id = p_left)
  ) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;

  if not public._has_like_toward_user(p_left, p_right)
     or not public._has_like_toward_user(p_right, p_left) then
    return jsonb_build_object('ok', false, 'error', 'no_reciprocal');
  end if;

  insert into public.matches (participant_a, participant_b)
  values (v_low, v_high)
  on conflict (participant_a, participant_b) do nothing
  returning * into v_match;

  if v_match.id is null then
    select * into v_match
    from public.matches
    where participant_a = v_low and participant_b = v_high;
  end if;

  return jsonb_build_object(
    'ok', true,
    'match_id', v_match.id,
    'status', v_match.status,
    'idempotent', false
  );
end;
$$;

create or replace function public.create_interest(
  p_target_type public.interest_target_type,
  p_target_id uuid,
  p_action public.interest_action
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_visible boolean := false;
  v_found boolean := false;
  v_existing uuid;
  v_id uuid;
  v_match jsonb := null;
  v_recent bigint;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  if p_target_type = 'property' then
    select host_user_id, status = 'published', true
      into v_owner, v_visible, v_found
    from public.properties
    where id = p_target_id;
  elsif p_target_type = 'listing_requirement' then
    select user_id, status = 'published', true
      into v_owner, v_visible, v_found
    from public.listing_requirements
    where id = p_target_id;
  elsif p_target_type = 'user' then
    select p_target_id, exists (
      select 1 from public.properties p
      where p.host_user_id = p_target_id and p.status = 'published'
      union all
      select 1 from public.listing_requirements r
      where r.user_id = p_target_id and r.status = 'published'
    ), exists (select 1 from public.users u where u.id = p_target_id)
      into v_owner, v_visible, v_found;
  end if;

  if not coalesce(v_found, false) then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_owner = v_uid then
    return jsonb_build_object('ok', false, 'error', 'self');
  end if;
  if not v_visible then
    return jsonb_build_object('ok', false, 'error', 'not_visible');
  end if;
  if exists (
    select 1 from public.blocks
    where (blocker_id = v_uid and blocked_user_id = v_owner)
       or (blocker_id = v_owner and blocked_user_id = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;

  select count(*) into v_recent
  from public.interests
  where actor_user_id = v_uid
    and created_at > now() - interval '1 hour';
  if v_recent >= 200 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  select id into v_existing
  from public.interests
  where actor_user_id = v_uid
    and target_type = p_target_type
    and target_id = p_target_id
    and action = p_action;

  if v_existing is not null then
    update public.interests set updated_at = now() where id = v_existing;
    if p_action = 'like' then
      v_match := public._try_mutual_match(v_uid, v_owner);
    end if;
    return jsonb_build_object(
      'ok', true,
      'interest_id', v_existing,
      'idempotent', true,
      'match', v_match
    );
  end if;

  if p_action in ('like', 'pass') then
    delete from public.interests
    where actor_user_id = v_uid
      and target_type = p_target_type
      and target_id = p_target_id
      and action in ('like', 'pass');
  end if;

  insert into public.interests (actor_user_id, target_type, target_id, action)
  values (v_uid, p_target_type, p_target_id, p_action)
  returning id into v_id;

  if p_action = 'like' then
    v_match := public._try_mutual_match(v_uid, v_owner);
  end if;

  return jsonb_build_object(
    'ok', true,
    'interest_id', v_id,
    'idempotent', false,
    'match', v_match
  );
end;
$$;

create or replace function public.create_mutual_match(p_other_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  return public._try_mutual_match(v_uid, p_other_user_id);
end;
$$;

create or replace function public.get_contact_visibility(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_consent public.contact_consents;
  v_contact public.private_contacts;
begin
  if v_uid is null then
    return jsonb_build_object(
      'visible', false,
      'reason', 'unauthenticated',
      'phone', null,
      'email', null
    );
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if not found
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object(
      'visible', false,
      'reason', 'not_found',
      'phone', null,
      'email', null
    );
  end if;

  if v_match.status <> 'active' then
    return jsonb_build_object(
      'visible', false,
      'reason', 'match_inactive',
      'phone', null,
      'email', null
    );
  end if;

  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;

  if exists (
    select 1 from public.blocks
    where (blocker_id = v_uid and blocked_user_id = v_other)
       or (blocker_id = v_other and blocked_user_id = v_uid)
  ) then
    return jsonb_build_object(
      'visible', false,
      'reason', 'blocked',
      'phone', null,
      'email', null
    );
  end if;

  select * into v_consent
  from public.contact_consents
  where match_id = p_match_id
    and granted_by = v_other
    and revoked_at is null;

  if not found then
    return jsonb_build_object(
      'visible', false,
      'reason', 'consent_required',
      'phone', null,
      'email', null
    );
  end if;

  select * into v_contact from public.private_contacts where user_id = v_other;

  return jsonb_build_object(
    'visible', true,
    'reason', 'granted',
    'phone', case
      when v_consent.scope in ('phone', 'phone_and_email') then v_contact.phone
      else null
    end,
    'email', case
      when v_consent.scope in ('email', 'phone_and_email') then v_contact.email
      else null
    end
  );
end;
$$;

comment on function public.get_contact_visibility(uuid) is
  'Returns phone or email only for an active match participant when the other person has unrevoked consent and neither side has blocked the other.';

create or replace function public.grant_contact_consent(
  p_match_id uuid,
  p_scope public.contact_scope
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_match from public.matches where id = p_match_id;
  if not found
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b)
     or v_match.status <> 'active' then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if exists (
    select 1 from public.blocks
    where (blocker_id = v_uid and blocked_user_id = v_other)
       or (blocker_id = v_other and blocked_user_id = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;

  insert into public.contact_consents (match_id, granted_by, scope)
  values (p_match_id, v_uid, p_scope)
  on conflict (match_id, granted_by) do update
    set scope = excluded.scope,
        revoked_at = null,
        granted_at = now()
  returning id into v_id;

  return jsonb_build_object('ok', true, 'consent_id', v_id);
end;
$$;

create or replace function public.revoke_contact_consent(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  update public.contact_consents
  set revoked_at = now()
  where match_id = p_match_id
    and granted_by = v_uid
    and revoked_at is null;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.publish_listing(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_property public.properties;
  v_photos integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_property from public.properties where id = p_property_id;
  if not found or v_property.host_user_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if char_length(v_property.title) < 3
     or char_length(v_property.locality) < 1
     or v_property.rent_inr <= 0 then
    return jsonb_build_object('ok', false, 'error', 'incomplete');
  end if;
  select count(*) into v_photos
  from public.property_photos
  where property_id = p_property_id;
  if v_photos < 3 then
    return jsonb_build_object('ok', false, 'error', 'photos');
  end if;
  update public.properties
  set status = 'published',
      published_at = coalesce(published_at, now())
  where id = p_property_id;
  return jsonb_build_object('ok', true, 'property_id', p_property_id);
end;
$$;

create or replace function public.publish_requirement(p_requirement_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.listing_requirements;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_row from public.listing_requirements where id = p_requirement_id;
  if not found or v_row.user_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if v_row.budget_min_inr > v_row.budget_max_inr or char_length(v_row.city) < 1 then
    return jsonb_build_object('ok', false, 'error', 'incomplete');
  end if;
  update public.listing_requirements
  set status = 'published'
  where id = p_requirement_id;
  return jsonb_build_object('ok', true, 'requirement_id', p_requirement_id);
end;
$$;

create or replace function public.request_mock_verification()
returns public.verification_status
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'unauthenticated';
  end if;
  update public.profiles
  set verification_status = 'mock_pending'
  where user_id = v_uid;
  return 'mock_pending';
end;
$$;

comment on function public.request_mock_verification() is
  'Sets mock_pending only. Never collects a document. mock_verified is not settable by the client.';

-- ---------------------------------------------------------------------------
-- Grants. auto_expose is off; everything below is explicit.
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from public, anon, authenticated;

revoke all on all functions in schema public from public, anon, authenticated;

grant usage on schema public to anon, authenticated, service_role;

grant all on all tables in schema public to service_role;

grant all on all functions in schema public to service_role;

-- Hosted projects may not let the migration role grant on auth.uid().
-- Local and hosted already allow anon and authenticated to execute it.
do $$
begin
  grant execute on function auth.uid() to anon, authenticated;
exception
  when insufficient_privilege then
    raise notice 'auth.uid grant skipped: %', sqlerrm;
end $$;

grant select on public.users to authenticated;

grant update (primary_role) on public.users to authenticated;

grant select on public.profiles to authenticated;

grant update (display_name, occupation, public_bio, avatar_path)
  on public.profiles to authenticated;

grant select, update (email, phone, date_of_birth)
  on public.private_contacts to authenticated;

grant select, insert, update, delete on public.host_profiles to authenticated;

grant select, insert, update, delete on public.tenant_preferences to authenticated;

grant select on public.properties to authenticated;

grant insert (
  id, host_user_id, title, locality, city, address_visibility, property_type,
  furnishing, rent_inr, deposit_inr, brokerage_inr, maintenance_inr,
  occupancy_max, available_from
) on public.properties to authenticated;

grant update (
  title, locality, city, address_visibility, property_type, furnishing,
  rent_inr, deposit_inr, brokerage_inr, maintenance_inr, occupancy_max,
  available_from
) on public.properties to authenticated;

grant select, insert, update, delete on public.property_private_details to authenticated;

grant select, insert, update, delete on public.property_features to authenticated;

grant select on public.property_photos to authenticated;

grant insert (property_id, storage_path, sort_order, photo_type)
  on public.property_photos to authenticated;

grant update (storage_path, sort_order, photo_type)
  on public.property_photos to authenticated;

grant delete on public.property_photos to authenticated;

grant select on public.listing_requirements to authenticated;

grant insert (
  id, user_id, city, localities, budget_min_inr, budget_max_inr, move_in_date,
  occupancy, property_types, furnishing, lifestyle
) on public.listing_requirements to authenticated;

grant update (
  city, localities, budget_min_inr, budget_max_inr, move_in_date, occupancy,
  property_types, furnishing, lifestyle
) on public.listing_requirements to authenticated;

grant select on public.interests to authenticated;

grant select on public.matches to authenticated;

grant select on public.contact_consents to authenticated;

grant select on public.conversations to authenticated;

grant select, insert on public.messages to authenticated;

grant select, insert, update on public.visit_requests to authenticated;

grant select, update (read_at) on public.notifications to authenticated;

grant select, insert on public.reports to authenticated;

grant select, insert, delete on public.blocks to authenticated;

grant select on public.staff_roles to authenticated;

grant select on public.subscriptions to authenticated;

grant select on public.payments to authenticated;

grant select, insert, update (revoked_at) on public.consent_records to authenticated;

grant execute on function public.is_staff() to authenticated;

grant execute on function public.is_blocked_with(uuid) to authenticated;

grant execute on function public.create_interest(public.interest_target_type, uuid, public.interest_action) to authenticated;

grant execute on function public.create_mutual_match(uuid) to authenticated;

grant execute on function public.get_contact_visibility(uuid) to authenticated;

grant execute on function public.grant_contact_consent(uuid, public.contact_scope) to authenticated;

grant execute on function public.revoke_contact_consent(uuid) to authenticated;

grant execute on function public.publish_listing(uuid) to authenticated;

grant execute on function public.publish_requirement(uuid) to authenticated;

grant execute on function public.request_mock_verification() to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.users enable row level security;

alter table public.profiles enable row level security;

alter table public.private_contacts enable row level security;

alter table public.host_profiles enable row level security;

alter table public.tenant_preferences enable row level security;

alter table public.properties enable row level security;

alter table public.property_private_details enable row level security;

alter table public.property_features enable row level security;

alter table public.property_photos enable row level security;

alter table public.listing_requirements enable row level security;

alter table public.interests enable row level security;

alter table public.matches enable row level security;

alter table public.contact_consents enable row level security;

alter table public.conversations enable row level security;

alter table public.messages enable row level security;

alter table public.visit_requests enable row level security;

alter table public.notifications enable row level security;

alter table public.reports enable row level security;

alter table public.blocks enable row level security;

alter table public.staff_roles enable row level security;

alter table public.subscriptions enable row level security;

alter table public.payments enable row level security;

alter table public.audit_events enable row level security;

alter table public.consent_records enable row level security;

drop policy if exists users_select_self on public.users;
create policy users_select_self on public.users
  for select to authenticated
  using (id = auth.uid() or public.is_staff());

drop policy if exists users_update_self on public.users;
create policy users_update_self on public.users
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_staff()
    or exists (
      select 1 from public.properties p
      where p.host_user_id = profiles.user_id and p.status = 'published'
    )
    or exists (
      select 1 from public.listing_requirements r
      where r.user_id = profiles.user_id and r.status = 'published'
    )
    or exists (
      select 1 from public.matches m
      where m.status = 'active'
        and (
          (m.participant_a = auth.uid() and m.participant_b = profiles.user_id)
          or (m.participant_b = auth.uid() and m.participant_a = profiles.user_id)
        )
    )
  );

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists private_contacts_self on public.private_contacts;
create policy private_contacts_self on public.private_contacts
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists host_profiles_self on public.host_profiles;
create policy host_profiles_self on public.host_profiles
  for all to authenticated
  using (user_id = auth.uid() or public.is_staff())
  with check (user_id = auth.uid());

drop policy if exists tenant_preferences_self on public.tenant_preferences;
create policy tenant_preferences_self on public.tenant_preferences
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists properties_select on public.properties;
create policy properties_select on public.properties
  for select to authenticated
  using (
    host_user_id = auth.uid()
    or (
      status = 'published'
      and not public.is_blocked_with(host_user_id)
    )
  );

drop policy if exists properties_insert on public.properties;
create policy properties_insert on public.properties
  for insert to authenticated
  with check (host_user_id = auth.uid());

drop policy if exists properties_update on public.properties;
create policy properties_update on public.properties
  for update to authenticated
  using (host_user_id = auth.uid())
  with check (host_user_id = auth.uid());

drop policy if exists property_private_owner on public.property_private_details;
create policy property_private_owner on public.property_private_details
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );

drop policy if exists property_features_select on public.property_features;
create policy property_features_select on public.property_features
  for select to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id
        and (
          p.host_user_id = auth.uid()
          or (p.status = 'published' and not public.is_blocked_with(p.host_user_id))
        )
    )
  );

drop policy if exists property_features_write on public.property_features;
create policy property_features_write on public.property_features
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );

drop policy if exists property_photos_select on public.property_photos;
create policy property_photos_select on public.property_photos
  for select to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id
        and (
          p.host_user_id = auth.uid()
          or (p.status = 'published' and not public.is_blocked_with(p.host_user_id))
        )
    )
  );

drop policy if exists property_photos_write on public.property_photos;
create policy property_photos_write on public.property_photos
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );

drop policy if exists requirements_select on public.listing_requirements;
create policy requirements_select on public.listing_requirements
  for select to authenticated
  using (
    user_id = auth.uid()
    or (
      status = 'published'
      and not public.is_blocked_with(user_id)
    )
  );

drop policy if exists requirements_insert on public.listing_requirements;
create policy requirements_insert on public.listing_requirements
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists requirements_update on public.listing_requirements;
create policy requirements_update on public.listing_requirements
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists interests_select_own on public.interests;
create policy interests_select_own on public.interests
  for select to authenticated
  using (actor_user_id = auth.uid());

drop policy if exists matches_select_participant on public.matches;
create policy matches_select_participant on public.matches
  for select to authenticated
  using (participant_a = auth.uid() or participant_b = auth.uid());

drop policy if exists consents_select_participant on public.contact_consents;
create policy consents_select_participant on public.contact_consents
  for select to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );

drop policy if exists conversations_select_member on public.conversations;
create policy conversations_select_member on public.conversations
  for select to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.status = 'active'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );

drop policy if exists messages_select_member on public.messages;
create policy messages_select_member on public.messages
  for select to authenticated
  using (
    exists (
      select 1
      from public.conversations c
      join public.matches m on m.id = c.match_id
      where c.id = conversation_id
        and c.status = 'open'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
        and not public.is_blocked_with(
          case when m.participant_a = auth.uid() then m.participant_b else m.participant_a end
        )
    )
  );

drop policy if exists messages_insert_member on public.messages;
create policy messages_insert_member on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.conversations c
      join public.matches m on m.id = c.match_id
      where c.id = conversation_id
        and c.status = 'open'
        and m.status = 'active'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
        and not public.is_blocked_with(
          case when m.participant_a = auth.uid() then m.participant_b else m.participant_a end
        )
    )
  );

drop policy if exists visits_participant on public.visit_requests;
create policy visits_participant on public.visit_requests
  for all to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  )
  with check (
    requester_id = auth.uid()
    and exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.status = 'active'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );

drop policy if exists notifications_recipient on public.notifications;
create policy notifications_recipient on public.notifications
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists notifications_mark_read on public.notifications;
create policy notifications_mark_read on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists reports_insert_own on public.reports;
create policy reports_insert_own on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open');

drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports
  for select to authenticated
  using (reporter_id = auth.uid() or public.is_staff());

drop policy if exists blocks_own on public.blocks;
create policy blocks_own on public.blocks
  for all to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

drop policy if exists staff_roles_select_self on public.staff_roles;
create policy staff_roles_select_self on public.staff_roles
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists subscriptions_select_own on public.subscriptions;
create policy subscriptions_select_own on public.subscriptions
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists payments_select_own on public.payments;
create policy payments_select_own on public.payments
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists consent_records_own on public.consent_records;
create policy consent_records_own on public.consent_records
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- audit_events: RLS on, no policies. service_role bypasses RLS.

-- Listing photo bucket, when the storage schema is present in this database.
do $homizi_storage$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; listing-photos bucket skipped';
    return;
  end if;
  insert into storage.buckets (id, name, public)
  values ('listing-photos', 'listing-photos', false)
  on conflict (id) do update
  set public = excluded.public;
  begin
    execute 'drop policy if exists listing_photos_insert on storage.objects';
    execute 'drop policy if exists listing_photos_select on storage.objects';
    execute 'drop policy if exists listing_photos_update on storage.objects';
    execute 'drop policy if exists listing_photos_delete on storage.objects';
    execute $policy$
      create policy listing_photos_insert on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $policy$;
    execute $policy$
      create policy listing_photos_select on storage.objects
      for select to authenticated
      using (
        bucket_id = 'listing-photos'
        and (
          (storage.foldername(name))[1] = auth.uid()::text
          or exists (
            select 1
            from public.property_photos ph
            join public.properties p on p.id = ph.property_id
            where ph.storage_path = name
              and p.status = 'published'
          )
        )
      )
    $policy$;
    execute $policy$
      create policy listing_photos_update on storage.objects
      for update to authenticated
      using (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $policy$;
    execute $policy$
      create policy listing_photos_delete on storage.objects
      for delete to authenticated
      using (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $policy$;
  exception
    when insufficient_privilege then
      raise notice 'listing-photos storage policies skipped: %', sqlerrm;
    when others then
      raise notice 'listing-photos storage policies skipped: %', sqlerrm;
  end;
exception
  when insufficient_privilege then
    raise notice 'listing-photos bucket skipped: %', sqlerrm;
end
$homizi_storage$;



insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261011120100',
  'homizi_access',
  array[
    $homizi_20261011120100_1$-- Access rules and server functions.
-- create_interest, create_mutual_match, and get_contact_visibility are authoritative.
-- A like becomes a match only when each person has an active like toward the other
-- (their user id, a published property they host, or a published requirement they own).
-- Passing after a match does not dissolve it. That behavior is an owner decision.

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff_roles where user_id = auth.uid()
  );
$$;$homizi_20261011120100_1$,
    $homizi_20261011120100_2$create or replace function public.is_blocked_with(other_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.blocks
    where (blocker_id = auth.uid() and blocked_user_id = other_user)
       or (blocker_id = other_user and blocked_user_id = auth.uid())
  );
$$;$homizi_20261011120100_2$,
    $homizi_20261011120100_3$create or replace function public._has_like_toward_user(p_actor uuid, p_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.interests i
    where i.actor_user_id = p_actor
      and i.action = 'like'
      and (
        (i.target_type = 'user' and i.target_id = p_owner)
        or (
          i.target_type = 'property'
          and exists (
            select 1
            from public.properties p
            where p.id = i.target_id
              and p.host_user_id = p_owner
              and p.status = 'published'
          )
        )
        or (
          i.target_type = 'listing_requirement'
          and exists (
            select 1
            from public.listing_requirements r
            where r.id = i.target_id
              and r.user_id = p_owner
              and r.status = 'published'
          )
        )
      )
  );
$$;$homizi_20261011120100_3$,
    $homizi_20261011120100_4$create or replace function public._try_mutual_match(p_left uuid, p_right uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_low uuid;
  v_high uuid;
  v_match public.matches;
begin
  if p_left is null or p_right is null or p_left = p_right then
    return jsonb_build_object('ok', false, 'error', 'invalid_pair');
  end if;

  if p_left < p_right then
    v_low := p_left;
    v_high := p_right;
  else
    v_low := p_right;
    v_high := p_left;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_low::text || ':' || v_high::text, 0));

  select * into v_match
  from public.matches
  where participant_a = v_low and participant_b = v_high;

  if found then
    return jsonb_build_object(
      'ok', true,
      'match_id', v_match.id,
      'status', v_match.status,
      'idempotent', true
    );
  end if;

  if exists (
    select 1 from public.users
    where id in (p_left, p_right) and status <> 'active'
  ) then
    return jsonb_build_object('ok', false, 'error', 'inactive_user');
  end if;

  if exists (
    select 1 from public.blocks
    where (blocker_id = p_left and blocked_user_id = p_right)
       or (blocker_id = p_right and blocked_user_id = p_left)
  ) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;

  if not public._has_like_toward_user(p_left, p_right)
     or not public._has_like_toward_user(p_right, p_left) then
    return jsonb_build_object('ok', false, 'error', 'no_reciprocal');
  end if;

  insert into public.matches (participant_a, participant_b)
  values (v_low, v_high)
  on conflict (participant_a, participant_b) do nothing
  returning * into v_match;

  if v_match.id is null then
    select * into v_match
    from public.matches
    where participant_a = v_low and participant_b = v_high;
  end if;

  return jsonb_build_object(
    'ok', true,
    'match_id', v_match.id,
    'status', v_match.status,
    'idempotent', false
  );
end;
$$;$homizi_20261011120100_4$,
    $homizi_20261011120100_5$create or replace function public.create_interest(
  p_target_type public.interest_target_type,
  p_target_id uuid,
  p_action public.interest_action
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_visible boolean := false;
  v_found boolean := false;
  v_existing uuid;
  v_id uuid;
  v_match jsonb := null;
  v_recent bigint;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  if p_target_type = 'property' then
    select host_user_id, status = 'published', true
      into v_owner, v_visible, v_found
    from public.properties
    where id = p_target_id;
  elsif p_target_type = 'listing_requirement' then
    select user_id, status = 'published', true
      into v_owner, v_visible, v_found
    from public.listing_requirements
    where id = p_target_id;
  elsif p_target_type = 'user' then
    select p_target_id, exists (
      select 1 from public.properties p
      where p.host_user_id = p_target_id and p.status = 'published'
      union all
      select 1 from public.listing_requirements r
      where r.user_id = p_target_id and r.status = 'published'
    ), exists (select 1 from public.users u where u.id = p_target_id)
      into v_owner, v_visible, v_found;
  end if;

  if not coalesce(v_found, false) then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_owner = v_uid then
    return jsonb_build_object('ok', false, 'error', 'self');
  end if;
  if not v_visible then
    return jsonb_build_object('ok', false, 'error', 'not_visible');
  end if;
  if exists (
    select 1 from public.blocks
    where (blocker_id = v_uid and blocked_user_id = v_owner)
       or (blocker_id = v_owner and blocked_user_id = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;

  select count(*) into v_recent
  from public.interests
  where actor_user_id = v_uid
    and created_at > now() - interval '1 hour';
  if v_recent >= 200 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  select id into v_existing
  from public.interests
  where actor_user_id = v_uid
    and target_type = p_target_type
    and target_id = p_target_id
    and action = p_action;

  if v_existing is not null then
    update public.interests set updated_at = now() where id = v_existing;
    if p_action = 'like' then
      v_match := public._try_mutual_match(v_uid, v_owner);
    end if;
    return jsonb_build_object(
      'ok', true,
      'interest_id', v_existing,
      'idempotent', true,
      'match', v_match
    );
  end if;

  if p_action in ('like', 'pass') then
    delete from public.interests
    where actor_user_id = v_uid
      and target_type = p_target_type
      and target_id = p_target_id
      and action in ('like', 'pass');
  end if;

  insert into public.interests (actor_user_id, target_type, target_id, action)
  values (v_uid, p_target_type, p_target_id, p_action)
  returning id into v_id;

  if p_action = 'like' then
    v_match := public._try_mutual_match(v_uid, v_owner);
  end if;

  return jsonb_build_object(
    'ok', true,
    'interest_id', v_id,
    'idempotent', false,
    'match', v_match
  );
end;
$$;$homizi_20261011120100_5$,
    $homizi_20261011120100_6$create or replace function public.create_mutual_match(p_other_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  return public._try_mutual_match(v_uid, p_other_user_id);
end;
$$;$homizi_20261011120100_6$,
    $homizi_20261011120100_7$create or replace function public.get_contact_visibility(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_consent public.contact_consents;
  v_contact public.private_contacts;
begin
  if v_uid is null then
    return jsonb_build_object(
      'visible', false,
      'reason', 'unauthenticated',
      'phone', null,
      'email', null
    );
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if not found
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object(
      'visible', false,
      'reason', 'not_found',
      'phone', null,
      'email', null
    );
  end if;

  if v_match.status <> 'active' then
    return jsonb_build_object(
      'visible', false,
      'reason', 'match_inactive',
      'phone', null,
      'email', null
    );
  end if;

  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;

  if exists (
    select 1 from public.blocks
    where (blocker_id = v_uid and blocked_user_id = v_other)
       or (blocker_id = v_other and blocked_user_id = v_uid)
  ) then
    return jsonb_build_object(
      'visible', false,
      'reason', 'blocked',
      'phone', null,
      'email', null
    );
  end if;

  select * into v_consent
  from public.contact_consents
  where match_id = p_match_id
    and granted_by = v_other
    and revoked_at is null;

  if not found then
    return jsonb_build_object(
      'visible', false,
      'reason', 'consent_required',
      'phone', null,
      'email', null
    );
  end if;

  select * into v_contact from public.private_contacts where user_id = v_other;

  return jsonb_build_object(
    'visible', true,
    'reason', 'granted',
    'phone', case
      when v_consent.scope in ('phone', 'phone_and_email') then v_contact.phone
      else null
    end,
    'email', case
      when v_consent.scope in ('email', 'phone_and_email') then v_contact.email
      else null
    end
  );
end;
$$;$homizi_20261011120100_7$,
    $homizi_20261011120100_8$comment on function public.get_contact_visibility(uuid) is
  'Returns phone or email only for an active match participant when the other person has unrevoked consent and neither side has blocked the other.';$homizi_20261011120100_8$,
    $homizi_20261011120100_9$create or replace function public.grant_contact_consent(
  p_match_id uuid,
  p_scope public.contact_scope
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_match from public.matches where id = p_match_id;
  if not found
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b)
     or v_match.status <> 'active' then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if exists (
    select 1 from public.blocks
    where (blocker_id = v_uid and blocked_user_id = v_other)
       or (blocker_id = v_other and blocked_user_id = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;

  insert into public.contact_consents (match_id, granted_by, scope)
  values (p_match_id, v_uid, p_scope)
  on conflict (match_id, granted_by) do update
    set scope = excluded.scope,
        revoked_at = null,
        granted_at = now()
  returning id into v_id;

  return jsonb_build_object('ok', true, 'consent_id', v_id);
end;
$$;$homizi_20261011120100_9$,
    $homizi_20261011120100_10$create or replace function public.revoke_contact_consent(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  update public.contact_consents
  set revoked_at = now()
  where match_id = p_match_id
    and granted_by = v_uid
    and revoked_at is null;
  return jsonb_build_object('ok', true);
end;
$$;$homizi_20261011120100_10$,
    $homizi_20261011120100_11$create or replace function public.publish_listing(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_property public.properties;
  v_photos integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_property from public.properties where id = p_property_id;
  if not found or v_property.host_user_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if char_length(v_property.title) < 3
     or char_length(v_property.locality) < 1
     or v_property.rent_inr <= 0 then
    return jsonb_build_object('ok', false, 'error', 'incomplete');
  end if;
  select count(*) into v_photos
  from public.property_photos
  where property_id = p_property_id;
  if v_photos < 3 then
    return jsonb_build_object('ok', false, 'error', 'photos');
  end if;
  update public.properties
  set status = 'published',
      published_at = coalesce(published_at, now())
  where id = p_property_id;
  return jsonb_build_object('ok', true, 'property_id', p_property_id);
end;
$$;$homizi_20261011120100_11$,
    $homizi_20261011120100_12$create or replace function public.publish_requirement(p_requirement_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.listing_requirements;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_row from public.listing_requirements where id = p_requirement_id;
  if not found or v_row.user_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if v_row.budget_min_inr > v_row.budget_max_inr or char_length(v_row.city) < 1 then
    return jsonb_build_object('ok', false, 'error', 'incomplete');
  end if;
  update public.listing_requirements
  set status = 'published'
  where id = p_requirement_id;
  return jsonb_build_object('ok', true, 'requirement_id', p_requirement_id);
end;
$$;$homizi_20261011120100_12$,
    $homizi_20261011120100_13$create or replace function public.request_mock_verification()
returns public.verification_status
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'unauthenticated';
  end if;
  update public.profiles
  set verification_status = 'mock_pending'
  where user_id = v_uid;
  return 'mock_pending';
end;
$$;$homizi_20261011120100_13$,
    $homizi_20261011120100_14$comment on function public.request_mock_verification() is
  'Sets mock_pending only. Never collects a document. mock_verified is not settable by the client.';$homizi_20261011120100_14$,
    $homizi_20261011120100_15$-- ---------------------------------------------------------------------------
-- Grants. auto_expose is off; everything below is explicit.
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from public, anon, authenticated;$homizi_20261011120100_15$,
    $homizi_20261011120100_16$revoke all on all functions in schema public from public, anon, authenticated;$homizi_20261011120100_16$,
    $homizi_20261011120100_17$grant usage on schema public to anon, authenticated, service_role;$homizi_20261011120100_17$,
    $homizi_20261011120100_18$grant all on all tables in schema public to service_role;$homizi_20261011120100_18$,
    $homizi_20261011120100_19$grant all on all functions in schema public to service_role;$homizi_20261011120100_19$,
    $homizi_20261011120100_20$-- Hosted projects may not let the migration role grant on auth.uid().
-- Local and hosted already allow anon and authenticated to execute it.
do $$
begin
  grant execute on function auth.uid() to anon, authenticated;
exception
  when insufficient_privilege then
    raise notice 'auth.uid grant skipped: %', sqlerrm;
end $$;$homizi_20261011120100_20$,
    $homizi_20261011120100_21$grant select on public.users to authenticated;$homizi_20261011120100_21$,
    $homizi_20261011120100_22$grant update (primary_role) on public.users to authenticated;$homizi_20261011120100_22$,
    $homizi_20261011120100_23$grant select on public.profiles to authenticated;$homizi_20261011120100_23$,
    $homizi_20261011120100_24$grant update (display_name, occupation, public_bio, avatar_path)
  on public.profiles to authenticated;$homizi_20261011120100_24$,
    $homizi_20261011120100_25$grant select, update (email, phone, date_of_birth)
  on public.private_contacts to authenticated;$homizi_20261011120100_25$,
    $homizi_20261011120100_26$grant select, insert, update, delete on public.host_profiles to authenticated;$homizi_20261011120100_26$,
    $homizi_20261011120100_27$grant select, insert, update, delete on public.tenant_preferences to authenticated;$homizi_20261011120100_27$,
    $homizi_20261011120100_28$grant select on public.properties to authenticated;$homizi_20261011120100_28$,
    $homizi_20261011120100_29$grant insert (
  id, host_user_id, title, locality, city, address_visibility, property_type,
  furnishing, rent_inr, deposit_inr, brokerage_inr, maintenance_inr,
  occupancy_max, available_from
) on public.properties to authenticated;$homizi_20261011120100_29$,
    $homizi_20261011120100_30$grant update (
  title, locality, city, address_visibility, property_type, furnishing,
  rent_inr, deposit_inr, brokerage_inr, maintenance_inr, occupancy_max,
  available_from
) on public.properties to authenticated;$homizi_20261011120100_30$,
    $homizi_20261011120100_31$grant select, insert, update, delete on public.property_private_details to authenticated;$homizi_20261011120100_31$,
    $homizi_20261011120100_32$grant select, insert, update, delete on public.property_features to authenticated;$homizi_20261011120100_32$,
    $homizi_20261011120100_33$grant select on public.property_photos to authenticated;$homizi_20261011120100_33$,
    $homizi_20261011120100_34$grant insert (property_id, storage_path, sort_order, photo_type)
  on public.property_photos to authenticated;$homizi_20261011120100_34$,
    $homizi_20261011120100_35$grant update (storage_path, sort_order, photo_type)
  on public.property_photos to authenticated;$homizi_20261011120100_35$,
    $homizi_20261011120100_36$grant delete on public.property_photos to authenticated;$homizi_20261011120100_36$,
    $homizi_20261011120100_37$grant select on public.listing_requirements to authenticated;$homizi_20261011120100_37$,
    $homizi_20261011120100_38$grant insert (
  id, user_id, city, localities, budget_min_inr, budget_max_inr, move_in_date,
  occupancy, property_types, furnishing, lifestyle
) on public.listing_requirements to authenticated;$homizi_20261011120100_38$,
    $homizi_20261011120100_39$grant update (
  city, localities, budget_min_inr, budget_max_inr, move_in_date, occupancy,
  property_types, furnishing, lifestyle
) on public.listing_requirements to authenticated;$homizi_20261011120100_39$,
    $homizi_20261011120100_40$grant select on public.interests to authenticated;$homizi_20261011120100_40$,
    $homizi_20261011120100_41$grant select on public.matches to authenticated;$homizi_20261011120100_41$,
    $homizi_20261011120100_42$grant select on public.contact_consents to authenticated;$homizi_20261011120100_42$,
    $homizi_20261011120100_43$grant select on public.conversations to authenticated;$homizi_20261011120100_43$,
    $homizi_20261011120100_44$grant select, insert on public.messages to authenticated;$homizi_20261011120100_44$,
    $homizi_20261011120100_45$grant select, insert, update on public.visit_requests to authenticated;$homizi_20261011120100_45$,
    $homizi_20261011120100_46$grant select, update (read_at) on public.notifications to authenticated;$homizi_20261011120100_46$,
    $homizi_20261011120100_47$grant select, insert on public.reports to authenticated;$homizi_20261011120100_47$,
    $homizi_20261011120100_48$grant select, insert, delete on public.blocks to authenticated;$homizi_20261011120100_48$,
    $homizi_20261011120100_49$grant select on public.staff_roles to authenticated;$homizi_20261011120100_49$,
    $homizi_20261011120100_50$grant select on public.subscriptions to authenticated;$homizi_20261011120100_50$,
    $homizi_20261011120100_51$grant select on public.payments to authenticated;$homizi_20261011120100_51$,
    $homizi_20261011120100_52$grant select, insert, update (revoked_at) on public.consent_records to authenticated;$homizi_20261011120100_52$,
    $homizi_20261011120100_53$grant execute on function public.is_staff() to authenticated;$homizi_20261011120100_53$,
    $homizi_20261011120100_54$grant execute on function public.is_blocked_with(uuid) to authenticated;$homizi_20261011120100_54$,
    $homizi_20261011120100_55$grant execute on function public.create_interest(public.interest_target_type, uuid, public.interest_action) to authenticated;$homizi_20261011120100_55$,
    $homizi_20261011120100_56$grant execute on function public.create_mutual_match(uuid) to authenticated;$homizi_20261011120100_56$,
    $homizi_20261011120100_57$grant execute on function public.get_contact_visibility(uuid) to authenticated;$homizi_20261011120100_57$,
    $homizi_20261011120100_58$grant execute on function public.grant_contact_consent(uuid, public.contact_scope) to authenticated;$homizi_20261011120100_58$,
    $homizi_20261011120100_59$grant execute on function public.revoke_contact_consent(uuid) to authenticated;$homizi_20261011120100_59$,
    $homizi_20261011120100_60$grant execute on function public.publish_listing(uuid) to authenticated;$homizi_20261011120100_60$,
    $homizi_20261011120100_61$grant execute on function public.publish_requirement(uuid) to authenticated;$homizi_20261011120100_61$,
    $homizi_20261011120100_62$grant execute on function public.request_mock_verification() to authenticated;$homizi_20261011120100_62$,
    $homizi_20261011120100_63$-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.users enable row level security;$homizi_20261011120100_63$,
    $homizi_20261011120100_64$alter table public.profiles enable row level security;$homizi_20261011120100_64$,
    $homizi_20261011120100_65$alter table public.private_contacts enable row level security;$homizi_20261011120100_65$,
    $homizi_20261011120100_66$alter table public.host_profiles enable row level security;$homizi_20261011120100_66$,
    $homizi_20261011120100_67$alter table public.tenant_preferences enable row level security;$homizi_20261011120100_67$,
    $homizi_20261011120100_68$alter table public.properties enable row level security;$homizi_20261011120100_68$,
    $homizi_20261011120100_69$alter table public.property_private_details enable row level security;$homizi_20261011120100_69$,
    $homizi_20261011120100_70$alter table public.property_features enable row level security;$homizi_20261011120100_70$,
    $homizi_20261011120100_71$alter table public.property_photos enable row level security;$homizi_20261011120100_71$,
    $homizi_20261011120100_72$alter table public.listing_requirements enable row level security;$homizi_20261011120100_72$,
    $homizi_20261011120100_73$alter table public.interests enable row level security;$homizi_20261011120100_73$,
    $homizi_20261011120100_74$alter table public.matches enable row level security;$homizi_20261011120100_74$,
    $homizi_20261011120100_75$alter table public.contact_consents enable row level security;$homizi_20261011120100_75$,
    $homizi_20261011120100_76$alter table public.conversations enable row level security;$homizi_20261011120100_76$,
    $homizi_20261011120100_77$alter table public.messages enable row level security;$homizi_20261011120100_77$,
    $homizi_20261011120100_78$alter table public.visit_requests enable row level security;$homizi_20261011120100_78$,
    $homizi_20261011120100_79$alter table public.notifications enable row level security;$homizi_20261011120100_79$,
    $homizi_20261011120100_80$alter table public.reports enable row level security;$homizi_20261011120100_80$,
    $homizi_20261011120100_81$alter table public.blocks enable row level security;$homizi_20261011120100_81$,
    $homizi_20261011120100_82$alter table public.staff_roles enable row level security;$homizi_20261011120100_82$,
    $homizi_20261011120100_83$alter table public.subscriptions enable row level security;$homizi_20261011120100_83$,
    $homizi_20261011120100_84$alter table public.payments enable row level security;$homizi_20261011120100_84$,
    $homizi_20261011120100_85$alter table public.audit_events enable row level security;$homizi_20261011120100_85$,
    $homizi_20261011120100_86$alter table public.consent_records enable row level security;$homizi_20261011120100_86$,
    $homizi_20261011120100_87$create policy users_select_self on public.users
  for select to authenticated
  using (id = auth.uid() or public.is_staff());$homizi_20261011120100_87$,
    $homizi_20261011120100_88$create policy users_update_self on public.users
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());$homizi_20261011120100_88$,
    $homizi_20261011120100_89$create policy profiles_select on public.profiles
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_staff()
    or exists (
      select 1 from public.properties p
      where p.host_user_id = profiles.user_id and p.status = 'published'
    )
    or exists (
      select 1 from public.listing_requirements r
      where r.user_id = profiles.user_id and r.status = 'published'
    )
    or exists (
      select 1 from public.matches m
      where m.status = 'active'
        and (
          (m.participant_a = auth.uid() and m.participant_b = profiles.user_id)
          or (m.participant_b = auth.uid() and m.participant_a = profiles.user_id)
        )
    )
  );$homizi_20261011120100_89$,
    $homizi_20261011120100_90$create policy profiles_update_self on public.profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());$homizi_20261011120100_90$,
    $homizi_20261011120100_91$create policy private_contacts_self on public.private_contacts
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());$homizi_20261011120100_91$,
    $homizi_20261011120100_92$create policy host_profiles_self on public.host_profiles
  for all to authenticated
  using (user_id = auth.uid() or public.is_staff())
  with check (user_id = auth.uid());$homizi_20261011120100_92$,
    $homizi_20261011120100_93$create policy tenant_preferences_self on public.tenant_preferences
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());$homizi_20261011120100_93$,
    $homizi_20261011120100_94$create policy properties_select on public.properties
  for select to authenticated
  using (
    host_user_id = auth.uid()
    or (
      status = 'published'
      and not public.is_blocked_with(host_user_id)
    )
  );$homizi_20261011120100_94$,
    $homizi_20261011120100_95$create policy properties_insert on public.properties
  for insert to authenticated
  with check (host_user_id = auth.uid());$homizi_20261011120100_95$,
    $homizi_20261011120100_96$create policy properties_update on public.properties
  for update to authenticated
  using (host_user_id = auth.uid())
  with check (host_user_id = auth.uid());$homizi_20261011120100_96$,
    $homizi_20261011120100_97$create policy property_private_owner on public.property_private_details
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );$homizi_20261011120100_97$,
    $homizi_20261011120100_98$create policy property_features_select on public.property_features
  for select to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id
        and (
          p.host_user_id = auth.uid()
          or (p.status = 'published' and not public.is_blocked_with(p.host_user_id))
        )
    )
  );$homizi_20261011120100_98$,
    $homizi_20261011120100_99$create policy property_features_write on public.property_features
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );$homizi_20261011120100_99$,
    $homizi_20261011120100_100$create policy property_photos_select on public.property_photos
  for select to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id
        and (
          p.host_user_id = auth.uid()
          or (p.status = 'published' and not public.is_blocked_with(p.host_user_id))
        )
    )
  );$homizi_20261011120100_100$,
    $homizi_20261011120100_101$create policy property_photos_write on public.property_photos
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );$homizi_20261011120100_101$,
    $homizi_20261011120100_102$create policy requirements_select on public.listing_requirements
  for select to authenticated
  using (
    user_id = auth.uid()
    or (
      status = 'published'
      and not public.is_blocked_with(user_id)
    )
  );$homizi_20261011120100_102$,
    $homizi_20261011120100_103$create policy requirements_insert on public.listing_requirements
  for insert to authenticated
  with check (user_id = auth.uid());$homizi_20261011120100_103$,
    $homizi_20261011120100_104$create policy requirements_update on public.listing_requirements
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());$homizi_20261011120100_104$,
    $homizi_20261011120100_105$create policy interests_select_own on public.interests
  for select to authenticated
  using (actor_user_id = auth.uid());$homizi_20261011120100_105$,
    $homizi_20261011120100_106$create policy matches_select_participant on public.matches
  for select to authenticated
  using (participant_a = auth.uid() or participant_b = auth.uid());$homizi_20261011120100_106$,
    $homizi_20261011120100_107$create policy consents_select_participant on public.contact_consents
  for select to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );$homizi_20261011120100_107$,
    $homizi_20261011120100_108$create policy conversations_select_member on public.conversations
  for select to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.status = 'active'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );$homizi_20261011120100_108$,
    $homizi_20261011120100_109$create policy messages_select_member on public.messages
  for select to authenticated
  using (
    exists (
      select 1
      from public.conversations c
      join public.matches m on m.id = c.match_id
      where c.id = conversation_id
        and c.status = 'open'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
        and not public.is_blocked_with(
          case when m.participant_a = auth.uid() then m.participant_b else m.participant_a end
        )
    )
  );$homizi_20261011120100_109$,
    $homizi_20261011120100_110$create policy messages_insert_member on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.conversations c
      join public.matches m on m.id = c.match_id
      where c.id = conversation_id
        and c.status = 'open'
        and m.status = 'active'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
        and not public.is_blocked_with(
          case when m.participant_a = auth.uid() then m.participant_b else m.participant_a end
        )
    )
  );$homizi_20261011120100_110$,
    $homizi_20261011120100_111$create policy visits_participant on public.visit_requests
  for all to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  )
  with check (
    requester_id = auth.uid()
    and exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.status = 'active'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );$homizi_20261011120100_111$,
    $homizi_20261011120100_112$create policy notifications_recipient on public.notifications
  for select to authenticated
  using (user_id = auth.uid());$homizi_20261011120100_112$,
    $homizi_20261011120100_113$create policy notifications_mark_read on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());$homizi_20261011120100_113$,
    $homizi_20261011120100_114$create policy reports_insert_own on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open');$homizi_20261011120100_114$,
    $homizi_20261011120100_115$create policy reports_select_own on public.reports
  for select to authenticated
  using (reporter_id = auth.uid() or public.is_staff());$homizi_20261011120100_115$,
    $homizi_20261011120100_116$create policy blocks_own on public.blocks
  for all to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());$homizi_20261011120100_116$,
    $homizi_20261011120100_117$create policy staff_roles_select_self on public.staff_roles
  for select to authenticated
  using (user_id = auth.uid());$homizi_20261011120100_117$,
    $homizi_20261011120100_118$create policy subscriptions_select_own on public.subscriptions
  for select to authenticated
  using (user_id = auth.uid());$homizi_20261011120100_118$,
    $homizi_20261011120100_119$create policy payments_select_own on public.payments
  for select to authenticated
  using (user_id = auth.uid());$homizi_20261011120100_119$,
    $homizi_20261011120100_120$create policy consent_records_own on public.consent_records
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());$homizi_20261011120100_120$,
    $homizi_20261011120100_121$-- audit_events: RLS on, no policies. service_role bypasses RLS.

-- Listing photo bucket, when the storage schema is present in this database.
do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; listing-photos bucket skipped';
    return;
  end if;
  insert into storage.buckets (id, name, public)
  values ('listing-photos', 'listing-photos', false)
  on conflict (id) do nothing;
  execute 'drop policy if exists listing_photos_insert on storage.objects';
  execute 'drop policy if exists listing_photos_select on storage.objects';
  execute 'drop policy if exists listing_photos_update on storage.objects';
  execute 'drop policy if exists listing_photos_delete on storage.objects';
  execute $policy$
    create policy listing_photos_insert on storage.objects
    for insert to authenticated
    with check (
      bucket_id = 'listing-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
  execute $policy$
    create policy listing_photos_select on storage.objects
    for select to authenticated
    using (
      bucket_id = 'listing-photos'
      and (
        (storage.foldername(name))[1] = auth.uid()::text
        or exists (
          select 1
          from public.property_photos ph
          join public.properties p on p.id = ph.property_id
          where ph.storage_path = name
            and p.status = 'published'
        )
      )
    )
  $policy$;
  execute $policy$
    create policy listing_photos_update on storage.objects
    for update to authenticated
    using (
      bucket_id = 'listing-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
  execute $policy$
    create policy listing_photos_delete on storage.objects
    for delete to authenticated
    using (
      bucket_id = 'listing-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
exception
  when others then
    raise notice 'listing-photos storage policies skipped: %', sqlerrm;
end $$;$homizi_20261011120100_121$
  ]::text[]
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261011120200_test_helpers.sql
-- -------------------------------------------------------------------------

-- Local test helpers. Not granted to anon. The Data API does not expose the tests schema.
-- create_supabase_user inserts only columns that exist on auth.users so it survives
-- GoTrue schema differences. The password is a local fixture, not a production secret.

create schema if not exists tests;

create table if not exists tests.user_map (
  identifier text primary key,
  user_id uuid not null unique
);

revoke all on schema tests from public, anon, authenticated;

grant usage on schema tests to postgres, service_role;

create or replace function tests.create_supabase_user(
  p_identifier text,
  email text default null,
  phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = auth, public, extensions, tests
as $$
declare
  uid uuid := gen_random_uuid();
  v_email text := coalesce(email, p_identifier || '@example.test');
  cols text[] := array['id'];
  vals text[] := array[quote_literal(uid) || '::uuid'];
  colname text;
  token_cols text[] := array[
    'confirmation_token',
    'recovery_token',
    'email_change',
    'email_change_token',
    'email_change_token_new',
    'email_change_token_current',
    'reauthentication_token',
    'phone_change',
    'phone_change_token'
  ];
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'instance_id'
  ) then
    cols := array_append(cols, 'instance_id');
    vals := array_append(vals, quote_literal('00000000-0000-0000-0000-000000000000') || '::uuid');
  end if;

  cols := array_append(cols, 'email');
  vals := array_append(vals, quote_literal(v_email));

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'aud'
  ) then
    cols := array_append(cols, 'aud');
    vals := array_append(vals, quote_literal('authenticated'));
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'role'
  ) then
    cols := array_append(cols, 'role');
    vals := array_append(vals, quote_literal('authenticated'));
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'encrypted_password'
  ) then
    cols := array_append(cols, 'encrypted_password');
    vals := array_append(vals, quote_literal(extensions.crypt('local-dev-only', extensions.gen_salt('bf'))));
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_app_meta_data'
  ) then
    cols := array_append(cols, 'raw_app_meta_data');
    vals := array_append(vals, quote_literal('{"provider":"email","providers":["email"]}') || '::jsonb');
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_user_meta_data'
  ) then
    cols := array_append(cols, 'raw_user_meta_data');
    vals := array_append(vals, quote_literal('{}') || '::jsonb');
  end if;

  foreach colname in array ARRAY['email_confirmed_at', 'phone_confirmed_at', 'created_at', 'updated_at', 'last_sign_in_at']
  loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'auth' and table_name = 'users'
        and column_name = colname
        and is_generated = 'NEVER'
    ) then
      cols := array_append(cols, colname);
      vals := array_append(vals, 'now()');
    end if;
  end loop;

  if phone is not null and exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'phone'
  ) then
    cols := array_append(cols, 'phone');
    vals := array_append(vals, quote_literal(phone));
  end if;

  foreach colname in array token_cols
  loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'auth' and table_name = 'users'
        and column_name = colname
        and is_generated = 'NEVER'
    ) then
      cols := array_append(cols, colname);
      vals := array_append(vals, quote_literal(''));
    end if;
  end loop;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'is_sso_user'
  ) then
    cols := array_append(cols, 'is_sso_user');
    vals := array_append(vals, 'false');
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'is_anonymous'
  ) then
    cols := array_append(cols, 'is_anonymous');
    vals := array_append(vals, 'false');
  end if;

  execute format(
    'insert into auth.users (%s) values (%s)',
    array_to_string(cols, ', '),
    array_to_string(vals, ', ')
  );

  if to_regclass('auth.identities') is not null then
    begin
      execute format(
        'insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
         values (gen_random_uuid(), %L::uuid, %L::jsonb, ''email'', %L, now(), now(), now())',
        uid,
        json_build_object('sub', uid, 'email', v_email)::text,
        uid::text
      );
    exception
      when others then
        raise notice 'auth.identities insert skipped: %', sqlerrm;
    end;
  end if;

  insert into tests.user_map as mapped (identifier, user_id)
  values (p_identifier, uid)
  on conflict (identifier) do update set user_id = excluded.user_id;

  if phone is not null then
    update public.private_contacts
    set phone = create_supabase_user.phone
    where user_id = uid;
  end if;

  return uid;
end;
$$;

create or replace function tests.get_supabase_uid(p_identifier text)
returns uuid
language sql
stable
security definer
set search_path = tests, public
as $$
  select user_map.user_id
  from tests.user_map
  where user_map.identifier = p_identifier;
$$;

-- Sets the JWT claim only. Callers then `set local role authenticated`.
create or replace function tests.authenticate_as(p_identifier text)
returns void
language plpgsql
security definer
set search_path = tests, public
as $$
declare
  uid uuid;
begin
  uid := tests.get_supabase_uid(p_identifier);
  if uid is null then
    raise exception 'Unknown test user %', p_identifier;
  end if;
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
end;
$$;

create or replace function tests.clear_authentication()
returns void
language plpgsql
security definer
set search_path = tests, public
as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
end;
$$;

revoke all on all functions in schema tests from public, anon, authenticated;

grant execute on function tests.get_supabase_uid(text) to authenticated;

grant usage on schema tests to authenticated;



insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261011120200',
  'test_helpers',
  array[
    $homizi_20261011120200_1$-- Local test helpers. Not granted to anon. The Data API does not expose the tests schema.
-- create_supabase_user inserts only columns that exist on auth.users so it survives
-- GoTrue schema differences. The password is a local fixture, not a production secret.

create schema if not exists tests;$homizi_20261011120200_1$,
    $homizi_20261011120200_2$create table if not exists tests.user_map (
  identifier text primary key,
  user_id uuid not null unique
);$homizi_20261011120200_2$,
    $homizi_20261011120200_3$revoke all on schema tests from public, anon, authenticated;$homizi_20261011120200_3$,
    $homizi_20261011120200_4$grant usage on schema tests to postgres, service_role;$homizi_20261011120200_4$,
    $homizi_20261011120200_5$create or replace function tests.create_supabase_user(
  p_identifier text,
  email text default null,
  phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = auth, public, extensions, tests
as $$
declare
  uid uuid := gen_random_uuid();
  v_email text := coalesce(email, p_identifier || '@example.test');
  cols text[] := array['id'];
  vals text[] := array[quote_literal(uid) || '::uuid'];
  colname text;
  token_cols text[] := array[
    'confirmation_token',
    'recovery_token',
    'email_change',
    'email_change_token',
    'email_change_token_new',
    'email_change_token_current',
    'reauthentication_token',
    'phone_change',
    'phone_change_token'
  ];
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'instance_id'
  ) then
    cols := array_append(cols, 'instance_id');
    vals := array_append(vals, quote_literal('00000000-0000-0000-0000-000000000000') || '::uuid');
  end if;

  cols := array_append(cols, 'email');
  vals := array_append(vals, quote_literal(v_email));

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'aud'
  ) then
    cols := array_append(cols, 'aud');
    vals := array_append(vals, quote_literal('authenticated'));
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'role'
  ) then
    cols := array_append(cols, 'role');
    vals := array_append(vals, quote_literal('authenticated'));
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'encrypted_password'
  ) then
    cols := array_append(cols, 'encrypted_password');
    vals := array_append(vals, quote_literal(extensions.crypt('local-dev-only', extensions.gen_salt('bf'))));
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_app_meta_data'
  ) then
    cols := array_append(cols, 'raw_app_meta_data');
    vals := array_append(vals, quote_literal('{"provider":"email","providers":["email"]}') || '::jsonb');
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_user_meta_data'
  ) then
    cols := array_append(cols, 'raw_user_meta_data');
    vals := array_append(vals, quote_literal('{}') || '::jsonb');
  end if;

  foreach colname in array ARRAY['email_confirmed_at', 'phone_confirmed_at', 'created_at', 'updated_at', 'last_sign_in_at']
  loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'auth' and table_name = 'users'
        and column_name = colname
        and is_generated = 'NEVER'
    ) then
      cols := array_append(cols, colname);
      vals := array_append(vals, 'now()');
    end if;
  end loop;

  if phone is not null and exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'phone'
  ) then
    cols := array_append(cols, 'phone');
    vals := array_append(vals, quote_literal(phone));
  end if;

  foreach colname in array token_cols
  loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'auth' and table_name = 'users'
        and column_name = colname
        and is_generated = 'NEVER'
    ) then
      cols := array_append(cols, colname);
      vals := array_append(vals, quote_literal(''));
    end if;
  end loop;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'is_sso_user'
  ) then
    cols := array_append(cols, 'is_sso_user');
    vals := array_append(vals, 'false');
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'is_anonymous'
  ) then
    cols := array_append(cols, 'is_anonymous');
    vals := array_append(vals, 'false');
  end if;

  execute format(
    'insert into auth.users (%s) values (%s)',
    array_to_string(cols, ', '),
    array_to_string(vals, ', ')
  );

  if to_regclass('auth.identities') is not null then
    begin
      execute format(
        'insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
         values (gen_random_uuid(), %L::uuid, %L::jsonb, ''email'', %L, now(), now(), now())',
        uid,
        json_build_object('sub', uid, 'email', v_email)::text,
        uid::text
      );
    exception
      when others then
        raise notice 'auth.identities insert skipped: %', sqlerrm;
    end;
  end if;

  insert into tests.user_map as mapped (identifier, user_id)
  values (p_identifier, uid)
  on conflict (identifier) do update set user_id = excluded.user_id;

  if phone is not null then
    update public.private_contacts
    set phone = create_supabase_user.phone
    where user_id = uid;
  end if;

  return uid;
end;
$$;$homizi_20261011120200_5$,
    $homizi_20261011120200_6$create or replace function tests.get_supabase_uid(p_identifier text)
returns uuid
language sql
stable
security definer
set search_path = tests, public
as $$
  select user_map.user_id
  from tests.user_map
  where user_map.identifier = p_identifier;
$$;$homizi_20261011120200_6$,
    $homizi_20261011120200_7$-- Sets the JWT claim only. Callers then `set local role authenticated`.
create or replace function tests.authenticate_as(p_identifier text)
returns void
language plpgsql
security definer
set search_path = tests, public
as $$
declare
  uid uuid;
begin
  uid := tests.get_supabase_uid(p_identifier);
  if uid is null then
    raise exception 'Unknown test user %', p_identifier;
  end if;
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
end;
$$;$homizi_20261011120200_7$,
    $homizi_20261011120200_8$create or replace function tests.clear_authentication()
returns void
language plpgsql
security definer
set search_path = tests, public
as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
end;
$$;$homizi_20261011120200_8$,
    $homizi_20261011120200_9$revoke all on all functions in schema tests from public, anon, authenticated;$homizi_20261011120200_9$,
    $homizi_20261011120200_10$grant execute on function tests.get_supabase_uid(text) to authenticated;$homizi_20261011120200_10$,
    $homizi_20261011120200_11$grant usage on schema tests to authenticated;$homizi_20261011120200_11$
  ]::text[]
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261011120300_listing_photo_limits.sql
-- -------------------------------------------------------------------------

-- Keep listing photos private, small, and limited to image types.
-- Paths stay owner-scoped through the storage policies in the access migration.

do $$
begin
  if to_regclass('storage.buckets') is null then
    raise notice 'storage schema not present; listing-photos limits skipped';
    return;
  end if;

  update storage.buckets
  set
    public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
  where id = 'listing-photos';
end $$;



insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261011120300',
  'listing_photo_limits',
  array[
    $homizi_20261011120300_1$-- Keep listing photos private, small, and limited to image types.
-- Paths stay owner-scoped through the storage policies in the access migration.

do $$
begin
  if to_regclass('storage.buckets') is null then
    raise notice 'storage schema not present; listing-photos limits skipped';
    return;
  end if;

  update storage.buckets
  set
    public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
  where id = 'listing-photos';
end $$;$homizi_20261011120300_1$
  ]::text[]
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261011120400_chat_visits.sql
-- -------------------------------------------------------------------------

-- Chat and visit requests on the existing tables.
-- Clients can read a thread they belong to. They cannot put a phone number or
-- an email in a message, and they cannot set message or visit status themselves.

create or replace function public.contains_contact_text(p_body text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_lower text := lower(coalesce(p_body, ''));
  v_compact text;
begin
  if v_lower ~ '[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}' then
    return true;
  end if;
  v_compact := regexp_replace(v_lower, '[[:space:]\-().]', '', 'g');
  return v_compact ~ '(^|[^0-9])[0-9]{10,}([^0-9]|$)';
end;
$$;

alter table public.messages
  drop constraint if exists messages_no_contact;

alter table public.messages
  add constraint messages_no_contact
  check (not public.contains_contact_text(body));

create or replace function public.visit_slots_ok(p_slots jsonb)
returns boolean
language plpgsql
stable
set search_path = public
as $$
declare
  v_item jsonb;
  v_key text;
  v_count integer;
begin
  if p_slots is null or jsonb_typeof(p_slots) <> 'array' then
    return false;
  end if;
  v_count := jsonb_array_length(p_slots);
  if v_count < 1 or v_count > 3 then
    return false;
  end if;
  for v_item in select value from jsonb_array_elements(p_slots)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      return false;
    end if;
    if (select count(*) from jsonb_object_keys(v_item)) <> 1 then
      return false;
    end if;
    if not (v_item ? 'starts_at') then
      return false;
    end if;
    for v_key in select jsonb_object_keys(v_item)
    loop
      if v_key <> 'starts_at' then
        return false;
      end if;
    end loop;
    if public.contains_contact_text(v_item ->> 'starts_at') then
      return false;
    end if;
    begin
      perform (v_item ->> 'starts_at')::timestamptz;
    exception
      when others then
        return false;
    end;
  end loop;
  return true;
end;
$$;

create or replace function public.visit_requests_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.status := 'requested';
  end if;
  if not public.visit_slots_ok(new.proposed_slots) then
    raise exception 'visit slots cannot include contact details'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists visit_requests_guard on public.visit_requests;

drop trigger if exists visit_requests_guard on public.visit_requests;
create trigger visit_requests_guard
  before insert or update on public.visit_requests
  for each row
  execute function public.visit_requests_guard();

create or replace function public.open_conversation_for_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.conversations (match_id)
  values (new.id)
  on conflict (match_id) do nothing;
  return new;
end;
$$;

drop trigger if exists matches_open_conversation on public.matches;

drop trigger if exists matches_open_conversation on public.matches;
create trigger matches_open_conversation
  after insert on public.matches
  for each row
  execute function public.open_conversation_for_match();

insert into public.conversations (match_id)
select m.id
from public.matches m
where not exists (
  select 1 from public.conversations c where c.match_id = m.id
);

create or replace function public.open_conversation(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_match from public.matches where id = p_match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;
  insert into public.conversations (match_id)
  values (p_match_id)
  on conflict (match_id) do nothing;
  select id into v_id from public.conversations where match_id = p_match_id;
  return jsonb_build_object('ok', true, 'conversation_id', v_id);
end;
$$;

create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_body text := trim(coalesce(p_body, ''));
  v_conversation public.conversations;
  v_match public.matches;
  v_other uuid;
  v_id uuid;
  v_created timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 4000 then
    return jsonb_build_object('ok', false, 'error', 'body');
  end if;
  if public.contains_contact_text(v_body) then
    return jsonb_build_object('ok', false, 'error', 'contact');
  end if;
  select * into v_conversation
  from public.conversations
  where id = p_conversation_id;
  if not found or v_conversation.status <> 'open' then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  select * into v_match from public.matches where id = v_conversation.match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;
  insert into public.messages (conversation_id, sender_id, body)
  values (p_conversation_id, v_uid, v_body)
  returning id, created_at into v_id, v_created;
  return jsonb_build_object(
    'ok', true,
    'message_id', v_id,
    'created_at', v_created
  );
end;
$$;

create or replace function public.request_visit(
  p_match_id uuid,
  p_slots jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public.visit_slots_ok(p_slots) then
    return jsonb_build_object('ok', false, 'error', 'slots');
  end if;
  select * into v_match from public.matches where id = p_match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;
  insert into public.visit_requests (match_id, requester_id, proposed_slots)
  values (p_match_id, v_uid, p_slots)
  returning id into v_id;
  return jsonb_build_object(
    'ok', true,
    'visit_id', v_id,
    'status', 'requested'
  );
end;
$$;

create or replace function public.respond_visit(
  p_visit_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_visit public.visit_requests;
  v_match public.matches;
  v_next public.visit_status;
  v_updated integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_status not in ('accepted', 'declined', 'cancelled') then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  select * into v_visit from public.visit_requests where id = p_visit_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  select * into v_match from public.matches where id = v_visit.match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  if v_visit.status <> 'requested' then
    return jsonb_build_object('ok', false, 'error', 'closed');
  end if;
  if p_status = 'cancelled' and v_uid <> v_visit.requester_id then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  if p_status in ('accepted', 'declined') and v_uid = v_visit.requester_id then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  v_next := p_status::public.visit_status;
  update public.visit_requests
  set status = v_next
  where id = p_visit_id
    and status = 'requested';
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    return jsonb_build_object('ok', false, 'error', 'closed');
  end if;
  return jsonb_build_object(
    'ok', true,
    'visit_id', p_visit_id,
    'status', p_status
  );
end;
$$;

comment on function public.send_message(uuid, text) is
  'Stores a chat message for an active match. Refuses phone numbers and email addresses. Does not return contact fields.';

comment on function public.request_visit(uuid, jsonb) is
  'Creates a visit request with one to three start times. Slots cannot carry contact fields or a street address.';

comment on function public.respond_visit(uuid, text) is
  'The other participant accepts or declines. The requester can cancel. No address is returned.';

revoke insert on public.messages from authenticated;

grant insert (conversation_id, sender_id, body)
  on public.messages to authenticated;

revoke insert, update on public.visit_requests from authenticated;

revoke all on function public.contains_contact_text(text) from public, anon;

revoke all on function public.visit_slots_ok(jsonb) from public, anon;

revoke all on function public.open_conversation(uuid) from public, anon;

revoke all on function public.send_message(uuid, text) from public, anon;

revoke all on function public.request_visit(uuid, jsonb) from public, anon;

revoke all on function public.respond_visit(uuid, text) from public, anon;

grant execute on function public.contains_contact_text(text) to authenticated;

grant execute on function public.visit_slots_ok(jsonb) to authenticated;

grant execute on function public.open_conversation(uuid) to authenticated;

grant execute on function public.send_message(uuid, text) to authenticated;

grant execute on function public.request_visit(uuid, jsonb) to authenticated;

grant execute on function public.respond_visit(uuid, text) to authenticated;

drop policy if exists messages_select_member on public.messages;

drop policy if exists messages_select_member on public.messages;
create policy messages_select_member on public.messages
  for select to authenticated
  using (
    status = 'sent'
    and exists (
      select 1
      from public.conversations c
      join public.matches m on m.id = c.match_id
      where c.id = conversation_id
        and c.status = 'open'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
        and not public.is_blocked_with(
          case
            when m.participant_a = auth.uid() then m.participant_b
            else m.participant_a
          end
        )
    )
  );



insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261011120400',
  'chat_visits',
  array[
    $homizi_20261011120400_1$-- Chat and visit requests on the existing tables.
-- Clients can read a thread they belong to. They cannot put a phone number or
-- an email in a message, and they cannot set message or visit status themselves.

create or replace function public.contains_contact_text(p_body text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_lower text := lower(coalesce(p_body, ''));
  v_compact text;
begin
  if v_lower ~ '[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}' then
    return true;
  end if;
  v_compact := regexp_replace(v_lower, '[[:space:]\-().]', '', 'g');
  return v_compact ~ '(^|[^0-9])[0-9]{10,}([^0-9]|$)';
end;
$$;$homizi_20261011120400_1$,
    $homizi_20261011120400_2$alter table public.messages
  drop constraint if exists messages_no_contact;$homizi_20261011120400_2$,
    $homizi_20261011120400_3$alter table public.messages
  add constraint messages_no_contact
  check (not public.contains_contact_text(body));$homizi_20261011120400_3$,
    $homizi_20261011120400_4$create or replace function public.visit_slots_ok(p_slots jsonb)
returns boolean
language plpgsql
stable
set search_path = public
as $$
declare
  v_item jsonb;
  v_key text;
  v_count integer;
begin
  if p_slots is null or jsonb_typeof(p_slots) <> 'array' then
    return false;
  end if;
  v_count := jsonb_array_length(p_slots);
  if v_count < 1 or v_count > 3 then
    return false;
  end if;
  for v_item in select value from jsonb_array_elements(p_slots)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      return false;
    end if;
    if (select count(*) from jsonb_object_keys(v_item)) <> 1 then
      return false;
    end if;
    if not (v_item ? 'starts_at') then
      return false;
    end if;
    for v_key in select jsonb_object_keys(v_item)
    loop
      if v_key <> 'starts_at' then
        return false;
      end if;
    end loop;
    if public.contains_contact_text(v_item ->> 'starts_at') then
      return false;
    end if;
    begin
      perform (v_item ->> 'starts_at')::timestamptz;
    exception
      when others then
        return false;
    end;
  end loop;
  return true;
end;
$$;$homizi_20261011120400_4$,
    $homizi_20261011120400_5$create or replace function public.visit_requests_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.status := 'requested';
  end if;
  if not public.visit_slots_ok(new.proposed_slots) then
    raise exception 'visit slots cannot include contact details'
      using errcode = '42501';
  end if;
  return new;
end;
$$;$homizi_20261011120400_5$,
    $homizi_20261011120400_6$drop trigger if exists visit_requests_guard on public.visit_requests;$homizi_20261011120400_6$,
    $homizi_20261011120400_7$create trigger visit_requests_guard
  before insert or update on public.visit_requests
  for each row
  execute function public.visit_requests_guard();$homizi_20261011120400_7$,
    $homizi_20261011120400_8$create or replace function public.open_conversation_for_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.conversations (match_id)
  values (new.id)
  on conflict (match_id) do nothing;
  return new;
end;
$$;$homizi_20261011120400_8$,
    $homizi_20261011120400_9$drop trigger if exists matches_open_conversation on public.matches;$homizi_20261011120400_9$,
    $homizi_20261011120400_10$create trigger matches_open_conversation
  after insert on public.matches
  for each row
  execute function public.open_conversation_for_match();$homizi_20261011120400_10$,
    $homizi_20261011120400_11$insert into public.conversations (match_id)
select m.id
from public.matches m
where not exists (
  select 1 from public.conversations c where c.match_id = m.id
);$homizi_20261011120400_11$,
    $homizi_20261011120400_12$create or replace function public.open_conversation(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_match from public.matches where id = p_match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;
  insert into public.conversations (match_id)
  values (p_match_id)
  on conflict (match_id) do nothing;
  select id into v_id from public.conversations where match_id = p_match_id;
  return jsonb_build_object('ok', true, 'conversation_id', v_id);
end;
$$;$homizi_20261011120400_12$,
    $homizi_20261011120400_13$create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_body text := trim(coalesce(p_body, ''));
  v_conversation public.conversations;
  v_match public.matches;
  v_other uuid;
  v_id uuid;
  v_created timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 4000 then
    return jsonb_build_object('ok', false, 'error', 'body');
  end if;
  if public.contains_contact_text(v_body) then
    return jsonb_build_object('ok', false, 'error', 'contact');
  end if;
  select * into v_conversation
  from public.conversations
  where id = p_conversation_id;
  if not found or v_conversation.status <> 'open' then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  select * into v_match from public.matches where id = v_conversation.match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;
  insert into public.messages (conversation_id, sender_id, body)
  values (p_conversation_id, v_uid, v_body)
  returning id, created_at into v_id, v_created;
  return jsonb_build_object(
    'ok', true,
    'message_id', v_id,
    'created_at', v_created
  );
end;
$$;$homizi_20261011120400_13$,
    $homizi_20261011120400_14$create or replace function public.request_visit(
  p_match_id uuid,
  p_slots jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public.visit_slots_ok(p_slots) then
    return jsonb_build_object('ok', false, 'error', 'slots');
  end if;
  select * into v_match from public.matches where id = p_match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;
  insert into public.visit_requests (match_id, requester_id, proposed_slots)
  values (p_match_id, v_uid, p_slots)
  returning id into v_id;
  return jsonb_build_object(
    'ok', true,
    'visit_id', v_id,
    'status', 'requested'
  );
end;
$$;$homizi_20261011120400_14$,
    $homizi_20261011120400_15$create or replace function public.respond_visit(
  p_visit_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_visit public.visit_requests;
  v_match public.matches;
  v_next public.visit_status;
  v_updated integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_status not in ('accepted', 'declined', 'cancelled') then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  select * into v_visit from public.visit_requests where id = p_visit_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  select * into v_match from public.matches where id = v_visit.match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  if v_visit.status <> 'requested' then
    return jsonb_build_object('ok', false, 'error', 'closed');
  end if;
  if p_status = 'cancelled' and v_uid <> v_visit.requester_id then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  if p_status in ('accepted', 'declined') and v_uid = v_visit.requester_id then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  v_next := p_status::public.visit_status;
  update public.visit_requests
  set status = v_next
  where id = p_visit_id
    and status = 'requested';
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    return jsonb_build_object('ok', false, 'error', 'closed');
  end if;
  return jsonb_build_object(
    'ok', true,
    'visit_id', p_visit_id,
    'status', p_status
  );
end;
$$;$homizi_20261011120400_15$,
    $homizi_20261011120400_16$comment on function public.send_message(uuid, text) is
  'Stores a chat message for an active match. Refuses phone numbers and email addresses. Does not return contact fields.';$homizi_20261011120400_16$,
    $homizi_20261011120400_17$comment on function public.request_visit(uuid, jsonb) is
  'Creates a visit request with one to three start times. Slots cannot carry contact fields or a street address.';$homizi_20261011120400_17$,
    $homizi_20261011120400_18$comment on function public.respond_visit(uuid, text) is
  'The other participant accepts or declines. The requester can cancel. No address is returned.';$homizi_20261011120400_18$,
    $homizi_20261011120400_19$revoke insert on public.messages from authenticated;$homizi_20261011120400_19$,
    $homizi_20261011120400_20$grant insert (conversation_id, sender_id, body)
  on public.messages to authenticated;$homizi_20261011120400_20$,
    $homizi_20261011120400_21$revoke insert, update on public.visit_requests from authenticated;$homizi_20261011120400_21$,
    $homizi_20261011120400_22$revoke all on function public.contains_contact_text(text) from public, anon;$homizi_20261011120400_22$,
    $homizi_20261011120400_23$revoke all on function public.visit_slots_ok(jsonb) from public, anon;$homizi_20261011120400_23$,
    $homizi_20261011120400_24$revoke all on function public.open_conversation(uuid) from public, anon;$homizi_20261011120400_24$,
    $homizi_20261011120400_25$revoke all on function public.send_message(uuid, text) from public, anon;$homizi_20261011120400_25$,
    $homizi_20261011120400_26$revoke all on function public.request_visit(uuid, jsonb) from public, anon;$homizi_20261011120400_26$,
    $homizi_20261011120400_27$revoke all on function public.respond_visit(uuid, text) from public, anon;$homizi_20261011120400_27$,
    $homizi_20261011120400_28$grant execute on function public.contains_contact_text(text) to authenticated;$homizi_20261011120400_28$,
    $homizi_20261011120400_29$grant execute on function public.visit_slots_ok(jsonb) to authenticated;$homizi_20261011120400_29$,
    $homizi_20261011120400_30$grant execute on function public.open_conversation(uuid) to authenticated;$homizi_20261011120400_30$,
    $homizi_20261011120400_31$grant execute on function public.send_message(uuid, text) to authenticated;$homizi_20261011120400_31$,
    $homizi_20261011120400_32$grant execute on function public.request_visit(uuid, jsonb) to authenticated;$homizi_20261011120400_32$,
    $homizi_20261011120400_33$grant execute on function public.respond_visit(uuid, text) to authenticated;$homizi_20261011120400_33$,
    $homizi_20261011120400_34$drop policy if exists messages_select_member on public.messages;$homizi_20261011120400_34$,
    $homizi_20261011120400_35$create policy messages_select_member on public.messages
  for select to authenticated
  using (
    status = 'sent'
    and exists (
      select 1
      from public.conversations c
      join public.matches m on m.id = c.match_id
      where c.id = conversation_id
        and c.status = 'open'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
        and not public.is_blocked_with(
          case
            when m.participant_a = auth.uid() then m.participant_b
            else m.participant_a
          end
        )
    )
  );$homizi_20261011120400_35$
  ]::text[]
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261011120500_notifications.sql
-- -------------------------------------------------------------------------

-- In-app notifications for matches, messages, and visits.
-- Clients may read their own rows and set read_at. They cannot insert a
-- notification or change its type or payload. Payloads are ids only.

-- Ids only. A UUID can contain a long digit run, so the check is the UUID
-- shape rather than a phone-number scan of the whole value.
alter table public.notifications
  drop constraint if exists notifications_payload;

alter table public.notifications
  add constraint notifications_payload check (
    jsonb_typeof(payload_minimal) = 'object'
    and payload_minimal ? 'match_id'
    and (payload_minimal - 'match_id' - 'visit_id' - 'conversation_id')
      = '{}'::jsonb
    and (payload_minimal ->> 'match_id')
      ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    and (
      not (payload_minimal ? 'visit_id')
      or (payload_minimal ->> 'visit_id')
        ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    )
    and (
      not (payload_minimal ? 'conversation_id')
      or (payload_minimal ->> 'conversation_id')
        ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    )
  );

alter table public.notifications
  drop constraint if exists notifications_type;

alter table public.notifications
  add constraint notifications_type check (
    type in (
      'match',
      'message',
      'visit_requested',
      'visit_accepted',
      'visit_declined',
      'visit_cancelled'
    )
  );

create or replace function public.notification_payload_ok(p_payload jsonb)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_key text;
  v_value text;
  v_type text;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return false;
  end if;
  if (
    p_payload ? 'phone'
    or p_payload ? 'email'
    or p_payload ? 'aadhaar'
    or p_payload ? 'address_line'
    or p_payload ? 'landmark'
    or p_payload ? 'latitude'
    or p_payload ? 'longitude'
    or p_payload ? 'street_address'
  ) then
    return false;
  end if;
  for v_key in select jsonb_object_keys(p_payload)
  loop
    if v_key not in ('match_id', 'visit_id', 'conversation_id') then
      return false;
    end if;
    v_type := jsonb_typeof(p_payload -> v_key);
    if v_type <> 'string' then
      return false;
    end if;
    v_value := p_payload ->> v_key;
    if v_value !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      return false;
    end if;
  end loop;
  return p_payload ? 'match_id';
end;
$$;

create or replace function public.enqueue_notification(
  p_user_id uuid,
  p_type text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;
  if p_type not in (
    'match',
    'message',
    'visit_requested',
    'visit_accepted',
    'visit_declined',
    'visit_cancelled'
  ) then
    return;
  end if;
  if not public.notification_payload_ok(p_payload) then
    return;
  end if;
  insert into public.notifications (user_id, type, payload_minimal)
  values (p_user_id, p_type, p_payload);
end;
$$;

create or replace function public.notify_on_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payload jsonb;
begin
  if new.status <> 'active' then
    return new;
  end if;
  v_payload := jsonb_build_object('match_id', new.id);
  perform public.enqueue_notification(new.participant_a, 'match', v_payload);
  perform public.enqueue_notification(new.participant_b, 'match', v_payload);
  return new;
end;
$$;

create or replace function public.notify_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_id uuid;
  v_a uuid;
  v_b uuid;
  v_recipient uuid;
begin
  if new.status <> 'sent' then
    return new;
  end if;
  select c.match_id, m.participant_a, m.participant_b
    into v_match_id, v_a, v_b
  from public.conversations c
  join public.matches m on m.id = c.match_id
  where c.id = new.conversation_id;
  if v_match_id is null then
    return new;
  end if;
  v_recipient := case
    when new.sender_id = v_a then v_b
    else v_a
  end;
  if v_recipient = new.sender_id then
    return new;
  end if;
  perform public.enqueue_notification(
    v_recipient,
    'message',
    jsonb_build_object(
      'match_id', v_match_id,
      'conversation_id', new.conversation_id
    )
  );
  return new;
end;
$$;

create or replace function public.notify_on_visit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_a uuid;
  v_b uuid;
  v_other uuid;
  v_type text;
  v_recipient uuid;
begin
  select participant_a, participant_b
    into v_a, v_b
  from public.matches
  where id = new.match_id;
  if v_a is null then
    return new;
  end if;
  v_other := case
    when new.requester_id = v_a then v_b
    else v_a
  end;

  if tg_op = 'INSERT' then
    perform public.enqueue_notification(
      v_other,
      'visit_requested',
      jsonb_build_object('match_id', new.match_id, 'visit_id', new.id)
    );
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;
  end if;
  v_type := case new.status
    when 'accepted' then 'visit_accepted'
    when 'declined' then 'visit_declined'
    when 'cancelled' then 'visit_cancelled'
    else null
  end;
  if v_type is null then
    return new;
  end if;
  v_recipient := case
    when new.status = 'cancelled' then v_other
    else new.requester_id
  end;
  perform public.enqueue_notification(
    v_recipient,
    v_type,
    jsonb_build_object('match_id', new.match_id, 'visit_id', new.id)
  );
  return new;
end;
$$;

drop trigger if exists notifications_on_match on public.matches;

drop trigger if exists notifications_on_match on public.matches;
create trigger notifications_on_match
  after insert on public.matches
  for each row
  execute function public.notify_on_match();

drop trigger if exists notifications_on_message on public.messages;

drop trigger if exists notifications_on_message on public.messages;
create trigger notifications_on_message
  after insert on public.messages
  for each row
  execute function public.notify_on_message();

drop trigger if exists notifications_on_visit on public.visit_requests;

drop trigger if exists notifications_on_visit on public.visit_requests;
create trigger notifications_on_visit
  after insert or update of status on public.visit_requests
  for each row
  execute function public.notify_on_visit();

insert into public.notifications (user_id, type, payload_minimal)
select m.participant_a, 'match', jsonb_build_object('match_id', m.id)
from public.matches m
where m.status = 'active'
  and not exists (
    select 1
    from public.notifications n
    where n.user_id = m.participant_a
      and n.type = 'match'
      and n.payload_minimal ->> 'match_id' = m.id::text
  )
union all
select m.participant_b, 'match', jsonb_build_object('match_id', m.id)
from public.matches m
where m.status = 'active'
  and not exists (
    select 1
    from public.notifications n
    where n.user_id = m.participant_b
      and n.type = 'match'
      and n.payload_minimal ->> 'match_id' = m.id::text
  );

revoke all on function public.notification_payload_ok(jsonb) from public, anon, authenticated;

revoke all on function public.enqueue_notification(uuid, text, jsonb) from public, anon, authenticated;

revoke all on function public.notify_on_match() from public, anon, authenticated;

revoke all on function public.notify_on_message() from public, anon, authenticated;

revoke all on function public.notify_on_visit() from public, anon, authenticated;

grant execute on function public.notification_payload_ok(jsonb) to authenticated;



insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261011120500',
  'notifications',
  array[
    $homizi_20261011120500_1$-- In-app notifications for matches, messages, and visits.
-- Clients may read their own rows and set read_at. They cannot insert a
-- notification or change its type or payload. Payloads are ids only.

-- Ids only. A UUID can contain a long digit run, so the check is the UUID
-- shape rather than a phone-number scan of the whole value.
alter table public.notifications
  drop constraint if exists notifications_payload;$homizi_20261011120500_1$,
    $homizi_20261011120500_2$alter table public.notifications
  add constraint notifications_payload check (
    jsonb_typeof(payload_minimal) = 'object'
    and payload_minimal ? 'match_id'
    and (payload_minimal - 'match_id' - 'visit_id' - 'conversation_id')
      = '{}'::jsonb
    and (payload_minimal ->> 'match_id')
      ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    and (
      not (payload_minimal ? 'visit_id')
      or (payload_minimal ->> 'visit_id')
        ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    )
    and (
      not (payload_minimal ? 'conversation_id')
      or (payload_minimal ->> 'conversation_id')
        ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    )
  );$homizi_20261011120500_2$,
    $homizi_20261011120500_3$alter table public.notifications
  drop constraint if exists notifications_type;$homizi_20261011120500_3$,
    $homizi_20261011120500_4$alter table public.notifications
  add constraint notifications_type check (
    type in (
      'match',
      'message',
      'visit_requested',
      'visit_accepted',
      'visit_declined',
      'visit_cancelled'
    )
  );$homizi_20261011120500_4$,
    $homizi_20261011120500_5$create or replace function public.notification_payload_ok(p_payload jsonb)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_key text;
  v_value text;
  v_type text;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return false;
  end if;
  if (
    p_payload ? 'phone'
    or p_payload ? 'email'
    or p_payload ? 'aadhaar'
    or p_payload ? 'address_line'
    or p_payload ? 'landmark'
    or p_payload ? 'latitude'
    or p_payload ? 'longitude'
    or p_payload ? 'street_address'
  ) then
    return false;
  end if;
  for v_key in select jsonb_object_keys(p_payload)
  loop
    if v_key not in ('match_id', 'visit_id', 'conversation_id') then
      return false;
    end if;
    v_type := jsonb_typeof(p_payload -> v_key);
    if v_type <> 'string' then
      return false;
    end if;
    v_value := p_payload ->> v_key;
    if v_value !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      return false;
    end if;
  end loop;
  return p_payload ? 'match_id';
end;
$$;$homizi_20261011120500_5$,
    $homizi_20261011120500_6$create or replace function public.enqueue_notification(
  p_user_id uuid,
  p_type text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;
  if p_type not in (
    'match',
    'message',
    'visit_requested',
    'visit_accepted',
    'visit_declined',
    'visit_cancelled'
  ) then
    return;
  end if;
  if not public.notification_payload_ok(p_payload) then
    return;
  end if;
  insert into public.notifications (user_id, type, payload_minimal)
  values (p_user_id, p_type, p_payload);
end;
$$;$homizi_20261011120500_6$,
    $homizi_20261011120500_7$create or replace function public.notify_on_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payload jsonb;
begin
  if new.status <> 'active' then
    return new;
  end if;
  v_payload := jsonb_build_object('match_id', new.id);
  perform public.enqueue_notification(new.participant_a, 'match', v_payload);
  perform public.enqueue_notification(new.participant_b, 'match', v_payload);
  return new;
end;
$$;$homizi_20261011120500_7$,
    $homizi_20261011120500_8$create or replace function public.notify_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_id uuid;
  v_a uuid;
  v_b uuid;
  v_recipient uuid;
begin
  if new.status <> 'sent' then
    return new;
  end if;
  select c.match_id, m.participant_a, m.participant_b
    into v_match_id, v_a, v_b
  from public.conversations c
  join public.matches m on m.id = c.match_id
  where c.id = new.conversation_id;
  if v_match_id is null then
    return new;
  end if;
  v_recipient := case
    when new.sender_id = v_a then v_b
    else v_a
  end;
  if v_recipient = new.sender_id then
    return new;
  end if;
  perform public.enqueue_notification(
    v_recipient,
    'message',
    jsonb_build_object(
      'match_id', v_match_id,
      'conversation_id', new.conversation_id
    )
  );
  return new;
end;
$$;$homizi_20261011120500_8$,
    $homizi_20261011120500_9$create or replace function public.notify_on_visit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_a uuid;
  v_b uuid;
  v_other uuid;
  v_type text;
  v_recipient uuid;
begin
  select participant_a, participant_b
    into v_a, v_b
  from public.matches
  where id = new.match_id;
  if v_a is null then
    return new;
  end if;
  v_other := case
    when new.requester_id = v_a then v_b
    else v_a
  end;

  if tg_op = 'INSERT' then
    perform public.enqueue_notification(
      v_other,
      'visit_requested',
      jsonb_build_object('match_id', new.match_id, 'visit_id', new.id)
    );
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;
  end if;
  v_type := case new.status
    when 'accepted' then 'visit_accepted'
    when 'declined' then 'visit_declined'
    when 'cancelled' then 'visit_cancelled'
    else null
  end;
  if v_type is null then
    return new;
  end if;
  v_recipient := case
    when new.status = 'cancelled' then v_other
    else new.requester_id
  end;
  perform public.enqueue_notification(
    v_recipient,
    v_type,
    jsonb_build_object('match_id', new.match_id, 'visit_id', new.id)
  );
  return new;
end;
$$;$homizi_20261011120500_9$,
    $homizi_20261011120500_10$drop trigger if exists notifications_on_match on public.matches;$homizi_20261011120500_10$,
    $homizi_20261011120500_11$create trigger notifications_on_match
  after insert on public.matches
  for each row
  execute function public.notify_on_match();$homizi_20261011120500_11$,
    $homizi_20261011120500_12$drop trigger if exists notifications_on_message on public.messages;$homizi_20261011120500_12$,
    $homizi_20261011120500_13$create trigger notifications_on_message
  after insert on public.messages
  for each row
  execute function public.notify_on_message();$homizi_20261011120500_13$,
    $homizi_20261011120500_14$drop trigger if exists notifications_on_visit on public.visit_requests;$homizi_20261011120500_14$,
    $homizi_20261011120500_15$create trigger notifications_on_visit
  after insert or update of status on public.visit_requests
  for each row
  execute function public.notify_on_visit();$homizi_20261011120500_15$,
    $homizi_20261011120500_16$insert into public.notifications (user_id, type, payload_minimal)
select m.participant_a, 'match', jsonb_build_object('match_id', m.id)
from public.matches m
where m.status = 'active'
  and not exists (
    select 1
    from public.notifications n
    where n.user_id = m.participant_a
      and n.type = 'match'
      and n.payload_minimal ->> 'match_id' = m.id::text
  )
union all
select m.participant_b, 'match', jsonb_build_object('match_id', m.id)
from public.matches m
where m.status = 'active'
  and not exists (
    select 1
    from public.notifications n
    where n.user_id = m.participant_b
      and n.type = 'match'
      and n.payload_minimal ->> 'match_id' = m.id::text
  );$homizi_20261011120500_16$,
    $homizi_20261011120500_17$revoke all on function public.notification_payload_ok(jsonb) from public, anon, authenticated;$homizi_20261011120500_17$,
    $homizi_20261011120500_18$revoke all on function public.enqueue_notification(uuid, text, jsonb) from public, anon, authenticated;$homizi_20261011120500_18$,
    $homizi_20261011120500_19$revoke all on function public.notify_on_match() from public, anon, authenticated;$homizi_20261011120500_19$,
    $homizi_20261011120500_20$revoke all on function public.notify_on_message() from public, anon, authenticated;$homizi_20261011120500_20$,
    $homizi_20261011120500_21$revoke all on function public.notify_on_visit() from public, anon, authenticated;$homizi_20261011120500_21$,
    $homizi_20261011120500_22$grant execute on function public.notification_payload_ok(jsonb) to authenticated;$homizi_20261011120500_22$
  ]::text[]
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261011120600_safety_deletion.sql
-- -------------------------------------------------------------------------

-- Report details cannot carry a phone or an email. Account deletion removes
-- the signed-in person on this database. It does not call an outside vendor.

alter table public.reports
  drop constraint if exists reports_details_no_contact;

alter table public.reports
  add constraint reports_details_no_contact check (
    details is null or not public.contains_contact_text(details)
  );

create or replace function public.delete_own_account()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  if to_regclass('storage.objects') is not null then
    begin
      delete from storage.objects
      where bucket_id = 'listing-photos'
        and split_part(name, '/', 1) = v_uid::text;
    exception
      when others then
        null;
    end;
  end if;

  delete from public.reports
  where reporter_id = v_uid
     or target_id = v_uid
     or target_id in (
       select id from public.properties where host_user_id = v_uid
     )
     or target_id in (
       select id from public.listing_requirements where user_id = v_uid
     )
     or target_id in (
       select m.id
       from public.messages m
       join public.conversations c on c.id = m.conversation_id
       join public.matches mt on mt.id = c.match_id
       where mt.participant_a = v_uid or mt.participant_b = v_uid
     );

  delete from public.notifications
  where user_id <> v_uid
    and payload_minimal ->> 'match_id' in (
      select id::text
      from public.matches
      where participant_a = v_uid or participant_b = v_uid
    );

  delete from public.interests
  where (
    target_type = 'user' and target_id = v_uid
  ) or (
    target_type = 'property'
    and target_id in (select id from public.properties where host_user_id = v_uid)
  ) or (
    target_type = 'listing_requirement'
    and target_id in (
      select id from public.listing_requirements where user_id = v_uid
    )
  );

  delete from public.matches
  where participant_a = v_uid or participant_b = v_uid;

  delete from public.properties
  where host_user_id = v_uid;

  delete from auth.users
  where id = v_uid;

  return jsonb_build_object('ok', true);
end;
$$;

comment on function public.delete_own_account() is
  'Deletes the signed-in account, their listings, messages, and private contact row on this database. Does not return contact fields.';

revoke all on function public.delete_own_account() from public, anon, authenticated;

grant execute on function public.delete_own_account() to authenticated;



insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261011120600',
  'safety_deletion',
  array[
    $homizi_20261011120600_1$-- Report details cannot carry a phone or an email. Account deletion removes
-- the signed-in person on this database. It does not call an outside vendor.

alter table public.reports
  drop constraint if exists reports_details_no_contact;$homizi_20261011120600_1$,
    $homizi_20261011120600_2$alter table public.reports
  add constraint reports_details_no_contact check (
    details is null or not public.contains_contact_text(details)
  );$homizi_20261011120600_2$,
    $homizi_20261011120600_3$create or replace function public.delete_own_account()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  if to_regclass('storage.objects') is not null then
    begin
      delete from storage.objects
      where bucket_id = 'listing-photos'
        and split_part(name, '/', 1) = v_uid::text;
    exception
      when others then
        null;
    end;
  end if;

  delete from public.reports
  where reporter_id = v_uid
     or target_id = v_uid
     or target_id in (
       select id from public.properties where host_user_id = v_uid
     )
     or target_id in (
       select id from public.listing_requirements where user_id = v_uid
     )
     or target_id in (
       select m.id
       from public.messages m
       join public.conversations c on c.id = m.conversation_id
       join public.matches mt on mt.id = c.match_id
       where mt.participant_a = v_uid or mt.participant_b = v_uid
     );

  delete from public.notifications
  where user_id <> v_uid
    and payload_minimal ->> 'match_id' in (
      select id::text
      from public.matches
      where participant_a = v_uid or participant_b = v_uid
    );

  delete from public.interests
  where (
    target_type = 'user' and target_id = v_uid
  ) or (
    target_type = 'property'
    and target_id in (select id from public.properties where host_user_id = v_uid)
  ) or (
    target_type = 'listing_requirement'
    and target_id in (
      select id from public.listing_requirements where user_id = v_uid
    )
  );

  delete from public.matches
  where participant_a = v_uid or participant_b = v_uid;

  delete from public.properties
  where host_user_id = v_uid;

  delete from auth.users
  where id = v_uid;

  return jsonb_build_object('ok', true);
end;
$$;$homizi_20261011120600_3$,
    $homizi_20261011120600_4$comment on function public.delete_own_account() is
  'Deletes the signed-in account, their listings, messages, and private contact row on this database. Does not return contact fields.';$homizi_20261011120600_4$,
    $homizi_20261011120600_5$revoke all on function public.delete_own_account() from public, anon, authenticated;$homizi_20261011120600_5$,
    $homizi_20261011120600_6$grant execute on function public.delete_own_account() to authenticated;$homizi_20261011120600_6$
  ]::text[]
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261014170000_score_compatibility.sql
-- -------------------------------------------------------------------------

-- PD-06 scoring on the server. Budget, city, locality, furnishing, property type.
-- Gender, religion, caste, age, and marital status are not arguments.

create or replace function public.score_compatibility(
  p_rent_inr integer,
  p_city text,
  p_locality text,
  p_furnishing text,
  p_property_type text,
  p_budget_min_inr integer,
  p_budget_max_inr integer,
  p_pref_city text,
  p_pref_locality text default null,
  p_pref_furnishing text default null,
  p_pref_property_type text default null
)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_score integer := 0;
  v_reasons jsonb := '[]'::jsonb;
  v_budget integer := 0;
  v_bound integer;
  v_delta numeric;
  v_wanted text;
begin
  if p_rent_inr is not null
     and p_budget_min_inr is not null
     and p_budget_max_inr is not null
     and p_rent_inr >= p_budget_min_inr
     and p_rent_inr <= p_budget_max_inr then
    v_budget := 40;
    v_reasons := v_reasons || jsonb_build_array('Rent sits inside your budget.');
  else
    if p_rent_inr is null
       or p_budget_min_inr is null
       or p_budget_max_inr is null then
      v_budget := 0;
    else
      v_bound := case
        when p_rent_inr < p_budget_min_inr then p_budget_min_inr
        else p_budget_max_inr
      end;
      if v_bound = 0 then
        v_budget := 0;
      else
        v_delta := abs(p_rent_inr - v_bound)::numeric / v_bound;
        v_budget := case when v_delta <= 0.20 then 15 else 0 end;
      end if;
    end if;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when v_budget = 15 then 'Rent is close to your budget.'
        else 'Rent is outside your budget.'
      end
    );
  end if;
  v_score := v_score + v_budget;

  if lower(btrim(coalesce(p_pref_city, ''))) = lower(btrim(coalesce(p_city, '')))
     and btrim(coalesce(p_pref_city, '')) <> '' then
    v_score := v_score + 25;
    v_reasons := v_reasons || jsonb_build_array('City matches ' || btrim(p_city) || '.');
  else
    v_reasons := v_reasons || jsonb_build_array(
      'City does not match ' || btrim(coalesce(p_pref_city, '')) || '.'
    );
  end if;

  v_wanted := btrim(coalesce(p_pref_locality, ''));
  if v_wanted = ''
     or lower(v_wanted) = lower(btrim(coalesce(p_locality, ''))) then
    v_score := v_score + 15;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when v_wanted = '' then 'No locality preference set.'
        else 'Locality matches ' || btrim(coalesce(p_locality, '')) || '.'
      end
    );
  else
    v_reasons := v_reasons || jsonb_build_array('Locality does not match ' || v_wanted || '.');
  end if;

  if p_pref_furnishing is null
     or btrim(p_pref_furnishing) = ''
     or lower(btrim(p_pref_furnishing)) = lower(btrim(coalesce(p_furnishing, ''))) then
    v_score := v_score + 10;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when p_pref_furnishing is null or btrim(p_pref_furnishing) = ''
          then 'No furnishing preference set.'
        else 'Furnishing matches.'
      end
    );
  else
    v_reasons := v_reasons || jsonb_build_array('Furnishing does not match.');
  end if;

  if p_pref_property_type is null
     or btrim(p_pref_property_type) = ''
     or lower(btrim(p_pref_property_type)) = lower(btrim(coalesce(p_property_type, ''))) then
    v_score := v_score + 10;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when p_pref_property_type is null or btrim(p_pref_property_type) = ''
          then 'No property type preference set.'
        else 'Property type matches.'
      end
    );
  else
    v_reasons := v_reasons || jsonb_build_array('Property type does not match.');
  end if;

  return jsonb_build_object('score', v_score, 'reasons', v_reasons);
end;
$$;

comment on function public.score_compatibility(
  integer, text, text, text, text, integer, integer, text, text, text, text
) is
  'PD-06 score. Does not read profiles and does not accept protected traits.';

revoke all on function public.score_compatibility(
  integer, text, text, text, text, integer, integer, text, text, text, text
) from public, anon;

grant execute on function public.score_compatibility(
  integer, text, text, text, text, integer, integer, text, text, text, text
) to authenticated;



insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261014170000',
  'score_compatibility',
  array[
    $homizi_20261014170000_1$-- PD-06 scoring on the server. Budget, city, locality, furnishing, property type.
-- Gender, religion, caste, age, and marital status are not arguments.

create or replace function public.score_compatibility(
  p_rent_inr integer,
  p_city text,
  p_locality text,
  p_furnishing text,
  p_property_type text,
  p_budget_min_inr integer,
  p_budget_max_inr integer,
  p_pref_city text,
  p_pref_locality text default null,
  p_pref_furnishing text default null,
  p_pref_property_type text default null
)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_score integer := 0;
  v_reasons jsonb := '[]'::jsonb;
  v_budget integer := 0;
  v_bound integer;
  v_delta numeric;
  v_wanted text;
begin
  if p_rent_inr is not null
     and p_budget_min_inr is not null
     and p_budget_max_inr is not null
     and p_rent_inr >= p_budget_min_inr
     and p_rent_inr <= p_budget_max_inr then
    v_budget := 40;
    v_reasons := v_reasons || jsonb_build_array('Rent sits inside your budget.');
  else
    if p_rent_inr is null
       or p_budget_min_inr is null
       or p_budget_max_inr is null then
      v_budget := 0;
    else
      v_bound := case
        when p_rent_inr < p_budget_min_inr then p_budget_min_inr
        else p_budget_max_inr
      end;
      if v_bound = 0 then
        v_budget := 0;
      else
        v_delta := abs(p_rent_inr - v_bound)::numeric / v_bound;
        v_budget := case when v_delta <= 0.20 then 15 else 0 end;
      end if;
    end if;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when v_budget = 15 then 'Rent is close to your budget.'
        else 'Rent is outside your budget.'
      end
    );
  end if;
  v_score := v_score + v_budget;

  if lower(btrim(coalesce(p_pref_city, ''))) = lower(btrim(coalesce(p_city, '')))
     and btrim(coalesce(p_pref_city, '')) <> '' then
    v_score := v_score + 25;
    v_reasons := v_reasons || jsonb_build_array('City matches ' || btrim(p_city) || '.');
  else
    v_reasons := v_reasons || jsonb_build_array(
      'City does not match ' || btrim(coalesce(p_pref_city, '')) || '.'
    );
  end if;

  v_wanted := btrim(coalesce(p_pref_locality, ''));
  if v_wanted = ''
     or lower(v_wanted) = lower(btrim(coalesce(p_locality, ''))) then
    v_score := v_score + 15;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when v_wanted = '' then 'No locality preference set.'
        else 'Locality matches ' || btrim(coalesce(p_locality, '')) || '.'
      end
    );
  else
    v_reasons := v_reasons || jsonb_build_array('Locality does not match ' || v_wanted || '.');
  end if;

  if p_pref_furnishing is null
     or btrim(p_pref_furnishing) = ''
     or lower(btrim(p_pref_furnishing)) = lower(btrim(coalesce(p_furnishing, ''))) then
    v_score := v_score + 10;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when p_pref_furnishing is null or btrim(p_pref_furnishing) = ''
          then 'No furnishing preference set.'
        else 'Furnishing matches.'
      end
    );
  else
    v_reasons := v_reasons || jsonb_build_array('Furnishing does not match.');
  end if;

  if p_pref_property_type is null
     or btrim(p_pref_property_type) = ''
     or lower(btrim(p_pref_property_type)) = lower(btrim(coalesce(p_property_type, ''))) then
    v_score := v_score + 10;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when p_pref_property_type is null or btrim(p_pref_property_type) = ''
          then 'No property type preference set.'
        else 'Property type matches.'
      end
    );
  else
    v_reasons := v_reasons || jsonb_build_array('Property type does not match.');
  end if;

  return jsonb_build_object('score', v_score, 'reasons', v_reasons);
end;
$$;$homizi_20261014170000_1$,
    $homizi_20261014170000_2$comment on function public.score_compatibility(
  integer, text, text, text, text, integer, integer, text, text, text, text
) is
  'PD-06 score. Does not read profiles and does not accept protected traits.';$homizi_20261014170000_2$,
    $homizi_20261014170000_3$revoke all on function public.score_compatibility(
  integer, text, text, text, text, integer, integer, text, text, text, text
) from public, anon;$homizi_20261014170000_3$,
    $homizi_20261014170000_4$grant execute on function public.score_compatibility(
  integer, text, text, text, text, integer, integer, text, text, text, text
) to authenticated;$homizi_20261014170000_4$
  ]::text[]
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;



do $homizi_check$
declare
  missing text;
begin
  select string_agg(expected.version, ', ' order by expected.version)
  into missing
  from (values
    ('20261011120000'),
    ('20261011120100'),
    ('20261011120200'),
    ('20261011120300'),
    ('20261011120400'),
    ('20261011120500'),
    ('20261011120600'),
    ('20261014170000')
  ) as expected(version)
  where not exists (
    select 1
    from supabase_migrations.schema_migrations applied
    where applied.version = expected.version
  );
  if missing is not null then
    raise exception 'staging migrations were not recorded: %', missing;
  end if;
  if to_regclass('public.users') is null then
    raise exception 'public.users was not created';
  end if;
  if to_regclass('storage.buckets') is not null
     and not exists (
       select 1 from storage.buckets where id = 'listing-photos'
     ) then
    raise exception 'listing-photos bucket was not created';
  end if;
end
$homizi_check$;
