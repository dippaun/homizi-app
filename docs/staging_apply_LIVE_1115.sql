-- Homizi live feed for staging project loraalfiuklespaldotd.
-- NOT APPLIED. Paste this file in the Supabase SQL editor only after Deep
-- says yes. It is safe to run twice. It does not print or store a key.
--
-- Do not also paste the older docs/staging_apply_*.sql files listed below.
-- This file already contains that SQL, in order.
--
-- README — approve one section at a time
-- 20261111130000_chat_contact_guard
--   Refuses phone numbers and emails in chat, including numbers written as words.
-- 20261114120000_auth_contact_verification
--   Copies Auth confirmation times onto profiles and keeps one phone and one email per person.
-- 20261114170000_kyc_idempotent_checks
--   Stops a late KYC webhook from downgrading a verified or failed check.
-- 20261114180000_rent_splits
--   Stores a finished rent split for the person who saved it.
-- 20261114190000_shared_homes
--   Stores who already lives in a listed home, and join requests for free rooms.
-- 20261114200000_priorities_host
--   Stores the tenant search order and the host preferred-tenant profile.
-- 20261114210000_find_roomie
--   Stores homes a roommate pair saved together, and joint requests each person confirms.
-- 20261114220000_property_partner_applications
--   Stores one property-partner application per signed-in user.
-- 20261114233000_live_two_user
--   Lets anyone read published listings, shows a like to both people, creates a match on a mutual like, and publishes listings, likes, matches, and messages on realtime.
--
-- Already on staging, so they are not in this file:
--   20261016120000_ensure_own_account — the function and auth trigger exist;
--     the version row was not recorded. Re-applying is optional.
--   20261022120000, 20261022193000, 20261022200000, 20261029120000,
--     and 20261106160000 were applied under different version numbers.
--   20261111170000 persist_user_actions is on staging and is not in this repo.
--
-- The same SQL also lives in:
--   docs/staging_apply_CHAT_1111.sql
--   docs/staging_apply_OTP_1114.sql
--   docs/staging_apply_KYC_1114.sql
--   docs/staging_apply_RENTSPLIT_1114.sql
--   docs/staging_apply_OCCUPANCY_1114.sql
--   docs/staging_apply_PRIORITIES_HOST_1114.sql
--   docs/staging_apply_FINDROOMIE_1114.sql
--   docs/staging_apply_PARTNER_1114.sql
-- Paste this file instead of those eight.
--
-- 20261114120000 clears duplicate phone and email rows so the unique indexes
-- can be created. Read that section before saying yes.

-- -------------------------------------------------------------------------
-- 20261111130000_chat_contact_guard
-- Refuses phone numbers and emails in chat, including numbers written as words.
-- -------------------------------------------------------------------------

-- Stronger chat contact check on the existing messages table.
-- Replaces public.contains_contact_text. send_message and the messages_no_contact
-- check call this function, so a new row is refused without a second table.
-- Not applied to a hosted project from this change. See docs/CHAT_CONTACT.md
-- and docs/staging_apply_CHAT_1111.sql.

create or replace function public.contains_contact_text(p_body text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v text := lower(coalesce(p_body, ''));
  v_work text;
  v_piece text;
  v_digits text;
  v_found text[];
  k int;
  words text[] := array[
    'zero', 'oh', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'
  ];
  digits text[] := array['0', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  w int;
  v_len int;
  i int;
  gstart int;
  starts int[] := '{}';
  ends int[] := '{}';
  lens int[] := '{}';
  gi int;
  gj int;
  buf text;
  cursor_at int;
  gap text;
  gap_words text[];
  gap_word text;
  wordy boolean;
  soft boolean;
  blocked boolean;
    plus boolean;
    dictated boolean;
    nwords int;
    ch text;
begin
  if v ~ '[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}' then
    return true;
  end if;
  if v ~ '[a-z0-9._%+\-]{1,40}[[:space:]]*(\[at\]|\(at\))[[:space:]]*[a-z0-9\-]+([[:space:]]*\.[[:space:]]*|[[:space:]]*\[dot\][[:space:]]*|[[:space:]]*\(dot\)[[:space:]]*|[[:space:]]+dot[[:space:]]+)[a-z]{2,}' then
    return true;
  end if;
  if (
      v ~ 'e-?mail'
      or v ~ '(gmail|yahoo|outlook|hotmail|rediffmail|protonmail|icloud|googlemail|ymail)'
    )
    and v ~ '[[:<:]]at[[:>:]]'
    and v ~ '(\[dot\]|\(dot\)|[[:<:]]dot[[:>:]])' then
    return true;
  end if;
  if v ~ '(^|[^a-z0-9])(wa\.me|chat\.whatsapp\.com|api\.whatsapp\.com|whatsapp\.com|t\.me|telegram\.me|telegram\.dog)([^a-z0-9]|$)' then
    return true;
  end if;

  v_work := v;
  for w in 1..array_length(words, 1) loop
    v_work := regexp_replace(
      v_work,
      '[[:<:]]triple[[:space:]]+' || words[w] || '[[:>:]]',
      repeat(digits[w], 3),
      'g'
    );
    v_work := regexp_replace(
      v_work,
      '[[:<:]]double[[:space:]]+' || words[w] || '[[:>:]]',
      repeat(digits[w], 2),
      'g'
    );
  end loop;
  for w in 1..array_length(words, 1) loop
    v_work := regexp_replace(
      v_work,
      '[[:<:]]' || words[w] || '[[:>:]]',
      digits[w],
      'g'
    );
  end loop;
  for w in 0..9 loop
    v_work := regexp_replace(
      v_work,
      '[[:<:]]triple[[:space:]]+' || w::text || '[[:>:]]',
      repeat(w::text, 3),
      'g'
    );
    v_work := regexp_replace(
      v_work,
      '[[:<:]]double[[:space:]]+' || w::text || '[[:>:]]',
      repeat(w::text, 2),
      'g'
    );
  end loop;

  v_work := regexp_replace(v_work, '[[:<:]][0-9]+[[:space:]]*-?[[:space:]]*bhks?[[:>:]]', ' ', 'g');
  v_work := regexp_replace(v_work, '[[:<:]][0-9]+[[:space:]]*-?[[:space:]]*rks?[[:>:]]', ' ', 'g');
  v_work := regexp_replace(v_work, '[[:<:]](floor|fl)\.?[[:space:]]*[0-9]{1,2}[[:>:]]', ' ', 'g');
  v_work := regexp_replace(v_work, '[[:<:]][0-9]{1,2}(st|nd|rd|th)[[:space:]]+floor[[:>:]]', ' ', 'g');
  v_work := regexp_replace(
    v_work,
    '[[:<:]](pin[[:space:]]*code|pincode|pin|zip)[[:space:]]*[1-8][0-9]{5}[[:>:]]',
    ' ',
    'g'
  );
  v_work := regexp_replace(v_work, '[0-9]{1,2}[./-][0-9]{1,2}[./-][0-9]{2,4}', ' ', 'g');
  v_work := regexp_replace(v_work, '[0-9]{4}[./-][0-9]{1,2}[./-][0-9]{1,2}', ' ', 'g');
  v_work := regexp_replace(
    v_work,
    '[[:<:]][0-9]{1,2}(st|nd|rd|th)?[[:space:]]+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?(,[[:space:]]*[0-9]{2,4})?[[:>:]]',
    ' ',
    'g'
  );
  v_work := regexp_replace(
    v_work,
    '[[:<:]](jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?[[:space:]]+[0-9]{1,2}(st|nd|rd|th)?(,[[:space:]]*[0-9]{4})?[[:>:]]',
    ' ',
    'g'
  );
  v_work := regexp_replace(v_work, '[[:<:]][0-9]{1,2}:[0-9]{2}[[:>:]]', ' ', 'g');
  v_work := regexp_replace(v_work, '[[:<:]][0-9]{1,2}[[:space:]]*(am|pm)[[:>:]]', ' ', 'g');

  for w in 1..12 loop
    v_found := regexp_match(
      v_work,
      '((?:₹|rs\.?|inr)[[:space:]]*[0-9][0-9,]*(?:\.[0-9]{1,2})?)'
    );
    exit when v_found is null;
    v_piece := v_found[1];
    v_digits := regexp_replace(v_piece, '[^0-9]', '', 'g');
    if char_length(v_digits) >= 10 then
      v_work := replace(v_work, v_piece, v_digits);
    else
      v_work := replace(v_work, v_piece, ' ');
    end if;
  end loop;

  for w in 1..12 loop
    v_found := regexp_match(v_work, '([0-9]{1,3}(?:,[0-9]{2,3})+)');
    exit when v_found is null;
    v_piece := v_found[1];
    v_digits := regexp_replace(v_piece, '[^0-9]', '', 'g');
    if char_length(v_digits) >= 10 and char_length(v_digits) <= 15 then
      v_work := replace(v_work, v_piece, v_digits);
    else
      v_work := replace(v_work, v_piece, ' ');
    end if;
  end loop;

  v_len := char_length(v_work);
  i := 1;
  while i <= v_len loop
    ch := substr(v_work, i, 1);
    if ch ~ '[0-9]' then
      gstart := i;
      while i <= v_len and substr(v_work, i, 1) ~ '[0-9]' loop
        i := i + 1;
      end loop;
      starts := array_append(starts, gstart);
      ends := array_append(ends, i);
      lens := array_append(lens, i - gstart);
    else
      i := i + 1;
    end if;
  end loop;

  if starts is null or array_length(starts, 1) is null then
    return false;
  end if;

  for gi in 1..array_length(starts, 1) loop
    if lens[gi] >= 10 and lens[gi] <= 15 then
      return true;
    end if;
    if lens[gi] > 15 then
      continue;
    end if;
    plus := substring(v_work from 1 for starts[gi] - 1) ~ '\+[[:space:]]*$';
    buf := substr(v_work, starts[gi], lens[gi]);
    cursor_at := ends[gi];
    wordy := false;
    dictated := lens[gi] = 1;
    for gj in gi + 1..array_length(starts, 1) loop
      gap := substr(v_work, cursor_at, starts[gj] - cursor_at);
      blocked := false;
      soft := false;
      if char_length(gap) > 48 then
        blocked := true;
      elsif gap ~ '^[[:space:].+()/-]*$' then
        if char_length(gap) > 16 then
          blocked := true;
        else
          soft := true;
        end if;
      else
        gap_words := regexp_split_to_array(btrim(gap), '[[:space:]]+');
        nwords := coalesce(array_length(gap_words, 1), 0);
        if nwords = 0 then
          soft := true;
        elsif nwords > 3 then
          blocked := true;
        else
          soft := false;
          for k in 1..nwords loop
            gap_word := gap_words[k];
            if gap_word !~ '^[a-z'']{1,12}$' then
              blocked := true;
            end if;
          end loop;
          if not blocked then
            wordy := true;
          end if;
        end if;
      end if;
      exit when blocked;
      if char_length(buf) + lens[gj] > 15 then
        exit;
      end if;
      buf := buf || substr(v_work, starts[gj], lens[gj]);
      cursor_at := ends[gj];
      if lens[gj] = 1 then
        dictated := true;
      end if;
      if plus and char_length(buf) >= 10 then
        return true;
      end if;
      if dictated and char_length(buf) >= 10 then
        return true;
      end if;
      if (wordy or soft) and (
        (char_length(buf) = 10 and buf ~ '^[6-9]')
        or (char_length(buf) = 11 and buf ~ '^0')
        or (char_length(buf) = 12 and buf ~ '^91')
        or (char_length(buf) = 13 and buf ~ '^091')
        or (char_length(buf) = 14 and buf ~ '^0091')
      ) then
        return true;
      end if;
    end loop;
  end loop;

  return false;
end;
$$;

comment on function public.contains_contact_text(text) is
  'True for a phone, an email, or a wa.me / WhatsApp / Telegram link. Rents, dates, BHK, floors, and 6-digit pincodes stay false.';

revoke all on function public.contains_contact_text(text) from public, anon;
grant execute on function public.contains_contact_text(text) to authenticated;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261111130000',
  'chat_contact_guard',
  array['docs/staging_apply_LIVE_1115.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261114120000_auth_contact_verification
-- Copies Auth confirmation times onto profiles and keeps one phone and one email per person.
-- -------------------------------------------------------------------------

-- Mirror Auth confirmation timestamps onto profiles, and keep one phone
-- and one email per person. The client cannot write the timestamps.
-- Apply this file from the SQL editor when the owner approves it.
-- Do not run it from this change.

alter table public.profiles
  add column if not exists email_confirmed_at timestamptz,
  add column if not exists phone_confirmed_at timestamptz;

comment on column public.profiles.email_confirmed_at is
  'Copy of auth.users.email_confirmed_at. Written only by the auth.users trigger.';

comment on column public.profiles.phone_confirmed_at is
  'Copy of auth.users.phone_confirmed_at. Written only by the auth.users trigger.';

revoke update (email_confirmed_at, phone_confirmed_at)
  on public.profiles from anon, authenticated;

create or replace function public.reject_client_contact_verification_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- current_user is a keyword. pg_catalog.current_user is parsed as a column.
  if (select current_user) in ('authenticated', 'anon') then
    if new.email_confirmed_at is distinct from old.email_confirmed_at
      or new.phone_confirmed_at is distinct from old.phone_confirmed_at then
      raise exception 'email_confirmed_at and phone_confirmed_at are read-only'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_reject_verification_write on public.profiles;
create trigger profiles_reject_verification_write
  before update on public.profiles
  for each row execute function public.reject_client_contact_verification_write();

create schema if not exists private;

create or replace function private.sync_auth_contact()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles as p (user_id, email_confirmed_at, phone_confirmed_at)
  values (new.id, new.email_confirmed_at, new.phone_confirmed_at)
  on conflict (user_id) do update
    set email_confirmed_at = excluded.email_confirmed_at,
        phone_confirmed_at = excluded.phone_confirmed_at,
        updated_at = pg_catalog.now();

  insert into public.private_contacts as c (user_id, email, phone)
  values (
    new.id,
    case when new.email_confirmed_at is not null then new.email else null end,
    case when new.phone_confirmed_at is not null then new.phone else null end
  )
  on conflict (user_id) do update
    set email = case
          when excluded.email is not null then excluded.email
          else c.email
        end,
        phone = case
          when excluded.phone is not null then excluded.phone
          else c.phone
        end,
        updated_at = pg_catalog.now();
  return new;
end;
$$;

revoke all on function private.sync_auth_contact() from public, anon, authenticated;

drop trigger if exists zz_sync_auth_contact on auth.users;
create trigger zz_sync_auth_contact
  after insert or update of email, phone, email_confirmed_at, phone_confirmed_at
  on auth.users
  for each row execute function private.sync_auth_contact();

-- Read-only copy of the caller's Auth confirmation. Not exposed: the private
-- schema is not in the Data API. The app reads the session user instead.
create or replace function private.own_contact_verification()
returns table (
  email text,
  phone text,
  email_confirmed_at timestamptz,
  phone_confirmed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select u.email::text, u.phone::text, u.email_confirmed_at, u.phone_confirmed_at
  from auth.users as u
  where u.id = auth.uid();
$$;

revoke all on function private.own_contact_verification() from public, anon, authenticated;

update public.profiles as p
set email_confirmed_at = u.email_confirmed_at,
    phone_confirmed_at = u.phone_confirmed_at
from auth.users as u
where u.id = p.user_id;

with ranked as (
  select
    user_id,
    row_number() over (
      partition by lower(email)
      order by updated_at, user_id
    ) as n
  from public.private_contacts
  where email is not null and btrim(email) <> ''
)
update public.private_contacts as c
set email = null
from ranked as r
where c.user_id = r.user_id and r.n > 1;

with ranked as (
  select
    user_id,
    row_number() over (
      partition by phone
      order by updated_at, user_id
    ) as n
  from public.private_contacts
  where phone is not null and btrim(phone) <> ''
)
update public.private_contacts as c
set phone = null
from ranked as r
where c.user_id = r.user_id and r.n > 1;

create unique index if not exists private_contacts_email_unique
  on public.private_contacts (lower(email))
  where email is not null;

create unique index if not exists private_contacts_phone_unique
  on public.private_contacts (phone)
  where phone is not null;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261114120000',
  'auth_contact_verification',
  array['docs/staging_apply_LIVE_1115.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261114170000_kyc_idempotent_checks
-- Stops a late KYC webhook from downgrading a verified or failed check.
-- -------------------------------------------------------------------------

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
  array['docs/staging_apply_LIVE_1115.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261114180000_rent_splits
-- Stores a finished rent split for the person who saved it.
-- -------------------------------------------------------------------------

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

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261114180000',
  'rent_splits',
  array['docs/staging_apply_LIVE_1115.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261114190000_shared_homes
-- Stores who already lives in a listed home, and join requests for free rooms.
-- -------------------------------------------------------------------------

-- Occupancy + Shared home (Nov 14, 2026). NOT APPLIED: the owner applies it.
-- Who already lives in a listed home and which rooms are free, plus join
-- requests from seekers. The app works without these tables: sample homes
-- and device copies are used, and a join request still sends the normal
-- interest the host sees under Interested seekers.
-- First names and last initials only. No phone, email, or ID numbers.

create table if not exists public.shared_home_details (
  listing_id uuid primary key references public.properties (id) on delete cascade,
  host_user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_label text not null check (char_length(btrim(property_label)) between 2 and 20),
  total_rooms smallint not null check (total_rooms between 1 and 10),
  currently_living smallint not null default 0 check (currently_living between 0 and 20),
  vacant_rooms smallint not null check (vacant_rooms between 0 and 10),
  total_capacity smallint not null check (total_capacity between 1 and 20),
  occupancy_type text not null default 'separate'
    check (occupancy_type in ('single', 'double', 'separate')),
  housemates jsonb not null default '[]'::jsonb
    check (jsonb_typeof(housemates) = 'array' and jsonb_array_length(housemates) <= 6),
  updated_at timestamptz not null default now(),
  constraint shared_home_details_rooms check (vacant_rooms <= total_rooms),
  constraint shared_home_details_capacity check (currently_living <= total_capacity),
  constraint shared_home_details_no_contact check (
    housemates::text !~ '@' and housemates::text !~ '[0-9]{10}'
  )
);

alter table public.shared_home_details enable row level security;

drop policy if exists shared_home_details_read on public.shared_home_details;
create policy shared_home_details_read on public.shared_home_details
  for select to authenticated
  using (
    host_user_id = auth.uid()
    or exists (
      select 1 from public.properties p
      where p.id = listing_id and p.status = 'published'
    )
  );

drop policy if exists shared_home_details_insert_own on public.shared_home_details;
create policy shared_home_details_insert_own on public.shared_home_details
  for insert to authenticated
  with check (
    host_user_id = auth.uid()
    and exists (
      select 1 from public.properties p
      where p.id = listing_id and p.host_user_id = auth.uid()
    )
  );

drop policy if exists shared_home_details_update_own on public.shared_home_details;
create policy shared_home_details_update_own on public.shared_home_details
  for update to authenticated
  using (host_user_id = auth.uid())
  with check (
    host_user_id = auth.uid()
    and exists (
      select 1 from public.properties p
      where p.id = listing_id and p.host_user_id = auth.uid()
    )
  );

drop policy if exists shared_home_details_delete_own on public.shared_home_details;
create policy shared_home_details_delete_own on public.shared_home_details
  for delete to authenticated
  using (host_user_id = auth.uid());

revoke all on public.shared_home_details from anon;
grant select, insert, update, delete on public.shared_home_details to authenticated;
grant all on public.shared_home_details to service_role;

create table if not exists public.shared_home_join_requests (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.properties (id) on delete cascade,
  requester_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  host_user_id uuid references auth.users (id) on delete cascade,
  requester_first_name text not null default 'A HOMIZI member'
    check (char_length(btrim(requester_first_name)) between 1 and 30
      and requester_first_name !~ '@'
      and requester_first_name !~ '[0-9]{6}'),
  mode text not null default 'individual' check (mode in ('individual', 'group')),
  people smallint not null default 1 check (people between 1 and 6),
  share_inr integer not null default 0 check (share_inr between 0 and 10000000),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'withdrawn', 'moved_in')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  moved_in_at timestamptz
);

create unique index if not exists shared_home_join_requests_open_idx
  on public.shared_home_join_requests (listing_id, requester_id)
  where status in ('pending', 'accepted', 'moved_in');

create index if not exists shared_home_join_requests_host_idx
  on public.shared_home_join_requests (host_user_id, created_at desc);

-- Fills the host from the listing and keeps status changes to the ones each
-- side may make: the host accepts or declines a pending request; the seeker
-- withdraws, or moves in after it was accepted. Nothing else changes.
create or replace function public.shared_home_join_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  host uuid;
begin
  if tg_op = 'INSERT' then
    select p.host_user_id into host
    from public.properties p
    where p.id = new.listing_id and p.status = 'published';
    if host is null then
      raise exception 'This home is not open for join requests.'
        using errcode = '42501';
    end if;
    if actor is not null and host = actor then
      raise exception 'You cannot join your own home.' using errcode = '42501';
    end if;
    new.host_user_id := host;
    new.status := 'pending';
    new.decided_at := null;
    new.moved_in_at := null;
    new.created_at := now();
    return new;
  end if;

  if new.listing_id is distinct from old.listing_id
    or new.requester_id is distinct from old.requester_id
    or new.host_user_id is distinct from old.host_user_id
    or new.requester_first_name is distinct from old.requester_first_name
    or new.mode is distinct from old.mode
    or new.people is distinct from old.people
    or new.share_inr is distinct from old.share_inr
    or new.created_at is distinct from old.created_at then
    raise exception 'Only the status of a join request can change.'
      using errcode = '42501';
  end if;

  if new.status = old.status or actor is null then
    return new;
  end if;

  if actor = old.host_user_id
    and old.status = 'pending'
    and new.status in ('accepted', 'declined') then
    new.decided_at := now();
    return new;
  end if;

  if actor = old.requester_id
    and (
      (old.status = 'pending' and new.status = 'withdrawn')
      or (old.status = 'accepted' and new.status in ('moved_in', 'withdrawn'))
    ) then
    if new.status = 'moved_in' then
      new.moved_in_at := now();
    end if;
    return new;
  end if;

  raise exception 'That status change is not allowed.' using errcode = '42501';
end;
$$;

revoke all on function public.shared_home_join_guard() from public, anon, authenticated;

drop trigger if exists shared_home_join_guard on public.shared_home_join_requests;
create trigger shared_home_join_guard
  before insert or update on public.shared_home_join_requests
  for each row execute function public.shared_home_join_guard();

alter table public.shared_home_join_requests enable row level security;

drop policy if exists shared_home_join_read on public.shared_home_join_requests;
create policy shared_home_join_read on public.shared_home_join_requests
  for select to authenticated
  using (requester_id = auth.uid() or host_user_id = auth.uid());

drop policy if exists shared_home_join_insert_own on public.shared_home_join_requests;
create policy shared_home_join_insert_own on public.shared_home_join_requests
  for insert to authenticated
  with check (requester_id = auth.uid());

drop policy if exists shared_home_join_update_party on public.shared_home_join_requests;
create policy shared_home_join_update_party on public.shared_home_join_requests
  for update to authenticated
  using (requester_id = auth.uid() or host_user_id = auth.uid())
  with check (requester_id = auth.uid() or host_user_id = auth.uid());

revoke all on public.shared_home_join_requests from anon;
grant select, insert, update on public.shared_home_join_requests to authenticated;
grant all on public.shared_home_join_requests to service_role;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261114190000',
  'shared_homes',
  array['docs/staging_apply_LIVE_1115.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261114200000_priorities_host
-- Stores the tenant search order and the host preferred-tenant profile.
-- -------------------------------------------------------------------------

-- Priorities + Host journey (Nov 14, 2026). NOT APPLIED: the owner applies it.
-- One row per user and side: the tenant's ranked search priorities, or the
-- host's preferred tenant profile. The app works without this table: both
-- are kept on the device and the older priority_rank order is still written.
-- No phone numbers or email addresses are stored here.

create table if not exists public.priority_preferences (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  side text not null check (side in ('tenant', 'host')),
  ranked text[] not null check (cardinality(ranked) between 1 and 8),
  must_have text[] not null default '{}',
  order_all text[] not null default '{}' check (cardinality(order_all) <= 8),
  prefs jsonb not null default '{}'::jsonb check (jsonb_typeof(prefs) = 'object'),
  updated_at timestamptz not null default now(),
  primary key (user_id, side),
  constraint priority_preferences_wires check (
    (side = 'tenant'
      and ranked <@ array['budget', 'occupancy', 'location', 'move_in', 'gender',
        'property_type', 'lifestyle', 'furnishing']::text[]
      and must_have <@ ranked
      and order_all <@ array['budget', 'occupancy', 'location', 'move_in', 'gender',
        'property_type', 'lifestyle', 'furnishing']::text[])
    or (side = 'host'
      and ranked <@ array['budget', 'move_in', 'working_professional', 'vegetarian',
        'gender_age', 'non_smoker', 'non_drinker', 'long_stay']::text[]
      and must_have <@ ranked
      and order_all <@ array['budget', 'move_in', 'working_professional', 'vegetarian',
        'gender_age', 'non_smoker', 'non_drinker', 'long_stay']::text[])
  ),
  constraint priority_preferences_no_contact check (
    (prefs - 'property_id')::text !~ '@'
    and (prefs - 'property_id')::text !~ '[0-9]{10}'
  )
);

alter table public.priority_preferences enable row level security;

drop policy if exists priority_preferences_own_read on public.priority_preferences;
create policy priority_preferences_own_read on public.priority_preferences
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists priority_preferences_own_insert on public.priority_preferences;
create policy priority_preferences_own_insert on public.priority_preferences
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists priority_preferences_own_update on public.priority_preferences;
create policy priority_preferences_own_update on public.priority_preferences
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists priority_preferences_own_delete on public.priority_preferences;
create policy priority_preferences_own_delete on public.priority_preferences
  for delete to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.priority_preferences_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists priority_preferences_touch on public.priority_preferences;
create trigger priority_preferences_touch
  before update on public.priority_preferences
  for each row execute function public.priority_preferences_touch();

revoke all on public.priority_preferences from anon;
grant select, insert, update, delete on public.priority_preferences to authenticated;
grant all on public.priority_preferences to service_role;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261114200000',
  'priorities_host',
  array['docs/staging_apply_LIVE_1115.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261114210000_find_roomie
-- Stores homes a roommate pair saved together, and joint requests each person confirms.
-- -------------------------------------------------------------------------

-- Find Your Roomie (Nov 14, 2026). NOT APPLIED: the owner applies it.
-- Homes a pair saved together, and a joint request that each person confirms
-- for themselves. The app works without these tables: sample people and
-- homes stay on the device. No phone, email, or street address is stored.
-- Does not change shared_home_join_requests.

create table if not exists public.roommate_shortlists (
  id uuid primary key default gen_random_uuid(),
  match_id uuid references public.matches (id) on delete set null,
  member_a uuid not null references auth.users (id) on delete cascade,
  member_b uuid not null references auth.users (id) on delete cascade,
  listing_id text not null,
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default pg_catalog.now(),
  constraint roommate_shortlists_ordered check (member_a < member_b),
  constraint roommate_shortlists_actor check (
    created_by = member_a or created_by = member_b
  ),
  constraint roommate_shortlists_listing check (
    char_length(btrim(listing_id)) between 1 and 80
    and listing_id !~ '@'
    and listing_id !~ '\+'
  ),
  constraint roommate_shortlists_pair_listing unique (member_a, member_b, listing_id)
);

comment on table public.roommate_shortlists is
  'Homes a roommate pair saved to look at together. No contact details.';

alter table public.roommate_shortlists enable row level security;

drop policy if exists roommate_shortlists_read on public.roommate_shortlists;
create policy roommate_shortlists_read on public.roommate_shortlists
  for select to authenticated
  using (member_a = auth.uid() or member_b = auth.uid());

drop policy if exists roommate_shortlists_insert on public.roommate_shortlists;
create policy roommate_shortlists_insert on public.roommate_shortlists
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and (member_a = auth.uid() or member_b = auth.uid())
  );

drop policy if exists roommate_shortlists_delete on public.roommate_shortlists;
create policy roommate_shortlists_delete on public.roommate_shortlists
  for delete to authenticated
  using (member_a = auth.uid() or member_b = auth.uid());

revoke all on public.roommate_shortlists from anon;
grant select, insert, delete on public.roommate_shortlists to authenticated;
grant all on public.roommate_shortlists to service_role;

create index if not exists roommate_shortlists_member_b_idx
  on public.roommate_shortlists (member_b);

create table if not exists public.roommate_joint_requests (
  id uuid primary key default gen_random_uuid(),
  match_id uuid references public.matches (id) on delete set null,
  member_a uuid not null references auth.users (id) on delete cascade,
  member_b uuid not null references auth.users (id) on delete cascade,
  listing_id text not null,
  member_a_confirmed boolean not null default false,
  member_b_confirmed boolean not null default false,
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint roommate_joint_requests_ordered check (member_a < member_b),
  constraint roommate_joint_requests_actor check (
    created_by = member_a or created_by = member_b
  ),
  constraint roommate_joint_requests_listing check (
    char_length(btrim(listing_id)) between 1 and 80
    and listing_id !~ '@'
    and listing_id !~ '\+'
  ),
  constraint roommate_joint_requests_pair_listing unique (member_a, member_b, listing_id)
);

comment on table public.roommate_joint_requests is
  'One home a pair asked for. Each person can confirm only their own flag.';

-- Keeps a person from confirming for their roommate, and from rewriting
-- who the pair is. Runs as the table owner so the client cannot call it.
create or replace function public.roommate_joint_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null
    or (actor is distinct from new.member_a and actor is distinct from new.member_b) then
    raise exception 'Only the two people in this pair can change it.'
      using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    new.created_by := actor;
    new.created_at := pg_catalog.now();
    new.updated_at := pg_catalog.now();
    if actor = new.member_a then
      new.member_b_confirmed := false;
    else
      new.member_a_confirmed := false;
    end if;
    return new;
  end if;

  if new.id is distinct from old.id
    or new.member_a is distinct from old.member_a
    or new.member_b is distinct from old.member_b
    or new.listing_id is distinct from old.listing_id
    or new.match_id is distinct from old.match_id
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at then
    raise exception 'Only a confirmation flag can change.'
      using errcode = '42501';
  end if;

  if actor = old.member_a
    and new.member_b_confirmed is distinct from old.member_b_confirmed then
    raise exception 'You can only confirm for yourself.'
      using errcode = '42501';
  end if;

  if actor = old.member_b
    and new.member_a_confirmed is distinct from old.member_a_confirmed then
    raise exception 'You can only confirm for yourself.'
      using errcode = '42501';
  end if;

  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

revoke all on function public.roommate_joint_guard() from public, anon, authenticated;

drop trigger if exists roommate_joint_guard on public.roommate_joint_requests;
create trigger roommate_joint_guard
  before insert or update on public.roommate_joint_requests
  for each row execute function public.roommate_joint_guard();

alter table public.roommate_joint_requests enable row level security;

drop policy if exists roommate_joint_read on public.roommate_joint_requests;
create policy roommate_joint_read on public.roommate_joint_requests
  for select to authenticated
  using (member_a = auth.uid() or member_b = auth.uid());

drop policy if exists roommate_joint_insert on public.roommate_joint_requests;
create policy roommate_joint_insert on public.roommate_joint_requests
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and (member_a = auth.uid() or member_b = auth.uid())
  );

drop policy if exists roommate_joint_update on public.roommate_joint_requests;
create policy roommate_joint_update on public.roommate_joint_requests
  for update to authenticated
  using (member_a = auth.uid() or member_b = auth.uid())
  with check (member_a = auth.uid() or member_b = auth.uid());

drop policy if exists roommate_joint_delete on public.roommate_joint_requests;
create policy roommate_joint_delete on public.roommate_joint_requests
  for delete to authenticated
  using (member_a = auth.uid() or member_b = auth.uid());

revoke all on public.roommate_joint_requests from anon;
grant select, insert, update, delete on public.roommate_joint_requests to authenticated;
grant all on public.roommate_joint_requests to service_role;

create index if not exists roommate_joint_requests_member_b_idx
  on public.roommate_joint_requests (member_b);

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261114210000',
  'find_roomie',
  array['docs/staging_apply_LIVE_1115.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261114220000_property_partner_applications
-- Stores one property-partner application per signed-in user.
-- -------------------------------------------------------------------------

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

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261114220000',
  'property_partner_applications',
  array['docs/staging_apply_LIVE_1115.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


-- -------------------------------------------------------------------------
-- 20261114233000_live_two_user
-- Lets anyone read published listings, shows a like to both people, creates a match on a mutual like, and publishes listings, likes, matches, and messages on realtime.
-- -------------------------------------------------------------------------

-- Live two-user feed. NOT APPLIED to staging: the owner pastes
-- docs/staging_apply_LIVE_1115.sql after saying yes.
--
-- Published homes, including PG and shared rooms, are readable by anyone
-- through public.public_listings(). Direct SELECT on properties stays
-- denied for anon, so drafts and street addresses stay hidden.
-- A like is visible to the sender and the person they liked, and to nobody else.
-- Inserting the second like creates one match. properties, interests, and
-- matches join the realtime publication. Listing-photo policies are confirmed,
-- and a published photo can be read without signing in.

create schema if not exists private;

-- ---------------------------------------------------------------------------
-- Published listings. Security definer stays in private. The public wrapper
-- is invoker and returns only the card columns. No phone, email, or street.
-- ---------------------------------------------------------------------------

create or replace function private.published_listing_rows()
returns table (
  id uuid,
  host_user_id uuid,
  title text,
  locality text,
  city text,
  rent_inr integer,
  deposit_inr integer,
  maintenance_inr integer,
  brokerage_inr integer,
  furnishing public.furnishing,
  property_type public.property_type,
  occupancy_max smallint,
  available_from date,
  published_at timestamptz,
  area_sqft integer,
  preferred_tenants text[],
  parking boolean,
  pets_allowed boolean,
  non_veg_allowed boolean,
  gated_society boolean,
  floor_no smallint,
  total_floors smallint,
  approx_latitude numeric,
  approx_longitude numeric,
  listing_verified boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.host_user_id,
    p.title,
    p.locality,
    p.city,
    p.rent_inr,
    p.deposit_inr,
    p.maintenance_inr,
    p.brokerage_inr,
    p.furnishing,
    p.property_type,
    p.occupancy_max,
    p.available_from,
    p.published_at,
    p.area_sqft,
    p.preferred_tenants,
    p.parking,
    p.pets_allowed,
    p.non_veg_allowed,
    p.gated_society,
    p.floor_no,
    p.total_floors,
    p.approx_latitude,
    p.approx_longitude,
    p.listing_verified
  from public.properties p
  where p.status = 'published'
    and not public.is_blocked_with(p.host_user_id);
$$;

revoke all on function private.published_listing_rows() from public, anon, authenticated;
grant execute on function private.published_listing_rows() to anon, authenticated;

create or replace function public.public_listings()
returns table (
  id uuid,
  host_user_id uuid,
  title text,
  locality text,
  city text,
  rent_inr integer,
  deposit_inr integer,
  maintenance_inr integer,
  brokerage_inr integer,
  furnishing public.furnishing,
  property_type public.property_type,
  occupancy_max smallint,
  available_from date,
  published_at timestamptz,
  area_sqft integer,
  preferred_tenants text[],
  parking boolean,
  pets_allowed boolean,
  non_veg_allowed boolean,
  gated_society boolean,
  floor_no smallint,
  total_floors smallint,
  approx_latitude numeric,
  approx_longitude numeric,
  listing_verified boolean
)
language sql
stable
security invoker
set search_path = public, private
as $$
  select * from private.published_listing_rows();
$$;

comment on function public.public_listings() is
  'Published listing cards for anon and authenticated. Verification is not required. Contact and street address are not returned.';

revoke all on function public.public_listings() from public;
grant execute on function public.public_listings() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Likes. The sender and the person they liked can read a like. Passes and
-- saves stay with the sender. Nobody else can read the row.
-- ---------------------------------------------------------------------------

drop policy if exists interests_select_own on public.interests;
drop policy if exists interests_select_parties on public.interests;
create policy interests_select_parties
  on public.interests
  for select
  to authenticated
  using (
    actor_user_id = auth.uid()
    or (
      action = 'like'
      and (
        (target_type = 'user' and target_id = auth.uid())
        or (
          target_type = 'property'
          and exists (
            select 1
            from public.properties p
            where p.id = interests.target_id
              and p.host_user_id = auth.uid()
          )
        )
        or (
          target_type = 'listing_requirement'
          and exists (
            select 1
            from public.listing_requirements r
            where r.id = interests.target_id
              and r.user_id = auth.uid()
          )
        )
      )
    )
  );

-- ---------------------------------------------------------------------------
-- Mutual like. create_interest already calls _try_mutual_match. This trigger
-- covers a direct insert as well. The function is idempotent, so both paths
-- leave one match row.
-- ---------------------------------------------------------------------------

create or replace function private.interests_try_mutual_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  if new.action is distinct from 'like'::public.interest_action then
    return new;
  end if;

  if new.target_type = 'property' then
    select p.host_user_id into v_owner
    from public.properties p
    where p.id = new.target_id;
  elsif new.target_type = 'listing_requirement' then
    select r.user_id into v_owner
    from public.listing_requirements r
    where r.id = new.target_id;
  elsif new.target_type = 'user' then
    v_owner := new.target_id;
  end if;

  if v_owner is not null and v_owner is distinct from new.actor_user_id then
    perform public._try_mutual_match(new.actor_user_id, v_owner);
  end if;
  return new;
end;
$$;

revoke all on function private.interests_try_mutual_match() from public, anon, authenticated;

drop trigger if exists interests_try_mutual_match on public.interests;
create trigger interests_try_mutual_match
  after insert on public.interests
  for each row execute function private.interests_try_mutual_match();

-- ---------------------------------------------------------------------------
-- Realtime. Messages are already published. Add the feed tables.
-- ---------------------------------------------------------------------------

alter table public.properties replica identity full;
alter table public.interests replica identity full;
alter table public.matches replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    raise notice 'supabase_realtime publication missing; live feed skipped';
    return;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'properties'
  ) then
    alter publication supabase_realtime add table public.properties;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'interests'
  ) then
    alter publication supabase_realtime add table public.interests;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'matches'
  ) then
    alter publication supabase_realtime add table public.matches;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
exception
  when insufficient_privilege then
    raise notice 'realtime publication update skipped: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- Contact stays behind get_contact_visibility. Confirm anon cannot read it.
-- ---------------------------------------------------------------------------

revoke all on public.private_contacts from anon, public;

-- ---------------------------------------------------------------------------
-- Listing photos. Confirm the owner policies, and let anon read a photo only
-- when it is attached to a published listing. The bucket stays private.
-- ---------------------------------------------------------------------------

create or replace function private.listing_photo_is_published(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.property_photos ph
    join public.properties p on p.id = ph.property_id
    where ph.storage_path = p_name
      and p.status = 'published'
  );
$$;

revoke all on function private.listing_photo_is_published(text) from public;
grant execute on function private.listing_photo_is_published(text) to anon, authenticated;

do $homizi_live_photos$
declare
  v_stmt text;
  v_stmts text[] := array[
    $sql$
      insert into storage.buckets (id, name, public)
      values ('listing-photos', 'listing-photos', false)
      on conflict (id) do update
      set public = false,
          file_size_limit = 5242880,
          allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
    $sql$,
    $sql$drop policy if exists listing_photos_insert on storage.objects$sql$,
    $sql$drop policy if exists listing_photos_select on storage.objects$sql$,
    $sql$drop policy if exists listing_photos_update on storage.objects$sql$,
    $sql$drop policy if exists listing_photos_delete on storage.objects$sql$,
    $sql$drop policy if exists listing_photos_select_published_anon on storage.objects$sql$,
    $sql$
      create policy listing_photos_insert on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $sql$,
    $sql$
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
    $sql$,
    $sql$
      create policy listing_photos_update on storage.objects
      for update to authenticated
      using (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
      with check (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $sql$,
    $sql$
      create policy listing_photos_delete on storage.objects
      for delete to authenticated
      using (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $sql$,
    $sql$
      create policy listing_photos_select_published_anon on storage.objects
      for select to anon
      using (
        bucket_id = 'listing-photos'
        and private.listing_photo_is_published(name)
      )
    $sql$
  ];
begin
  if to_regclass('storage.buckets') is null
     or to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; listing-photos policies skipped';
    return;
  end if;
  foreach v_stmt in array v_stmts loop
    execute v_stmt;
  end loop;
exception
  when insufficient_privilege then
    raise notice 'listing-photos policies skipped: %', sqlerrm;
end
$homizi_live_photos$;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261114233000',
  'live_two_user',
  array['docs/staging_apply_LIVE_1115.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

-- -------------------------------------------------------------------------
-- ROLLBACK
-- Do not run the block below with the apply sections. It deletes the rows
-- those sections store. To roll back, copy from ROLLBACK START through
-- ROLLBACK END into a new SQL editor tab, then run only that tab.
-- Replaced functions (chat contact check, KYC, auth sync) are not restored
-- to their previous bodies. Dropping the new tables and the live-feed
-- objects is the reversible part.
-- -------------------------------------------------------------------------
/*
-- ROLLBACK START
drop trigger if exists interests_try_mutual_match on public.interests;
drop function if exists private.interests_try_mutual_match();
drop function if exists public.public_listings();
drop function if exists private.published_listing_rows();
drop function if exists private.listing_photo_is_published(text);

drop policy if exists interests_select_parties on public.interests;
create policy interests_select_own
  on public.interests
  for select to authenticated
  using (actor_user_id = auth.uid());

drop policy if exists listing_photos_select_published_anon on storage.objects;

alter publication supabase_realtime drop table public.properties;
alter publication supabase_realtime drop table public.interests;
alter publication supabase_realtime drop table public.matches;

drop table if exists public.property_partner_applications;
drop table if exists public.roommate_joint_requests;
drop table if exists public.roommate_shortlists;
drop table if exists public.priority_preferences;
drop table if exists public.shared_home_join_requests;
drop table if exists public.shared_home_details;
drop table if exists public.rent_splits;

drop trigger if exists zz_sync_auth_contact on auth.users;
drop trigger if exists profiles_reject_verification_write on public.profiles;
alter table public.profiles
  drop column if exists email_confirmed_at,
  drop column if exists phone_confirmed_at;

delete from supabase_migrations.schema_migrations
where version in (
  '20261111130000',
  '20261114120000',
  '20261114170000',
  '20261114180000',
  '20261114190000',
  '20261114200000',
  '20261114210000',
  '20261114220000',
  '20261114233000'
);
-- ROLLBACK END
*/
