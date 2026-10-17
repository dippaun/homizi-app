-- HOMIZI live identity checks for a project that already ran
-- docs/staging_apply_E_1017c.sql (or later).
-- Paste this whole file into the dashboard SQL editor. Running it again is safe.
--
-- It applies 20261017211500_live_identity_checks.sql.
-- Stores a status, timestamps, a Digio request id, and the last 4 characters.
-- No Aadhaar number, document, or face image is written.

-- Live Aadhaar and face checks. Clients can read their own row, record
-- consent, and delete that row. Verified flags are written only by
-- apply_kyc_checks, which refuses a signed-in user. The row stores a status,
-- timestamps, a Digio request id, and the last 4 characters. It does not
-- store an Aadhaar number, a document, or a face image.

alter table public.identity_verifications
  add column if not exists aadhaar_status text not null default 'not_started',
  add column if not exists face_status text not null default 'not_started',
  add column if not exists aadhaar_verified_at timestamptz,
  add column if not exists face_verified_at timestamptz,
  add column if not exists consent_version text,
  add column if not exists started_at timestamptz;

do $kyc_checks$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'identity_verifications_aadhaar_status'
  ) then
    alter table public.identity_verifications
      add constraint identity_verifications_aadhaar_status
      check (aadhaar_status in ('not_started', 'in_progress', 'verified', 'failed'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'identity_verifications_face_status'
  ) then
    alter table public.identity_verifications
      add constraint identity_verifications_face_status
      check (face_status in ('not_started', 'in_progress', 'verified', 'failed'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'identity_verifications_consent_version'
  ) then
    alter table public.identity_verifications
      add constraint identity_verifications_consent_version
      check (
        consent_version is null
        or (
          char_length(consent_version) between 1 and 40
          and position('@' in consent_version) = 0
        )
      );
  end if;
end
$kyc_checks$;

comment on table public.identity_verifications is
  'Status, timestamps, Digio request id (provider_reference), and masked last 4. No Aadhaar number, document, or face image.';
comment on column public.identity_verifications.provider_reference is
  'Digio request id. A 12-digit run is rejected.';
comment on column public.identity_verifications.aadhaar_status is
  'not_started, in_progress, verified, or failed. Written by apply_kyc_checks only.';
comment on column public.identity_verifications.face_status is
  'not_started, in_progress, verified, or failed. Written by apply_kyc_checks only.';

revoke insert, update, delete on public.identity_verifications
  from public, anon, authenticated;

create or replace function public.identity_verifications_guard()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_role text := coalesce(auth.role(), '');
  v_client boolean := current_user in ('authenticated', 'anon')
    or v_role in ('authenticated', 'anon');
begin
  if new.provider_reference is not null and new.provider_reference ~ '[0-9]{12}' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  if new.masked_last4 is not null and new.masked_last4 !~ '^[0-9A-Z]{4}$' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  if v_client and (
    new.verification_status in ('pending', 'verified', 'rejected')
    and (
      tg_op = 'INSERT'
      or old.verification_status is distinct from new.verification_status
    )
    or tg_op = 'INSERT' and new.aadhaar_status in ('in_progress', 'verified', 'failed')
    or tg_op = 'UPDATE'
      and new.aadhaar_status is distinct from old.aadhaar_status
      and new.aadhaar_status in ('in_progress', 'verified', 'failed')
    or tg_op = 'INSERT' and new.face_status in ('in_progress', 'verified', 'failed')
    or tg_op = 'UPDATE'
      and new.face_status is distinct from old.face_status
      and new.face_status in ('in_progress', 'verified', 'failed')
    or tg_op = 'UPDATE' and (
      new.masked_last4 is distinct from old.masked_last4
      or new.provider_reference is distinct from old.provider_reference
      or new.aadhaar_verified_at is distinct from old.aadhaar_verified_at
      or new.face_verified_at is distinct from old.face_verified_at
    )
    or tg_op = 'INSERT' and (
      new.masked_last4 is not null
      or new.provider_reference is not null
      or new.aadhaar_verified_at is not null
      or new.face_verified_at is not null
    )
  ) then
    raise exception 'verification status is server-only' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function public.identity_verifications_guard() from public, anon, authenticated;

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
    'masked_last4', p.masked_last4,
    'aadhaar_status', p.aadhaar_status,
    'face_status', p.face_status,
    'consented_at', p.consented_at,
    'aadhaar_verified_at', p.aadhaar_verified_at,
    'face_verified_at', p.face_verified_at,
    'started_at', p.started_at
  );
$$;

revoke all on function public.identity_public_json(public.identity_verifications)
  from public, anon, authenticated;
grant execute on function public.identity_public_json(public.identity_verifications)
  to service_role;

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
    user_id, verification_status, provider, document_kind, consented_at, consent_version
  ) values (
    v_uid, 'consent_given', 'digio', p_document_kind, now(), '2026-10-17-dpdp'
  )
  on conflict (user_id) do update
  set
    document_kind = excluded.document_kind,
    consented_at = now(),
    consent_version = excluded.consent_version,
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

create or replace function public.apply_kyc_checks(
  p_user_id uuid,
  p_aadhaar_status text,
  p_face_status text,
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
  v_overall text;
begin
  if coalesce(auth.role(), '') in ('authenticated', 'anon') then
    raise exception 'verification status is server-only' using errcode = '42501';
  end if;
  if p_user_id is null
     or p_aadhaar_status is null
     or p_aadhaar_status not in ('not_started', 'in_progress', 'verified', 'failed')
     or p_face_status is null
     or p_face_status not in ('not_started', 'in_progress', 'verified', 'failed') then
    return jsonb_build_object('ok', false, 'error', 'status');
  end if;
  if p_document_kind is not null
     and p_document_kind not in ('digilocker', 'aadhaar_offline', 'pan') then
    return jsonb_build_object('ok', false, 'error', 'kind');
  end if;
  if p_reference is null
     or btrim(p_reference) = ''
     or p_reference ~ '[0-9]{12}' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  if p_masked_last4 is not null and p_masked_last4 !~ '^[0-9A-Z]{4}$' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  v_overall := case
    when p_aadhaar_status = 'verified' and p_face_status = 'verified' then 'verified'
    when p_aadhaar_status = 'in_progress' or p_face_status = 'in_progress' then 'pending'
    when p_aadhaar_status = 'failed' or p_face_status = 'failed' then 'rejected'
    else 'consent_given'
  end;
  insert into public.identity_verifications (
    user_id, verification_status, provider, document_kind, provider_reference,
    masked_last4, consented_at, aadhaar_status, face_status,
    aadhaar_verified_at, face_verified_at, started_at
  ) values (
    p_user_id,
    v_overall,
    'digio',
    p_document_kind,
    p_reference,
    p_masked_last4,
    now(),
    p_aadhaar_status,
    p_face_status,
    case when p_aadhaar_status = 'verified' then now() else null end,
    case when p_face_status = 'verified' then now() else null end,
    case
      when p_aadhaar_status = 'in_progress' or p_face_status = 'in_progress' then now()
      else null
    end
  )
  on conflict (user_id) do update
  set
    verification_status = excluded.verification_status,
    provider = 'digio',
    document_kind = coalesce(excluded.document_kind, public.identity_verifications.document_kind),
    provider_reference = excluded.provider_reference,
    masked_last4 = coalesce(excluded.masked_last4, public.identity_verifications.masked_last4),
    aadhaar_status = excluded.aadhaar_status,
    face_status = excluded.face_status,
    aadhaar_verified_at = case
      when excluded.aadhaar_status = 'verified'
        then coalesce(public.identity_verifications.aadhaar_verified_at, now())
      else null
    end,
    face_verified_at = case
      when excluded.face_status = 'verified'
        then coalesce(public.identity_verifications.face_verified_at, now())
      else null
    end,
    started_at = case
      when excluded.aadhaar_status = 'in_progress' or excluded.face_status = 'in_progress'
        then coalesce(public.identity_verifications.started_at, now())
      else public.identity_verifications.started_at
    end
  returning * into v_row;
  return jsonb_build_object(
    'ok', true,
    'verification', public.identity_public_json(v_row)
  );
end;
$$;

create or replace function public.delete_my_verification()
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
  delete from public.identity_verifications where user_id = v_uid;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.record_kyc_consent(text) from public, anon;
revoke all on function public.apply_kyc_checks(uuid, text, text, text, text, text)
  from public, anon, authenticated;
revoke all on function public.delete_my_verification() from public, anon;

grant execute on function public.record_kyc_consent(text) to authenticated, service_role;
grant execute on function public.apply_kyc_checks(uuid, text, text, text, text, text)
  to service_role;
grant execute on function public.delete_my_verification() to authenticated, service_role;

create or replace view public.user_badges
with (security_invoker = false) as
select
  u.id as user_id,
  (pc.phone is not null and btrim(pc.phone) <> '') as phone_verified,
  (pc.email is not null and btrim(pc.email) <> '') as email_verified,
  (
    char_length(btrim(coalesce(p.display_name, ''))) >= 2
    and nullif(btrim(coalesce(p.occupation, '')), '') is not null
    and char_length(btrim(coalesce(p.public_bio, ''))) >= 20
  ) as profile_complete,
  (p.verification_status = 'mock_verified') as id_verified_demo,
  coalesce(iv.aadhaar_status = 'verified', false) as aadhaar_verified,
  coalesce(iv.face_status = 'verified', false) as face_verified
from public.users u
left join public.profiles p on p.user_id = u.id
left join public.private_contacts pc on pc.user_id = u.id
left join public.identity_verifications iv on iv.user_id = u.id;

comment on view public.user_badges is
  'Phone, email, and profile flags, plus Aadhaar and face results. The booleans do not include a number, a document, or a face image.';

revoke all on table public.user_badges from anon, public;
grant select on table public.user_badges to authenticated;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261017211500',
  'live_identity_checks',
  array['docs/staging_apply_H_1017.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
