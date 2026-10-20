-- Staging-only fresh testers: qa+<suffix>@homizi.in and test<N>@homizi.in.
-- N is 1 to 9999. The shared test@homizi.in mailbox is refused.
-- Creates an email-confirmed auth user with no chosen role.
-- The auth trigger may insert an empty profile. users.primary_role stays
-- unset, and profiles.primary_role stays null, so the role picker opens.
--
-- This file does not insert staging_flags.test_accounts_enabled.
-- Production stays off because that row is absent.
-- docs/staging_apply_M_1019.sql inserts the flag on the Mumbai project.
-- The mailbox password is read from private.staging_secrets key test_password.
-- Set that row once by hand. This file does not insert or replace it.

create table if not exists public.staging_flags (
  key text primary key,
  enabled boolean not null,
  updated_at timestamptz not null default now(),
  constraint staging_flags_key_check check (key ~ '^[a-z][a-z0-9_]{0,63}$')
);

comment on table public.staging_flags is
  'Staging switches. The test_accounts_enabled row is inserted only by docs/staging_apply_M_1019.sql. Production leaves this table empty.';

alter table public.staging_flags enable row level security;

revoke all on table public.staging_flags from public, anon, authenticated;

-- Staging test password. Set once by hand. Later scripts do not replace it.
-- service_role can read and insert. anon and authenticated cannot.
-- staging_create_test_user reads the row as security definer.

create schema if not exists private;

revoke all on schema private from public, anon, authenticated;

grant usage on schema private to service_role;

create table if not exists private.staging_secrets (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now(),
  constraint staging_secrets_key_check check (key ~ '^[a-z][a-z0-9_]{0,63}$')
);

comment on table private.staging_secrets is
  'Staging-only values set once by hand. Scripts do not replace an existing row. service_role can read and insert. anon and authenticated cannot.';

alter table private.staging_secrets enable row level security;

revoke all on table private.staging_secrets from public, anon, authenticated;

grant select, insert on table private.staging_secrets to service_role;

create or replace function public.staging_create_test_user(p_email text)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_uid uuid;
  v_existing uuid;
  v_instance uuid;
  v_password text;
  v_today integer;
  cols text[] := array['id'];
  vals text[];
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
  id_cols text[];
  id_vals text[];
begin
  if v_email !~ '^qa\+[a-z0-9-]{1,32}@homizi\.in$'
     and v_email !~ '^test[1-9][0-9]{0,3}@homizi\.in$' then
    raise exception 'That email is not a staging test mailbox.'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.staging_flags
    where key = 'test_accounts_enabled'
      and enabled is true
  ) then
    raise exception 'Staging test accounts are off.'
      using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(841019, hashtext(v_email));

  select id
  into v_existing
  from auth.users
  where lower(email) = v_email
  limit 1;

  if v_existing is not null then
    return v_existing;
  end if;

  select value
  into v_password
  from private.staging_secrets
  where key = 'test_password';

  if v_password is null or btrim(v_password) = '' then
    raise exception 'The staging test password has not been set.'
      using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(841019, 50);

  select count(*)::integer
  into v_today
  from auth.users
  where (
      email ~ '^qa\+[a-z0-9-]{1,32}@homizi\.in$'
      or email ~ '^test[1-9][0-9]{0,3}@homizi\.in$'
    )
    and created_at >= (date_trunc('day', (now() at time zone 'utc')) at time zone 'utc');

  if v_today >= 50 then
    raise exception 'The daily staging test account limit was reached.'
      using errcode = '54000';
  end if;

  if to_regclass('auth.users') is null
     or to_regclass('auth.identities') is null then
    raise exception 'Auth tables are not available.'
      using errcode = '55000';
  end if;

  v_uid := gen_random_uuid();
  vals := array[quote_literal(v_uid) || '::uuid'];

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'instance_id'
  ) then
    select instance_id
    into v_instance
    from auth.users
    where instance_id is not null
    limit 1;
    if v_instance is null then
      v_instance := '00000000-0000-0000-0000-000000000000';
    end if;
    cols := array_append(cols, 'instance_id');
    vals := array_append(vals, quote_literal(v_instance) || '::uuid');
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
    vals := array_append(
      vals,
      'extensions.crypt(' || quote_literal(v_password) || ', extensions.gen_salt(''bf''))'
    );
  else
    raise exception 'auth.users.encrypted_password is missing.'
      using errcode = '55000';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_app_meta_data'
  ) then
    cols := array_append(cols, 'raw_app_meta_data');
    vals := array_append(
      vals,
      quote_literal('{"provider":"email","providers":["email"]}') || '::jsonb'
    );
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_user_meta_data'
  ) then
    cols := array_append(cols, 'raw_user_meta_data');
    vals := array_append(vals, quote_literal('{}') || '::jsonb');
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'email_confirmed_at'
  ) then
    raise exception 'auth.users.email_confirmed_at is missing.'
      using errcode = '55000';
  end if;

  foreach colname in array array['email_confirmed_at', 'created_at', 'updated_at']
  loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'auth' and table_name = 'users'
        and column_name = colname and is_generated = 'NEVER'
    ) then
      cols := array_append(cols, colname);
      vals := array_append(vals, 'now()');
    end if;
  end loop;

  foreach colname in array token_cols
  loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'auth' and table_name = 'users'
        and column_name = colname and is_generated = 'NEVER'
    ) then
      cols := array_append(cols, colname);
      vals := array_append(vals, quote_literal(''));
    end if;
  end loop;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users'
      and column_name = 'email_change_confirm_status' and is_generated = 'NEVER'
  ) then
    cols := array_append(cols, 'email_change_confirm_status');
    vals := array_append(vals, '0');
  end if;
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

  id_cols := array['user_id', 'identity_data', 'provider', 'provider_id'];
  id_vals := array[
    quote_literal(v_uid) || '::uuid',
    quote_literal(jsonb_build_object(
      'sub', v_uid::text,
      'email', v_email,
      'email_verified', true
    )::text) || '::jsonb',
    quote_literal('email'),
    quote_literal(v_uid::text)
  ];

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'identities'
      and column_name = 'id'
      and is_nullable = 'NO'
      and is_generated = 'NEVER'
      and column_default is null
  ) then
    id_cols := array_prepend('id', id_cols);
    id_vals := array_prepend('gen_random_uuid()', id_vals);
  end if;

  foreach colname in array array['created_at', 'updated_at', 'last_sign_in_at']
  loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'auth' and table_name = 'identities'
        and column_name = colname and is_generated = 'NEVER'
    ) then
      id_cols := array_append(id_cols, colname);
      id_vals := array_append(id_vals, 'now()');
    end if;
  end loop;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'identities'
      and column_name = 'email'
      and is_generated = 'NEVER'
      and is_nullable = 'NO'
  ) then
    id_cols := array_append(id_cols, 'email');
    id_vals := array_append(id_vals, quote_literal(v_email));
  end if;

  execute format(
    'insert into auth.identities (%s) values (%s)',
    array_to_string(id_cols, ', '),
    array_to_string(id_vals, ', ')
  );

  if to_regclass('public.users') is not null then
    update public.users
    set primary_role = 'unset'
    where id = v_uid;
  end if;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'primary_role'
  ) then
    update public.profiles
    set primary_role = null
    where user_id = v_uid;
  end if;

  return v_uid;
end;
$$;

comment on function public.staging_create_test_user(text) is
  'Creates one empty qa+ or test<N> mailbox on staging when test_accounts_enabled is true. N is 1 to 9999. Callable by anon. Does not choose a role. Refuses test@homizi.in and every other email. At most 50 new mailboxes per UTC day. Reads the password from private.staging_secrets and does not replace an existing user.';

revoke all on function public.staging_create_test_user(text) from public, authenticated;
grant execute on function public.staging_create_test_user(text) to anon;

create or replace function public.staging_purge_test_users(older_than interval)
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_id uuid;
  v_email text;
  v_count integer := 0;
  v_deleted integer;
begin
  if older_than is null or older_than <= interval '0' then
    raise exception 'Choose an age greater than zero.'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.staging_flags
    where key = 'test_accounts_enabled'
      and enabled is true
  ) then
    raise exception 'Staging test accounts are off.'
      using errcode = '42501';
  end if;

  for v_id in
    select id
    from auth.users
    where (
      email ~ '^qa\+[a-z0-9-]{1,32}@homizi\.in$'
      or email ~ '^test[1-9][0-9]{0,3}@homizi\.in$'
    )
      and created_at < now() - older_than
  loop
    select email
    into v_email
    from auth.users
    where id = v_id
    for update;

    if v_email is null
       or (
         v_email !~ '^qa\+[a-z0-9-]{1,32}@homizi\.in$'
         and v_email !~ '^test[1-9][0-9]{0,3}@homizi\.in$'
       ) then
      continue;
    end if;

    if to_regclass('storage.objects') is not null then
      begin
        delete from storage.objects
        where bucket_id in ('listing-photos', 'avatars')
          and split_part(name, '/', 1) = v_id::text;
      exception
        when others then
          null;
      end;
    end if;

    if to_regclass('public.agreements') is not null then
      delete from public.agreements
      where created_by = v_id
         or match_id in (
           select id from public.matches
           where participant_a = v_id or participant_b = v_id
         );
    end if;

    if to_regclass('public.payments') is not null then
      delete from public.payments
      where payee_user_id = v_id
         or (
           match_id is not null
           and match_id in (
             select id from public.matches
             where participant_a = v_id or participant_b = v_id
           )
         );
    end if;

    delete from public.reports
    where reporter_id = v_id
       or target_id = v_id
       or target_id in (
         select id from public.properties where host_user_id = v_id
       )
       or target_id in (
         select id from public.listing_requirements where user_id = v_id
       )
       or target_id in (
         select m.id
         from public.messages m
         join public.conversations c on c.id = m.conversation_id
         join public.matches mt on mt.id = c.match_id
         where mt.participant_a = v_id or mt.participant_b = v_id
       );

    delete from public.notifications
    where user_id <> v_id
      and payload_minimal ->> 'match_id' in (
        select id::text
        from public.matches
        where participant_a = v_id or participant_b = v_id
      );

    delete from public.interests
    where (
      target_type = 'user' and target_id = v_id
    ) or (
      target_type = 'property'
      and target_id in (select id from public.properties where host_user_id = v_id)
    ) or (
      target_type = 'listing_requirement'
      and target_id in (
        select id from public.listing_requirements where user_id = v_id
      )
    );

    delete from public.matches
    where participant_a = v_id or participant_b = v_id;

    delete from public.properties
    where host_user_id = v_id;

    if to_regclass('auth.identities') is not null then
      delete from auth.identities where user_id = v_id;
    end if;

    delete from auth.users
    where id = v_id
      and email = v_email;
    get diagnostics v_deleted = row_count;
    v_count := v_count + v_deleted;
  end loop;

  return v_count;
end;
$$;

comment on function public.staging_purge_test_users(interval) is
  'Deletes qa+ and test<N> mailboxes older than the interval. N is 1 to 9999. Does not delete test@homizi.in. Refuses to run when test_accounts_enabled is absent or false. Not granted to anon or authenticated.';

revoke all on function public.staging_purge_test_users(interval) from public, anon, authenticated;
