-- Reset encrypted_password on an existing qa+ or test<N> mailbox from
-- private.staging_secrets.test_password. Does not insert or replace that row.
-- A build that still has the placeholder password does not call this.
-- Do not apply from an agent. Paste docs/staging_apply_QALOGIN_1112.sql
-- only after the owner approves that file.

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
    select value
    into v_password
    from private.staging_secrets
    where key = 'test_password';

    if v_password is null or btrim(v_password) = '' then
      raise exception 'The staging test password has not been set.'
        using errcode = '42501';
    end if;

    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'auth' and table_name = 'users'
        and column_name = 'encrypted_password'
    ) then
      raise exception 'auth.users.encrypted_password is missing.'
        using errcode = '55000';
    end if;

    execute $reset_password$
      update auth.users
      set encrypted_password = extensions.crypt($1, extensions.gen_salt('bf'))
      where id = $2
    $reset_password$
    using v_password, v_existing;

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
  'Creates one empty qa+ or test<N> mailbox on staging when test_accounts_enabled is true. N is 1 to 9999. Callable by anon. Does not choose a role. Refuses test@homizi.in and every other email. At most 50 new mailboxes per UTC day. Reads the password from private.staging_secrets. An existing qa+ or test<N> user keeps the same id and encrypted_password is set again from that secret. Does not insert or replace the secret row.';

revoke all on function public.staging_create_test_user(text) from public, authenticated;
grant execute on function public.staging_create_test_user(text) to anon;

