-- HOMIZI foundation schema.
-- Contact fields live only in private_contacts. No Aadhaar or payment card columns.
-- Payments tables are deferred placeholders: clients cannot write them.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.user_status as enum ('active', 'suspended', 'deleted');
create type public.primary_role as enum ('unset', 'tenant', 'host', 'both');
create type public.verification_status as enum (
  'not_started',
  'mock_pending',
  'mock_verified',
  'rejected'
);
create type public.host_category as enum (
  'owner',
  'broker',
  'company',
  'flatmate',
  'other'
);
create type public.property_type as enum (
  'apartment',
  'independent_house',
  'villa',
  'pg',
  'studio',
  'shared_room',
  'private_room'
);
create type public.furnishing as enum (
  'unfurnished',
  'semi_furnished',
  'furnished'
);
create type public.listing_status as enum (
  'draft',
  'published',
  'paused',
  'removed',
  'expired'
);
create type public.address_visibility as enum (
  'locality_only',
  'after_match',
  'after_visit_accept'
);
create type public.photo_type as enum (
  'exterior',
  'living',
  'bedroom',
  'kitchen',
  'bathroom',
  'other'
);
create type public.moderation_status as enum ('pending', 'approved', 'rejected');
create type public.interest_target_type as enum (
  'property',
  'listing_requirement',
  'user'
);
create type public.interest_action as enum ('like', 'pass', 'save');
create type public.match_status as enum ('active', 'unmatched', 'blocked');
create type public.contact_scope as enum ('phone', 'email', 'phone_and_email');
create type public.conversation_status as enum ('open', 'closed');
create type public.message_status as enum ('sent', 'hidden');
create type public.visit_status as enum (
  'requested',
  'accepted',
  'declined',
  'rescheduled',
  'cancelled',
  'completed'
);
create type public.report_target_type as enum (
  'user',
  'property',
  'listing_requirement',
  'message'
);
create type public.report_reason as enum (
  'spam',
  'harassment',
  'scam',
  'fake_listing',
  'inappropriate',
  'other'
);
create type public.report_status as enum (
  'open',
  'reviewing',
  'resolved',
  'dismissed'
);
create type public.subscription_status as enum (
  'inactive',
  'active',
  'expired',
  'cancelled'
);
create type public.payment_status as enum (
  'pending',
  'succeeded',
  'failed',
  'refunded'
);
create type public.consent_policy_type as enum ('terms', 'privacy');

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status public.user_status not null default 'active',
  primary_role public.primary_role not null default 'unset'
);

create table public.profiles (
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

create table public.private_contacts (
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

create table public.host_profiles (
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

create table public.tenant_preferences (
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

create table public.properties (
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

create table public.property_private_details (
  property_id uuid primary key references public.properties (id) on delete cascade,
  address_line text,
  landmark text,
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  updated_at timestamptz not null default now()
);

create table public.property_features (
  property_id uuid not null references public.properties (id) on delete cascade,
  feature_key text not null,
  value text not null,
  primary key (property_id, feature_key),
  constraint property_features_key_len check (char_length(feature_key) between 1 and 40)
);

create table public.property_photos (
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

create table public.listing_requirements (
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

create table public.interests (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null references public.users (id) on delete cascade,
  target_type public.interest_target_type not null,
  target_id uuid not null,
  action public.interest_action not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (actor_user_id, target_type, target_id, action)
);

create unique index interests_one_stance
  on public.interests (actor_user_id, target_type, target_id)
  where action in ('like', 'pass');

create table public.matches (
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

create table public.contact_consents (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  granted_by uuid not null references public.users (id),
  scope public.contact_scope not null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (match_id, granted_by)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references public.matches (id) on delete cascade,
  status public.conversation_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.users (id),
  body text not null,
  status public.message_status not null default 'sent',
  created_at timestamptz not null default now(),
  constraint messages_body_len check (char_length(body) between 1 and 4000)
);

create table public.visit_requests (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  requester_id uuid not null references public.users (id),
  proposed_slots jsonb not null default '[]'::jsonb,
  status public.visit_status not null default 'requested',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notifications (
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

create table public.reports (
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

create table public.blocks (
  blocker_id uuid not null references public.users (id) on delete cascade,
  blocked_user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id),
  constraint blocks_no_self check (blocker_id <> blocked_user_id)
);

create table public.staff_roles (
  user_id uuid primary key references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.subscriptions (
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

create table public.payments (
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

create table public.audit_events (
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

create table public.consent_records (
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

create index users_status_idx on public.users (status);
create index properties_host_idx on public.properties (host_user_id);
create index properties_discovery_idx
  on public.properties (status, city, locality);
create index properties_rent_idx
  on public.properties (rent_inr)
  where status = 'published';
create index property_photos_property_idx on public.property_photos (property_id);
create index listing_requirements_owner_idx
  on public.listing_requirements (user_id, status);
create index interests_actor_idx on public.interests (actor_user_id, created_at desc);
create index interests_target_idx on public.interests (target_type, target_id);
create index matches_participant_a_idx on public.matches (participant_a);
create index matches_participant_b_idx on public.matches (participant_b);
create index blocks_blocked_idx on public.blocks (blocked_user_id);
create index reports_status_idx on public.reports (status, created_at);
create index notifications_user_idx
  on public.notifications (user_id, created_at desc);
create index messages_conversation_idx
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

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger private_contacts_set_updated_at
  before update on public.private_contacts
  for each row execute function public.set_updated_at();
create trigger host_profiles_set_updated_at
  before update on public.host_profiles
  for each row execute function public.set_updated_at();
create trigger tenant_preferences_set_updated_at
  before update on public.tenant_preferences
  for each row execute function public.set_updated_at();
create trigger properties_set_updated_at
  before update on public.properties
  for each row execute function public.set_updated_at();
create trigger property_private_details_set_updated_at
  before update on public.property_private_details
  for each row execute function public.set_updated_at();
create trigger property_photos_set_updated_at
  before update on public.property_photos
  for each row execute function public.set_updated_at();
create trigger listing_requirements_set_updated_at
  before update on public.listing_requirements
  for each row execute function public.set_updated_at();
create trigger interests_set_updated_at
  before update on public.interests
  for each row execute function public.set_updated_at();
create trigger matches_set_updated_at
  before update on public.matches
  for each row execute function public.set_updated_at();
create trigger conversations_set_updated_at
  before update on public.conversations
  for each row execute function public.set_updated_at();
create trigger visit_requests_set_updated_at
  before update on public.visit_requests
  for each row execute function public.set_updated_at();
create trigger subscriptions_set_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();
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

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
