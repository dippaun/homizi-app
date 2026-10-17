-- Rent agreements and identity checks. verification_status on this table
-- is written by apply_verification_result, which refuses a signed-in user.
-- Raw Aadhaar numbers and documents are rejected. profiles.verification_status
-- stays the existing mock enum.

create table if not exists public.agreements (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id),
  created_by uuid not null references public.users (id),
  title text not null,
  draft_body text not null,
  status text not null default 'draft',
  provider text not null default 'demo',
  provider_reference text,
  stamp_amount_inr integer,
  source_draft_id uuid,
  tenant_signed_at timestamptz,
  owner_signed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint agreements_status check (
    status in (
      'draft',
      'sent',
      'tenant_signed',
      'owner_signed',
      'completed',
      'declined',
      'expired'
    )
  ),
  constraint agreements_provider check (provider in ('demo', 'digio')),
  constraint agreements_title check (
    char_length(btrim(title)) between 3 and 120
    and position('@' in title) = 0
  ),
  constraint agreements_body check (
    char_length(draft_body) between 1 and 8000
    and position('@' in draft_body) = 0
    and draft_body !~ '[0-9]{12}'
  ),
  constraint agreements_stamp check (
    stamp_amount_inr is null or stamp_amount_inr >= 0
  )
);

comment on table public.agreements is
  'E-sign status for a match. source_draft_id has no foreign key so a later draft table can arrive. Digio status is server-only.';
comment on column public.agreements.source_draft_id is
  'Optional id of a rent_agreement_drafts row. The foreign key is added when that table exists.';

do $agreements_draft_fk$
begin
  if to_regclass('public.rent_agreement_drafts') is not null
     and not exists (
       select 1
       from pg_constraint
       where conname = 'agreements_source_draft_fkey'
     ) then
    alter table public.agreements
      add constraint agreements_source_draft_fkey
      foreign key (source_draft_id)
      references public.rent_agreement_drafts (id)
      on delete set null;
  end if;
end
$agreements_draft_fk$;

drop trigger if exists agreements_set_updated_at on public.agreements;
create trigger agreements_set_updated_at
  before update on public.agreements
  for each row execute function public.set_updated_at();

alter table public.agreements enable row level security;

drop policy if exists agreements_select_party on public.agreements;
create policy agreements_select_party on public.agreements
  for select to authenticated
  using (
    exists (
      select 1
      from public.matches m
      where m.id = match_id
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );

grant select on public.agreements to authenticated;
grant all on public.agreements to service_role;

create table if not exists public.identity_verifications (
  user_id uuid primary key references public.users (id) on delete cascade,
  verification_status text not null default 'not_started',
  provider text not null default 'demo',
  document_kind text,
  provider_reference text,
  masked_last4 text,
  consented_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint identity_verifications_status check (
    verification_status in (
      'not_started',
      'consent_given',
      'pending',
      'verified',
      'rejected'
    )
  ),
  constraint identity_verifications_provider check (provider in ('demo', 'digio')),
  constraint identity_verifications_kind check (
    document_kind is null
    or document_kind in ('digilocker', 'aadhaar_offline', 'pan')
  ),
  constraint identity_verifications_mask check (
    masked_last4 is null or masked_last4 ~ '^[0-9A-Z]{4}$'
  ),
  constraint identity_verifications_reference check (
    provider_reference is null or provider_reference !~ '[0-9]{12}'
  )
);

comment on table public.identity_verifications is
  'Status, provider reference, and masked last 4 only. No Aadhaar number and no document.';

drop trigger if exists identity_verifications_set_updated_at
  on public.identity_verifications;
create trigger identity_verifications_set_updated_at
  before update on public.identity_verifications
  for each row execute function public.set_updated_at();

create or replace function public.identity_verifications_guard()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_role text := coalesce(auth.role(), '');
begin
  if new.provider_reference is not null and new.provider_reference ~ '[0-9]{12}' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  if new.masked_last4 is not null and new.masked_last4 !~ '^[0-9A-Z]{4}$' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  if (
    current_user in ('authenticated', 'anon')
    or v_role in ('authenticated', 'anon')
  ) and new.verification_status in ('pending', 'verified', 'rejected')
     and (
       tg_op = 'INSERT'
       or old.verification_status is distinct from new.verification_status
     ) then
    raise exception 'verification status is server-only' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists identity_verifications_guard on public.identity_verifications;
create trigger identity_verifications_guard
  before insert or update on public.identity_verifications
  for each row execute function public.identity_verifications_guard();

revoke all on function public.identity_verifications_guard() from public, anon, authenticated;

alter table public.identity_verifications enable row level security;

drop policy if exists identity_verifications_select_own on public.identity_verifications;
create policy identity_verifications_select_own on public.identity_verifications
  for select to authenticated
  using (user_id = auth.uid());

grant select on public.identity_verifications to authenticated;
grant all on public.identity_verifications to service_role;

create or replace function public.agreement_public_json(p public.agreements)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id,
    'title', p.title,
    'status', p.status,
    'provider', p.provider,
    'provider_reference', p.provider_reference,
    'stamp_amount_inr', p.stamp_amount_inr,
    'source_draft_id', p.source_draft_id,
    'draft_body', p.draft_body
  );
$$;

create or replace function public.identity_public_json(p public.identity_verifications)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'verification_status', p.verification_status,
    'provider', p.provider,
    'provider_reference', p.provider_reference,
    'document_kind', p.document_kind,
    'masked_last4', p.masked_last4
  );
$$;

revoke all on function public.agreement_public_json(public.agreements)
  from public, anon, authenticated;
revoke all on function public.identity_public_json(public.identity_verifications)
  from public, anon, authenticated;
grant execute on function public.agreement_public_json(public.agreements) to service_role;
grant execute on function public.identity_public_json(public.identity_verifications)
  to service_role;

create or replace function public.create_agreement(
  p_match_id uuid,
  p_title text,
  p_draft_body text,
  p_stamp_amount_inr integer default null,
  p_source_draft_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.agreements;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not exists (
    select 1
    from public.matches m
    where m.id = p_match_id
      and m.status = 'active'
      and (m.participant_a = v_uid or m.participant_b = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  if p_title is null
     or char_length(btrim(p_title)) < 3
     or char_length(btrim(p_title)) > 120
     or position('@' in p_title) > 0
     or p_draft_body is null
     or char_length(p_draft_body) < 1
     or char_length(p_draft_body) > 8000
     or position('@' in p_draft_body) > 0
     or p_draft_body ~ '[0-9]{12}' then
    return jsonb_build_object('ok', false, 'error', 'draft');
  end if;
  insert into public.agreements (
    match_id, created_by, title, draft_body, status, provider,
    stamp_amount_inr, source_draft_id
  ) values (
    p_match_id, v_uid, btrim(p_title), p_draft_body, 'draft', 'demo',
    p_stamp_amount_inr, p_source_draft_id
  )
  returning * into v_row;
  return jsonb_build_object('ok', true, 'agreement', public.agreement_public_json(v_row));
end;
$$;

create or replace function public.send_agreement(p_agreement_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.agreements;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_row from public.agreements where id = p_agreement_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if not exists (
    select 1 from public.matches m
    where m.id = v_row.match_id
      and (m.participant_a = v_uid or m.participant_b = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  if v_row.provider <> 'demo' then
    return jsonb_build_object('ok', false, 'error', 'provider');
  end if;
  if v_row.status = 'draft' then
    update public.agreements
    set status = 'sent'
    where id = p_agreement_id
    returning * into v_row;
  end if;
  return jsonb_build_object('ok', true, 'agreement', public.agreement_public_json(v_row));
end;
$$;

create or replace function public.demo_sign_agreement(
  p_agreement_id uuid,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.agreements;
  v_next text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_role is null or p_role not in ('tenant', 'owner') then
    return jsonb_build_object('ok', false, 'error', 'role');
  end if;
  select * into v_row from public.agreements where id = p_agreement_id;
  if not found or v_row.provider <> 'demo' then
    return jsonb_build_object('ok', false, 'error', 'not_demo');
  end if;
  if not exists (
    select 1 from public.matches m
    where m.id = v_row.match_id
      and (m.participant_a = v_uid or m.participant_b = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_next := case
    when v_row.status = 'sent' and p_role = 'tenant' then 'tenant_signed'
    when v_row.status = 'sent' and p_role = 'owner' then 'owner_signed'
    when v_row.status = 'tenant_signed' and p_role = 'owner' then 'completed'
    when v_row.status = 'owner_signed' and p_role = 'tenant' then 'completed'
    else null
  end;
  if v_next is null then
    return jsonb_build_object('ok', false, 'error', 'status');
  end if;
  update public.agreements
  set
    status = v_next,
    tenant_signed_at = case
      when p_role = 'tenant' then coalesce(tenant_signed_at, now())
      else tenant_signed_at
    end,
    owner_signed_at = case
      when p_role = 'owner' then coalesce(owner_signed_at, now())
      else owner_signed_at
    end
  where id = p_agreement_id
  returning * into v_row;
  return jsonb_build_object('ok', true, 'agreement', public.agreement_public_json(v_row));
end;
$$;

create or replace function public.apply_esign_result(
  p_agreement_id uuid,
  p_status text,
  p_provider_reference text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.agreements;
begin
  if coalesce(auth.role(), '') in ('authenticated', 'anon') then
    raise exception 'agreement status is server-only' using errcode = '42501';
  end if;
  if p_status is null or p_status not in (
    'sent', 'tenant_signed', 'owner_signed', 'completed', 'declined', 'expired'
  ) then
    return jsonb_build_object('ok', false, 'error', 'status');
  end if;
  if p_provider_reference is not null and (
    position('@' in p_provider_reference) > 0
    or p_provider_reference ~ '[0-9]{12}'
  ) then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  update public.agreements
  set
    status = p_status,
    provider = 'digio',
    provider_reference = coalesce(p_provider_reference, provider_reference)
  where id = p_agreement_id
  returning * into v_row;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'agreement', public.agreement_public_json(v_row));
end;
$$;

create or replace function public.record_kyc_consent(p_document_kind text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.identity_verifications;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_document_kind is null
     or p_document_kind not in ('digilocker', 'aadhaar_offline', 'pan') then
    return jsonb_build_object('ok', false, 'error', 'kind');
  end if;
  insert into public.identity_verifications (
    user_id, verification_status, provider, document_kind, consented_at
  ) values (
    v_uid, 'consent_given', 'demo', p_document_kind, now()
  )
  on conflict (user_id) do update
  set
    document_kind = excluded.document_kind,
    consented_at = now(),
    verification_status = case
      when public.identity_verifications.verification_status in (
        'pending', 'verified', 'rejected'
      ) then public.identity_verifications.verification_status
      else 'consent_given'
    end
  returning * into v_row;
  return jsonb_build_object(
    'ok', true,
    'verification', public.identity_public_json(v_row)
  );
end;
$$;

create or replace function public.apply_verification_result(
  p_user_id uuid,
  p_status text,
  p_provider text,
  p_reference text,
  p_masked_last4 text,
  p_document_kind text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.identity_verifications;
begin
  if coalesce(auth.role(), '') in ('authenticated', 'anon') then
    raise exception 'verification status is server-only' using errcode = '42501';
  end if;
  if p_status is null or p_status not in ('pending', 'verified', 'rejected') then
    return jsonb_build_object('ok', false, 'error', 'status');
  end if;
  if p_provider is null or p_provider not in ('demo', 'digio') then
    return jsonb_build_object('ok', false, 'error', 'provider');
  end if;
  if p_reference is not null and p_reference ~ '[0-9]{12}' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  if p_masked_last4 is not null and p_masked_last4 !~ '^[0-9A-Z]{4}$' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  insert into public.identity_verifications (
    user_id, verification_status, provider, document_kind,
    provider_reference, masked_last4, consented_at
  ) values (
    p_user_id, p_status, p_provider, p_document_kind,
    p_reference, p_masked_last4, now()
  )
  on conflict (user_id) do update
  set
    verification_status = excluded.verification_status,
    provider = excluded.provider,
    document_kind = coalesce(excluded.document_kind, public.identity_verifications.document_kind),
    provider_reference = excluded.provider_reference,
    masked_last4 = excluded.masked_last4
  returning * into v_row;
  return jsonb_build_object(
    'ok', true,
    'verification', public.identity_public_json(v_row)
  );
end;
$$;

revoke all on function public.create_agreement(uuid, text, text, integer, uuid)
  from public, anon;
revoke all on function public.send_agreement(uuid) from public, anon;
revoke all on function public.demo_sign_agreement(uuid, text) from public, anon;
revoke all on function public.apply_esign_result(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.record_kyc_consent(text) from public, anon;
revoke all on function public.apply_verification_result(uuid, text, text, text, text, text)
  from public, anon, authenticated;

grant execute on function public.create_agreement(uuid, text, text, integer, uuid)
  to authenticated, service_role;
grant execute on function public.send_agreement(uuid) to authenticated, service_role;
grant execute on function public.demo_sign_agreement(uuid, text)
  to authenticated, service_role;
grant execute on function public.record_kyc_consent(text) to authenticated, service_role;
grant execute on function public.apply_esign_result(uuid, text, text) to service_role;
grant execute on function public.apply_verification_result(uuid, text, text, text, text, text)
  to service_role;
