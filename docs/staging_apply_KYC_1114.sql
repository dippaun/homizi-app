-- KYC idempotent checks. Unapplied. Paste docs/staging_apply_KYC_1114.sql in the
-- Supabase SQL editor (staging) after the owner says yes. Safe to run twice.
-- Same text as supabase/migrations/20261114170000_kyc_idempotent_checks.sql.
-- The app is correct without it: kyc-webhook applies the same rule.

-- KYC go-live (Nov 14, 2026). NOT APPLIED to staging: the owner applies it.
--
-- apply_kyc_checks becomes idempotent per Digio request: a verified check is
-- never downgraded by a late or replayed webhook, and a failed check does not
-- go back to in progress. The kyc-webhook Edge Function already applies the
-- same rule before it calls this function, so the app is correct without
-- this migration; this is the database-side guard.
--
-- A new Digio request (new reference) also restarts started_at, so the
-- app's 10-day link expiry is measured from the latest request.
--
-- Same signature, same grants: service_role only. A signed-in user is still
-- refused (42501).

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
  v_prev public.identity_verifications;
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
  -- Idempotent for the same Digio request: a verified check stays verified
  -- and a failed check does not go back to in progress, whatever order
  -- Digio delivers or retries its events in. A new request (a new
  -- reference from start-kyc) starts fresh.
  select * into v_prev
  from public.identity_verifications
  where user_id = p_user_id;
  if found and v_prev.provider_reference is not distinct from p_reference then
    if v_prev.aadhaar_status = 'verified' then
      p_aadhaar_status := 'verified';
    elsif v_prev.aadhaar_status = 'failed' and p_aadhaar_status = 'in_progress' then
      p_aadhaar_status := 'failed';
    end if;
    if v_prev.face_status = 'verified' then
      p_face_status := 'verified';
    elsif v_prev.face_status = 'failed' and p_face_status = 'in_progress' then
      p_face_status := 'failed';
    end if;
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
      when public.identity_verifications.provider_reference is distinct from excluded.provider_reference
        and (excluded.aadhaar_status = 'in_progress' or excluded.face_status = 'in_progress')
        then now()
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

revoke all on function public.apply_kyc_checks(uuid, text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.apply_kyc_checks(uuid, text, text, text, text, text)
  to service_role;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261114170000',
  'kyc_idempotent_checks',
  array['docs/staging_apply_KYC_1114.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
