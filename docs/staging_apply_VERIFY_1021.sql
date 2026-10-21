-- HOMIZI verification flags for Create Your Profile.
-- Paste this whole file into the staging SQL editor. Running it again is safe.
--
-- Adds the public nickname, optional company, and the four verification flags.
-- The legal name and the selfie path are owner-only: column SELECT is revoked,
-- and only security-definer functions can read them.
-- Do not store an Aadhaar number or a biometric selfie in profiles.
-- Age and gender are not scoring inputs. Matching must not read them.

alter table public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists nickname text,
  add column if not exists age smallint,
  add column if not exists gender text,
  add column if not exists company_name text,
  add column if not exists mobile_verified boolean not null default false,
  add column if not exists email_verified boolean not null default false,
  add column if not exists identity_verified boolean not null default false,
  add column if not exists selfie_verified boolean not null default false,
  add column if not exists show_photo_to_verified boolean not null default false,
  add column if not exists selfie_path text;

alter table public.profiles drop constraint if exists profiles_nickname_len;
alter table public.profiles
  add constraint profiles_nickname_len check (
    nickname is null or char_length(nickname) <= 80
  );

alter table public.profiles drop constraint if exists profiles_age_years;
alter table public.profiles
  add constraint profiles_age_years check (
    age is null or age between 18 and 100
  );

alter table public.profiles drop constraint if exists profiles_gender_choice;
alter table public.profiles
  add constraint profiles_gender_choice check (
    gender is null
    or gender in ('Woman', 'Man', 'Non-binary', 'Prefer not to say')
  );

alter table public.profiles drop constraint if exists profiles_company_name_len;
alter table public.profiles
  add constraint profiles_company_name_len check (
    company_name is null or char_length(company_name) <= 120
  );

comment on column public.profiles.nickname is
  'Public name. display_name is kept equal to this. Never the legal name.';

comment on column public.profiles.first_name is
  'Owner-only. Never shown on a public profile.';

comment on column public.profiles.last_name is
  'Owner-only. Never shown on a public profile.';

comment on column public.profiles.age is
  'Exact age the person entered. Not a matching score input.';

comment on column public.profiles.gender is
  'Optional self-description. Not a matching score input.';

comment on column public.profiles.selfie_path is
  'Owner-only reference. Bytes are not stored here. Other people receive it only from profile_photo_for_viewer.';

comment on column public.profiles.show_photo_to_verified is
  'Off by default. The selfie stays private until the person opts in.';

-- Column privileges hide the legal name and selfie even when the row is visible.
revoke select (first_name, last_name, selfie_path)
  on table public.profiles
  from public, anon, authenticated;

grant update (
  nickname,
  age,
  gender,
  company_name,
  mobile_verified,
  email_verified,
  identity_verified,
  selfie_verified,
  show_photo_to_verified
) on table public.profiles to authenticated;

create or replace function public.read_own_private_profile()
returns table (first_name text, last_name text, selfie_path text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return;
  end if;
  return query
    select p.first_name, p.last_name, p.selfie_path
    from public.profiles p
    where p.user_id = v_user;
end;
$$;

comment on function public.read_own_private_profile() is
  'Legal name and selfie path for the signed-in owner only.';

create or replace function public.profile_photo_for_viewer(p_user uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_viewer uuid := auth.uid();
  v_owner public.profiles;
  v_viewer_row public.profiles;
begin
  if v_viewer is null or p_user is null then
    return null;
  end if;
  select * into v_owner from public.profiles where user_id = p_user;
  if not found then
    return null;
  end if;
  if v_viewer = p_user then
    return v_owner.selfie_path;
  end if;
  if not v_owner.show_photo_to_verified then
    return null;
  end if;
  select * into v_viewer_row from public.profiles where user_id = v_viewer;
  if not found then
    return null;
  end if;
  if v_viewer_row.mobile_verified
     and v_viewer_row.email_verified
     and v_viewer_row.identity_verified
     and v_viewer_row.selfie_verified then
    return v_owner.selfie_path;
  end if;
  return null;
end;
$$;

comment on function public.profile_photo_for_viewer(uuid) is
  'Selfie path for the owner, or for a fully verified viewer when the owner opted in.';

create or replace function public.apply_profile_verification(
  p_nickname text,
  p_occupation text,
  p_age smallint,
  p_gender text,
  p_company_name text,
  p_first_name text,
  p_last_name text,
  p_mobile_verified boolean,
  p_email_verified boolean,
  p_identity_verified boolean,
  p_selfie_verified boolean,
  p_show_photo_to_verified boolean,
  p_selfie_path text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_nick text := left(btrim(coalesce(p_nickname, '')), 80);
  v_range text;
  v_verified boolean;
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;
  if p_age is not null and (p_age < 18 or p_age > 100) then
    raise exception 'age out of range';
  end if;
  v_range := case
    when p_age is null then null
    when p_age between 18 and 24 then '18-24'
    when p_age between 25 and 30 then '25-30'
    when p_age between 31 and 35 then '31-35'
    when p_age between 36 and 45 then '36-45'
    else '45+'
  end;
  v_verified := coalesce(p_mobile_verified, false)
    and coalesce(p_email_verified, false)
    and coalesce(p_identity_verified, false)
    and coalesce(p_selfie_verified, false);
  update public.profiles
  set
    display_name = v_nick,
    nickname = v_nick,
    occupation = nullif(left(btrim(coalesce(p_occupation, '')), 80), ''),
    age = p_age,
    age_range = v_range,
    gender = p_gender,
    company_name = nullif(left(btrim(coalesce(p_company_name, '')), 120), ''),
    first_name = nullif(left(btrim(coalesce(p_first_name, '')), 80), ''),
    last_name = nullif(left(btrim(coalesce(p_last_name, '')), 80), ''),
    mobile_verified = coalesce(p_mobile_verified, false),
    email_verified = coalesce(p_email_verified, false),
    identity_verified = coalesce(p_identity_verified, false),
    selfie_verified = coalesce(p_selfie_verified, false),
    show_photo_to_verified = coalesce(p_show_photo_to_verified, false),
    selfie_path = p_selfie_path,
    verification_status = case
      when v_verified then 'mock_verified'::public.verification_status
      else 'mock_pending'::public.verification_status
    end,
    updated_at = now()
  where user_id = v_user;
end;
$$;

comment on function public.apply_profile_verification(
  text, text, smallint, text, text, text, text,
  boolean, boolean, boolean, boolean, boolean, text
) is
  'Owner-only profile verification write. Does not accept an Aadhaar number.';

revoke all on function public.read_own_private_profile() from public;
revoke all on function public.profile_photo_for_viewer(uuid) from public;
revoke all on function public.apply_profile_verification(
  text, text, smallint, text, text, text, text,
  boolean, boolean, boolean, boolean, boolean, text
) from public;

grant execute on function public.read_own_private_profile() to authenticated;
grant execute on function public.profile_photo_for_viewer(uuid) to authenticated;
grant execute on function public.apply_profile_verification(
  text, text, smallint, text, text, text, text,
  boolean, boolean, boolean, boolean, boolean, text
) to authenticated;
