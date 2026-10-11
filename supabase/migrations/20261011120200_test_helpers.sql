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
