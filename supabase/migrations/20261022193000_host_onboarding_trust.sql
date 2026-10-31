-- HOMIZI host onboarding and separate trust checks.
-- Paste this whole file into the staging SQL editor. Running it again is safe.
-- Do not apply it from the app. Do not put a service role key in this file.
--
-- Identity (mobile, email, Aadhaar, selfie) stays on profiles.
-- Property authorization is a different check: owner document, broker ID,
-- tenant permission, or company registration.
-- This file does not add a phone, email, or Aadhaar column.
-- Legal name is owner-only. Contact stays in private_contacts.
-- Premium here is a badge label. This file does not charge a card.

reset role;

do $$
begin
  if to_regclass('public.profiles') is null
     or to_regclass('public.users') is null
     or to_regclass('public.host_profiles') is null
     or to_regclass('public.staff_roles') is null
     or to_regprocedure('public.set_updated_at()') is null then
    raise exception 'Apply the earlier HOMIZI staging SQL before this file.';
  end if;
end $$;

create table if not exists public.host_onboarding (
  user_id uuid primary key references public.users (id) on delete cascade,
  legal_full_name text,
  public_nickname text,
  gender text,
  agreement_permits_share boolean not null default false,
  bio text,
  response_time text,
  preferred_tenant_types text[] not null default '{}',
  company_name text,
  registration_no text,
  subscription_plan text not null default 'free',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint host_onboarding_nick_len check (
    public_nickname is null or char_length(public_nickname) between 2 and 80
  ),
  constraint host_onboarding_legal_len check (
    legal_full_name is null or char_length(legal_full_name) between 2 and 80
  ),
  constraint host_onboarding_gender check (
    gender is null
    or gender in ('Woman', 'Man', 'Non-binary', 'Prefer not to say')
  ),
  constraint host_onboarding_bio_len check (
    bio is null or char_length(bio) <= 280
  ),
  constraint host_onboarding_response check (
    response_time is null
    or response_time in (
      'Replies within 2 hours',
      'Replies within 24 hours',
      'Replies within 2 days'
    )
  ),
  constraint host_onboarding_company_len check (
    company_name is null or char_length(company_name) <= 120
  ),
  constraint host_onboarding_registration check (
    registration_no is null
    or registration_no ~ '^[A-Za-z0-9/-]{5,21}$'
  ),
  constraint host_onboarding_plan check (
    subscription_plan in ('free', 'premium')
  )
);

comment on table public.host_onboarding is
  'Host registration. legal_full_name is owner-only. No phone, email, or Aadhaar number is stored here.';

comment on column public.host_onboarding.legal_full_name is
  'Owner-only legal name. Never shown on a public profile.';

comment on column public.host_onboarding.public_nickname is
  'Name other people see. Not the legal name.';

comment on column public.host_onboarding.subscription_plan is
  'Free or Premium badge. Not a payment record.';

comment on column public.host_onboarding.agreement_permits_share is
  'Existing tenant confirmed the rental agreement allows sharing.';

create table if not exists public.host_roles (
  user_id uuid not null references public.users (id) on delete cascade,
  role text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, role),
  constraint host_roles_role_check check (
    role in ('owner', 'broker', 'roomie', 'company')
  )
);

comment on table public.host_roles is
  'Every host role on one account. host_profiles.host_category stays the primary one.';

create table if not exists public.host_authorizations (
  user_id uuid not null references public.users (id) on delete cascade,
  kind text not null,
  status text not null default 'not_submitted',
  updated_at timestamptz not null default now(),
  primary key (user_id, kind),
  constraint host_authorizations_kind_check check (
    kind in (
      'owner_document',
      'broker_id',
      'tenant_permission',
      'company_registration'
    )
  ),
  constraint host_authorizations_status_check check (
    status in ('not_submitted', 'under_review', 'verified')
  )
);

comment on table public.host_authorizations is
  'Property authorization, separate from identity verification. A member cannot set verified.';

-- A signed-in member cannot mark their own document verified.
-- Staff in staff_roles can. A SQL session with no auth.uid() can seed rows.
create or replace function public.guard_host_authorization_status()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status = 'verified'
     and auth.uid() is not null
     and not exists (
       select 1 from public.staff_roles as staff
       where staff.user_id = auth.uid()
     )
     and (tg_op = 'INSERT' or old.status is distinct from 'verified') then
    new.status := 'under_review';
  end if;
  return new;
end;
$$;

drop trigger if exists host_authorizations_guard on public.host_authorizations;
create trigger host_authorizations_guard
  before insert or update on public.host_authorizations
  for each row execute function public.guard_host_authorization_status();

drop trigger if exists host_onboarding_set_updated_at on public.host_onboarding;
create trigger host_onboarding_set_updated_at
  before update on public.host_onboarding
  for each row execute function public.set_updated_at();

create or replace function public.apply_host_onboarding(
  p_legal_full_name text,
  p_public_nickname text,
  p_gender text,
  p_roles text[],
  p_agreement_permits_share boolean,
  p_bio text,
  p_response_time text,
  p_preferred_tenant_types text[],
  p_company_name text,
  p_registration_no text,
  p_plan text,
  p_authorizations jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_nick text := left(btrim(coalesce(p_public_nickname, '')), 80);
  v_legal text := nullif(left(btrim(coalesce(p_legal_full_name, '')), 80), '');
  v_company text := nullif(left(btrim(coalesce(p_company_name, '')), 120), '');
  v_reg text := nullif(btrim(coalesce(p_registration_no, '')), '');
  v_plan text := coalesce(nullif(btrim(coalesce(p_plan, '')), ''), 'free');
  v_category text := 'other';
  v_item jsonb;
  v_kind text;
  v_status text;
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;
  if char_length(v_nick) < 2 then
    raise exception 'nickname required';
  end if;
  if p_roles is null or cardinality(p_roles) = 0 then
    raise exception 'choose a category';
  end if;
  if exists (
    select 1 from unnest(p_roles) as role
    where role not in ('owner', 'broker', 'roomie', 'company')
  ) then
    raise exception 'unknown host role';
  end if;
  if 'roomie' = any(p_roles)
     and not coalesce(p_agreement_permits_share, false) then
    raise exception 'rental agreement permission is required';
  end if;
  if p_gender is not null
     and p_gender not in ('Woman', 'Man', 'Non-binary', 'Prefer not to say') then
    raise exception 'unknown gender';
  end if;
  if v_plan not in ('free', 'premium') then
    raise exception 'unknown plan';
  end if;
  if p_bio is not null and char_length(p_bio) > 280 then
    raise exception 'bio too long';
  end if;
  if p_response_time is not null
     and p_response_time not in (
       'Replies within 2 hours',
       'Replies within 24 hours',
       'Replies within 2 days'
     ) then
    raise exception 'unknown response time';
  end if;
  if exists (
    select 1
    from unnest(coalesce(p_preferred_tenant_types, '{}')) as tenant_type
    where tenant_type not in (
      'Working professional',
      'Student',
      'Actor / Actress',
      'Any'
    )
  ) then
    raise exception 'unknown tenant type';
  end if;
  if 'company' = any(p_roles) then
    if v_company is null then
      raise exception 'company name required';
    end if;
    if v_reg is null or v_reg !~ '^[A-Za-z0-9/-]{5,21}$' then
      raise exception 'registration number required';
    end if;
  elsif v_reg is not null and v_reg !~ '^[A-Za-z0-9/-]{5,21}$' then
    raise exception 'invalid registration number';
  end if;

  if 'owner' = any(p_roles) then
    v_category := 'owner';
  elsif 'broker' = any(p_roles) then
    v_category := 'broker';
  elsif 'company' = any(p_roles) then
    v_category := 'company';
  elsif 'roomie' = any(p_roles) then
    v_category := 'flatmate';
  end if;

  insert into public.host_onboarding (
    user_id,
    legal_full_name,
    public_nickname,
    gender,
    agreement_permits_share,
    bio,
    response_time,
    preferred_tenant_types,
    company_name,
    registration_no,
    subscription_plan
  )
  values (
    v_user,
    v_legal,
    v_nick,
    p_gender,
    coalesce(p_agreement_permits_share, false),
    nullif(btrim(coalesce(p_bio, '')), ''),
    p_response_time,
    coalesce(p_preferred_tenant_types, '{}'),
    case when 'company' = any(p_roles) then v_company else null end,
    case when 'company' = any(p_roles) then v_reg else null end,
    v_plan
  )
  on conflict (user_id) do update
  set legal_full_name = excluded.legal_full_name,
      public_nickname = excluded.public_nickname,
      gender = excluded.gender,
      agreement_permits_share = excluded.agreement_permits_share,
      bio = excluded.bio,
      response_time = excluded.response_time,
      preferred_tenant_types = excluded.preferred_tenant_types,
      company_name = excluded.company_name,
      registration_no = excluded.registration_no,
      subscription_plan = excluded.subscription_plan,
      updated_at = now();

  delete from public.host_roles where user_id = v_user;
  insert into public.host_roles (user_id, role)
  select v_user, role
  from unnest(p_roles) as role;

  insert into public.host_profiles (user_id, host_category, company_name)
  values (
    v_user,
    v_category::public.host_category,
    case when 'company' = any(p_roles) then v_company else null end
  )
  on conflict (user_id) do update
  set host_category = excluded.host_category,
      company_name = excluded.company_name,
      updated_at = now();

  for v_item in
    select value
    from jsonb_array_elements(coalesce(p_authorizations, '[]'::jsonb))
  loop
    v_kind := v_item->>'kind';
    v_status := coalesce(v_item->>'status', 'under_review');
    if v_kind not in (
      'owner_document',
      'broker_id',
      'tenant_permission',
      'company_registration'
    ) then
      raise exception 'unknown authorization';
    end if;
    if v_status not in ('not_submitted', 'under_review', 'verified') then
      v_status := 'under_review';
    end if;
    if v_status = 'verified'
       and not exists (
         select 1 from public.staff_roles as staff
         where staff.user_id = v_user
       ) then
      v_status := 'under_review';
    end if;
    insert into public.host_authorizations (user_id, kind, status)
    values (v_user, v_kind, v_status)
    on conflict (user_id, kind) do update
    set status = excluded.status,
        updated_at = now();
  end loop;
end;
$$;

comment on function public.apply_host_onboarding(
  text, text, text, text[], boolean, text, text, text[], text, text, text, jsonb
) is
  'Saves host roles and property-authorization requests. Does not accept a phone, email, or Aadhaar number.';

create or replace function public.read_own_host_legal_name()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return null;
  end if;
  return (
    select legal_full_name
    from public.host_onboarding
    where user_id = v_user
  );
end;
$$;

comment on function public.read_own_host_legal_name() is
  'Legal name for the signed-in host only.';

revoke select (legal_full_name)
  on table public.host_onboarding
  from public, anon, authenticated;

alter table public.host_onboarding enable row level security;
alter table public.host_roles enable row level security;
alter table public.host_authorizations enable row level security;

drop policy if exists host_onboarding_self on public.host_onboarding;
create policy host_onboarding_self on public.host_onboarding
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists host_roles_self on public.host_roles;
create policy host_roles_self on public.host_roles
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists host_authorizations_self on public.host_authorizations;
create policy host_authorizations_self on public.host_authorizations
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.host_onboarding from public, anon;
revoke all on public.host_roles from public, anon;
revoke all on public.host_authorizations from public, anon;

grant select (
  user_id,
  public_nickname,
  gender,
  agreement_permits_share,
  bio,
  response_time,
  preferred_tenant_types,
  company_name,
  registration_no,
  subscription_plan,
  created_at,
  updated_at
) on public.host_onboarding to authenticated;

grant insert, update, delete on public.host_onboarding to authenticated;
grant select, insert, update, delete on public.host_roles to authenticated;
grant select, insert, update, delete on public.host_authorizations to authenticated;

revoke all on function public.apply_host_onboarding(
  text, text, text, text[], boolean, text, text, text[], text, text, text, jsonb
) from public, anon;
revoke all on function public.read_own_host_legal_name() from public, anon;
revoke all on function public.guard_host_authorization_status() from public;

grant execute on function public.apply_host_onboarding(
  text, text, text, text[], boolean, text, text, text[], text, text, text, jsonb
) to authenticated;
grant execute on function public.read_own_host_legal_name() to authenticated;

