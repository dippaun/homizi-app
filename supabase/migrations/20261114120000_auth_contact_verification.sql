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
  if pg_catalog.current_user in ('authenticated', 'anon') then
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
