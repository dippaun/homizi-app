-- Run this once in the staging SQL editor. It is safe to run again.
--
-- Checked on 2026-10-16 against https://loraalfiuklespaldotd.supabase.co
-- as test@homizi.in (authenticated):
--
-- * GET /rest/v1/properties?status=eq.published&host_user_id=neq.<self>
--   returned HTTP 200 and the 40 seed rows (content-range 0-39/*).
--   Columns match the app select. RLS already allows a signed-in tenant
--   to read published homes that are not their own. No policy change.
-- * GET interests, matches, and contact_consents returned HTTP 200 and
--   empty arrays. get_contact_visibility is not called when there is no match.
-- * PATCH profiles (display_name, occupation, public_bio) returned HTTP 200.
--   Column grants already allow those three fields.
-- * POST tenant_preferences upsert returned HTTP 200. A missing row is not
--   an error. The previous ensure_own_account did not insert one.
-- * Anon GET properties, with Origin https://homizi.netlify.app, returned
--   HTTP 401 code 42501 "permission denied for table properties".
--   Access-Control-Allow-Origin echoed the site, so the browser can read
--   that body. Anon is not granted SELECT. That is intentional.
-- * CORS is not the failure. A dropped socket is not the failure either.
--   The app was mapping browser ClientException / Failed to fetch text onto
--   a generic offline sentence, which hid 42501 and other server causes.
--
-- This script only makes sure every account has an empty preferences row.
-- The app upserts that row on profile save, and it does not hide the 40
-- listings when the row is missing or blank.

create or replace function public.ensure_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := nullif(auth.jwt() ->> 'email', '');
begin
  if v_uid is null then
    raise exception 'Sign in before creating a profile.'
      using errcode = '42501';
  end if;
  insert into public.users (id) values (v_uid) on conflict (id) do nothing;
  insert into public.profiles (user_id) values (v_uid) on conflict (user_id) do nothing;
  insert into public.private_contacts (user_id, email)
  values (v_uid, v_email)
  on conflict (user_id) do update
  set email = coalesce(public.private_contacts.email, excluded.email);
  insert into public.tenant_preferences (user_id)
  values (v_uid)
  on conflict (user_id) do nothing;
end;
$$;

revoke all on function public.ensure_own_account() from public, anon;
grant execute on function public.ensure_own_account() to authenticated;

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
  insert into public.tenant_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

insert into public.tenant_preferences (user_id)
select id from public.users
on conflict (user_id) do nothing;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261016190000',
  'tenant_preferences_row',
  array['docs/staging_apply_fix_1016.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

do $homizi_fix_1016_check$
begin
  if position(
    'tenant_preferences' in pg_get_functiondef('public.ensure_own_account()'::regprocedure)
  ) = 0 then
    raise exception 'ensure_own_account does not insert tenant_preferences';
  end if;
end
$homizi_fix_1016_check$;
