-- HOMIZI staging fresh testers for project loraalfiuklespaldotd.
-- Paste this whole file into the dashboard SQL editor. Running it again is safe.
--
-- It matches supabase/migrations/20261019101900_staging_test_accounts.sql
-- and inserts staging_flags key test_accounts_enabled.
-- Do not paste this into production. The migration leaves that row absent,
-- and production builds never call staging_create_test_user.
-- No service role key, secret key, or database password is in this file.
-- The function reads private.staging_secrets.test_password. This file does not set it.

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

insert into public.staging_flags (key, enabled)
values ('test_accounts_enabled', true)
on conflict (key) do update
set enabled = excluded.enabled,
    updated_at = now();

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261019101900',
  'staging_test_accounts',
  array['docs/staging_apply_M_1019.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

-- Requirement answers are multi-select text arrays.
-- Multi-select requirement answers.
-- Safe to run again. A text or enum value becomes a one-item text array.
-- An empty array, or a no-preference value, matches every listing.
-- Gender preference and occupancy preference stay a single value.

do $drop_multi_checks$
declare
  spec record;
begin
  for spec in
    select *
    from (values
      ('listing_requirements', 'listing_requirements_room_type'),
      ('listing_requirements', 'listing_requirements_parking_need'),
      ('listing_requirements', 'listing_requirements_preferred_floor'),
      ('listing_requirements', 'listing_requirements_pets'),
      ('listing_requirements', 'listing_requirements_food_habit'),
      ('listing_requirements', 'listing_requirements_smoking'),
      ('listing_requirements', 'listing_requirements_drinking'),
      ('listing_requirements', 'listing_requirements_profession'),
      ('listing_requirements', 'listing_requirements_guests_policy'),
      ('listing_requirements', 'listing_requirements_sleep_schedule'),
      ('listing_requirements', 'listing_requirements_social_style'),
      ('listing_requirements', 'listing_requirements_cooking'),
      ('tenant_preferences', 'tenant_preferences_room_type'),
      ('tenant_preferences', 'tenant_preferences_parking_need'),
      ('tenant_preferences', 'tenant_preferences_preferred_floor'),
      ('tenant_preferences', 'tenant_preferences_pets'),
      ('tenant_preferences', 'tenant_preferences_food_habit'),
      ('tenant_preferences', 'tenant_preferences_smoking'),
      ('tenant_preferences', 'tenant_preferences_drinking'),
      ('tenant_preferences', 'tenant_preferences_profession'),
      ('tenant_preferences', 'tenant_preferences_guests_policy'),
      ('tenant_preferences', 'tenant_preferences_sleep_schedule'),
      ('tenant_preferences', 'tenant_preferences_social_style'),
      ('tenant_preferences', 'tenant_preferences_cooking'),
      ('roommate_profiles', 'roommate_profiles_food'),
      ('roommate_profiles', 'roommate_profiles_smoking'),
      ('roommate_profiles', 'roommate_profiles_pets'),
      ('roommate_profiles', 'roommate_profiles_sleep'),
      ('roommate_profiles', 'roommate_profiles_social'),
      ('roommate_profiles', 'roommate_profiles_cooking'),
      ('roommate_profiles', 'roommate_profiles_guests')
    ) as t(rel, con)
  loop
    if to_regclass('public.' || spec.rel) is not null then
      execute format(
        'alter table public.%I drop constraint if exists %I',
        spec.rel,
        spec.con
      );
    end if;
  end loop;
end
$drop_multi_checks$;

do $convert_multi$
declare
  spec record;
  kind text;
begin
  for spec in
    select *
    from (values
      ('listing_requirements', 'room_type'),
      ('listing_requirements', 'furnishing'),
      ('listing_requirements', 'parking_need'),
      ('listing_requirements', 'preferred_floor'),
      ('listing_requirements', 'pets'),
      ('listing_requirements', 'food_habit'),
      ('listing_requirements', 'smoking'),
      ('listing_requirements', 'drinking'),
      ('listing_requirements', 'profession'),
      ('listing_requirements', 'guests_policy'),
      ('listing_requirements', 'sleep_schedule'),
      ('listing_requirements', 'social_style'),
      ('listing_requirements', 'cooking'),
      ('tenant_preferences', 'room_type'),
      ('tenant_preferences', 'furnishing'),
      ('tenant_preferences', 'parking_need'),
      ('tenant_preferences', 'preferred_floor'),
      ('tenant_preferences', 'pets'),
      ('tenant_preferences', 'food_habit'),
      ('tenant_preferences', 'smoking'),
      ('tenant_preferences', 'drinking'),
      ('tenant_preferences', 'profession'),
      ('tenant_preferences', 'guests_policy'),
      ('tenant_preferences', 'sleep_schedule'),
      ('tenant_preferences', 'social_style'),
      ('tenant_preferences', 'cooking'),
      ('roommate_profiles', 'food'),
      ('roommate_profiles', 'smoking'),
      ('roommate_profiles', 'pets'),
      ('roommate_profiles', 'sleep'),
      ('roommate_profiles', 'social'),
      ('roommate_profiles', 'cooking'),
      ('roommate_profiles', 'guests')
    ) as t(rel, col)
  loop
    if to_regclass('public.' || spec.rel) is null then
      continue;
    end if;
    select data_type into kind
    from information_schema.columns
    where table_schema = 'public'
      and table_name = spec.rel
      and column_name = spec.col;
    if kind is null or kind = 'ARRAY' then
      continue;
    end if;
    execute format(
      $sql$alter table public.%I alter column %I type text[] using case
        when %I is null or btrim(%I::text) = '' then '{}'::text[]
        else array[btrim(%I::text)]
      end$sql$,
      spec.rel,
      spec.col,
      spec.col,
      spec.col,
      spec.col
    );
  end loop;
end
$convert_multi$;

do $add_multi_checks$
declare
  spec record;
begin
  for spec in
    select *
    from (values
      ('listing_requirements', 'listing_requirements_room_type',
        'room_type is null or room_type <@ array[''private_room'', ''shared'', ''1rk'', ''1bhk'', ''2bhk'', ''3bhk'', ''4bhk'']::text[]'),
      ('listing_requirements', 'listing_requirements_furnishing',
        'furnishing is null or furnishing <@ array[''unfurnished'', ''semi_furnished'', ''furnished'', ''any'', ''no_preference'']::text[]'),
      ('listing_requirements', 'listing_requirements_parking_need',
        'parking_need is null or parking_need <@ array[''none'', ''two_wheeler'', ''four_wheeler'', ''either'']::text[]'),
      ('listing_requirements', 'listing_requirements_preferred_floor',
        'preferred_floor is null or preferred_floor <@ array[''any'', ''ground'', ''low'', ''mid'', ''high'']::text[]'),
      ('listing_requirements', 'listing_requirements_pets',
        'pets is null or pets <@ array[''no_pets'', ''have_pets'', ''pets_ok'']::text[]'),
      ('listing_requirements', 'listing_requirements_food_habit',
        'food_habit is null or food_habit <@ array[''veg'', ''non_veg'', ''eggetarian'']::text[]'),
      ('listing_requirements', 'listing_requirements_smoking',
        'smoking is null or smoking <@ array[''no'', ''occasionally'', ''yes'']::text[]'),
      ('listing_requirements', 'listing_requirements_drinking',
        'drinking is null or drinking <@ array[''no'', ''occasionally'', ''yes'']::text[]'),
      ('listing_requirements', 'listing_requirements_profession',
        'profession is null or profession <@ array[''student'', ''working'']::text[]'),
      ('listing_requirements', 'listing_requirements_guests_policy',
        'guests_policy is null or guests_policy <@ array[''no_guests'', ''occasional'', ''often'']::text[]'),
      ('listing_requirements', 'listing_requirements_sleep_schedule',
        'sleep_schedule is null or sleep_schedule <@ array[''early'', ''flexible'', ''night'']::text[]'),
      ('listing_requirements', 'listing_requirements_social_style',
        'social_style is null or social_style <@ array[''quiet'', ''balanced'', ''social'']::text[]'),
      ('listing_requirements', 'listing_requirements_cooking',
        'cooking is null or cooking <@ array[''rarely'', ''sometimes'', ''often'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_room_type',
        'room_type is null or room_type <@ array[''private_room'', ''shared'', ''1rk'', ''1bhk'', ''2bhk'', ''3bhk'', ''4bhk'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_furnishing',
        'furnishing is null or furnishing <@ array[''unfurnished'', ''semi_furnished'', ''furnished'', ''any'', ''no_preference'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_parking_need',
        'parking_need is null or parking_need <@ array[''none'', ''two_wheeler'', ''four_wheeler'', ''either'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_preferred_floor',
        'preferred_floor is null or preferred_floor <@ array[''any'', ''ground'', ''low'', ''mid'', ''high'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_pets',
        'pets is null or pets <@ array[''no_pets'', ''have_pets'', ''pets_ok'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_food_habit',
        'food_habit is null or food_habit <@ array[''veg'', ''non_veg'', ''eggetarian'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_smoking',
        'smoking is null or smoking <@ array[''no'', ''occasionally'', ''yes'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_drinking',
        'drinking is null or drinking <@ array[''no'', ''occasionally'', ''yes'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_profession',
        'profession is null or profession <@ array[''student'', ''working'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_guests_policy',
        'guests_policy is null or guests_policy <@ array[''no_guests'', ''occasional'', ''often'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_sleep_schedule',
        'sleep_schedule is null or sleep_schedule <@ array[''early'', ''flexible'', ''night'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_social_style',
        'social_style is null or social_style <@ array[''quiet'', ''balanced'', ''social'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_cooking',
        'cooking is null or cooking <@ array[''rarely'', ''sometimes'', ''often'']::text[]'),
      ('roommate_profiles', 'roommate_profiles_food',
        'food is null or food <@ array[''veg'', ''eggetarian'', ''non_veg'', ''any'']::text[]'),
      ('roommate_profiles', 'roommate_profiles_smoking',
        'smoking is null or smoking <@ array[''never'', ''sometimes'', ''regularly'']::text[]'),
      ('roommate_profiles', 'roommate_profiles_pets',
        'pets is null or pets <@ array[''none'', ''has'', ''ok'']::text[]'),
      ('roommate_profiles', 'roommate_profiles_sleep',
        'sleep is null or sleep <@ array[''early'', ''flexible'', ''night'', ''any'']::text[]'),
      ('roommate_profiles', 'roommate_profiles_social',
        'social is null or social <@ array[''quiet'', ''balanced'', ''social'', ''any'']::text[]'),
      ('roommate_profiles', 'roommate_profiles_cooking',
        'cooking is null or cooking <@ array[''rarely'', ''sometimes'', ''often'', ''any'']::text[]'),
      ('roommate_profiles', 'roommate_profiles_guests',
        'guests is null or guests <@ array[''rare'', ''sometimes'', ''often'', ''any'']::text[]')
    ) as t(rel, con, expr)
  loop
    if to_regclass('public.' || spec.rel) is null then
      continue;
    end if;
    execute format(
      'alter table public.%I drop constraint if exists %I',
      spec.rel,
      spec.con
    );
    execute format(
      'alter table public.%I add constraint %I check (%s)',
      spec.rel,
      spec.con,
      spec.expr
    );
  end loop;
end
$add_multi_checks$;

create or replace function public.requirement_listing_match(
  listing_id uuid,
  requirement_id uuid
) returns integer
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  l record;
  r record;
  score integer := 0;
  pt text;
  room text;
  rooms text[];
  furns text[];
  type_ok boolean := false;
  wanted text[];
  hits integer;
  total integer;
begin
  select
    city,
    locality,
    rent_inr,
    property_type::text as property_type,
    furnishing::text as furnishing,
    available_from
  into l
  from public.properties
  where id = listing_id;
  if not found then
    return 0;
  end if;

  select
    city,
    localities,
    budget_min_inr,
    budget_max_inr,
    room_type,
    property_types,
    furnishing,
    amenities,
    move_in_date
  into r
  from public.listing_requirements
  where id = requirement_id;
  if not found then
    return 0;
  end if;

  if lower(btrim(l.city)) = lower(btrim(r.city)) then
    score := score + 25;
  end if;
  if exists (
    select 1
    from unnest(coalesce(r.localities, '{}'::text[])) as loc
    where lower(btrim(loc)) = lower(btrim(l.locality))
  ) then
    score := score + 20;
  end if;
  if l.rent_inr >= r.budget_min_inr and l.rent_inr <= r.budget_max_inr then
    score := score + 20;
  elsif l.rent_inr >= round(r.budget_min_inr::numeric * 0.8)
    and l.rent_inr <= round(r.budget_max_inr::numeric * 1.2) then
    score := score + 10;
  end if;

  pt := l.property_type;
  rooms := coalesce(r.room_type, '{}'::text[]);
  if coalesce(cardinality(rooms), 0) = 0
     or exists (
       select 1
       from unnest(rooms) as item
       where lower(btrim(item)) in ('any', 'no_preference')
     )
  then
    type_ok := true;
  else
    foreach room in array rooms loop
      if room = 'private_room' then
        type_ok := pt in ('private_room', 'apartment', 'independent_house', 'villa');
      elsif room = 'shared' then
        type_ok := pt in ('shared_room', 'pg');
      elsif room = '1rk' then
        type_ok := pt in ('studio', 'apartment');
      elsif room = '1bhk' then
        type_ok := pt in ('apartment', 'independent_house', 'villa', 'studio');
      elsif room in ('2bhk', '3bhk', '4bhk') then
        type_ok := pt in ('apartment', 'independent_house', 'villa');
      else
        type_ok := pt = any (select item::text from unnest(r.property_types) as item);
      end if;
      exit when type_ok;
    end loop;
  end if;
  if type_ok then
    score := score + 15;
  end if;

  furns := coalesce(r.furnishing, '{}'::text[]);
  if coalesce(cardinality(furns), 0) = 0
     or exists (
       select 1
       from unnest(furns) as item
       where lower(btrim(item)) in ('any', 'no_preference')
          or lower(btrim(item)) = lower(btrim(coalesce(l.furnishing, '')))
     )
  then
    score := score + 10;
  end if;

  wanted := coalesce(r.amenities, '{}'::text[]);
  total := cardinality(wanted);
  if total = 0 then
    score := score + 5;
  else
    select count(*)::integer into hits
    from unnest(wanted) as item
    where exists (
      select 1
      from public.property_features as feature
      where feature.property_id = listing_id
        and feature.feature_key = 'amenity:' || item
    );
    score := score + round((hits::numeric / total) * 5)::integer;
  end if;

  if r.move_in_date is null
    or l.available_from is null
    or l.available_from <= r.move_in_date + 30 then
    score := score + 5;
  end if;

  if score < 0 then
    return 0;
  end if;
  if score > 100 then
    return 100;
  end if;
  return score;
end;
$$;

comment on function public.requirement_listing_match(uuid, uuid) is
  '0-100 fit of one listing against one requirement. Any selected room type or furnishing can match. An empty list matches all. Does not read gender, religion, caste, age, phone, or email.';

create or replace function public.seekers_for_my_listings()
returns table (
  requirement_id uuid,
  listing_id uuid,
  display_name text,
  city text,
  localities text[],
  budget_min_inr integer,
  budget_max_inr integer,
  room_type text,
  seeker_kind text,
  about_me text,
  profession text,
  match_percent integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select distinct on (r.id)
    r.id,
    p.id,
    pr.display_name,
    r.city,
    r.localities,
    r.budget_min_inr,
    r.budget_max_inr,
    array_to_string(coalesce(r.room_type, '{}'::text[]), ', '),
    r.seeker_kind,
    r.about_me,
    array_to_string(coalesce(r.profession, '{}'::text[]), ', '),
    scored.match_percent
  from public.properties as p
  join public.listing_requirements as r
    on r.status = 'published'
   and r.discoverable
   and r.user_id <> auth.uid()
  left join public.profiles as pr
    on pr.user_id = r.user_id
  cross join lateral (
    select public.requirement_listing_match(p.id, r.id) as match_percent
  ) as scored
  where p.host_user_id = auth.uid()
    and p.status in ('published', 'draft')
  order by r.id, scored.match_percent desc, p.id;
$$;

comment on function public.seekers_for_my_listings() is
  'Best match of each opted-in published brief against the caller''s listings. No phone or email.';

create or replace function public._roommate_norm_values(p_values text[])
returns text[]
language sql
immutable
set search_path = public
as $$
  select coalesce(array_agg(item), '{}'::text[])
  from (
    select distinct lower(btrim(raw)) as item
    from unnest(coalesce(p_values, '{}'::text[])) as raw
    where btrim(coalesce(raw, '')) <> ''
  ) as cleaned;
$$;

create or replace function public._roommate_open_values(p_values text[])
returns boolean
language sql
immutable
set search_path = public
as $$
  select coalesce(cardinality(public._roommate_norm_values(p_values)), 0) = 0
    or exists (
      select 1
      from unnest(public._roommate_norm_values(p_values)) as item
      where item in ('any', 'no_preference')
    );
$$;

create or replace function public._roommate_food_pair_conflict(p_a text, p_b text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select not (
    p_a = '' or p_b = '' or p_a = 'any' or p_b = 'any' or p_a = p_b
    or not (
      p_a = 'veg' or p_b = 'veg'
      or (p_a = 'eggetarian' and p_b = 'non_veg')
      or (p_b = 'eggetarian' and p_a = 'non_veg')
    )
  );
$$;

create or replace function public._roommate_smoke_pair_conflict(p_a text, p_b text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_a <> '' and p_b <> '' and p_a <> p_b and (p_a = 'never' or p_b = 'never');
$$;

create or replace function public._roommate_pet_pair_conflict(p_a text, p_b text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select (p_a = 'has' and p_b = 'none') or (p_a = 'none' and p_b = 'has');
$$;

create or replace function public._roommate_any_conflict(
  p_a text[],
  p_b text[],
  p_kind text
) returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  left_item text;
  right_item text;
  pair_conflict boolean;
begin
  if public._roommate_open_values(p_a) or public._roommate_open_values(p_b) then
    return false;
  end if;
  for left_item in
    select item from unnest(public._roommate_norm_values(p_a)) as item
  loop
    for right_item in
      select item from unnest(public._roommate_norm_values(p_b)) as item
    loop
      pair_conflict := case p_kind
        when 'food' then public._roommate_food_pair_conflict(left_item, right_item)
        when 'smoking' then public._roommate_smoke_pair_conflict(left_item, right_item)
        else public._roommate_pet_pair_conflict(left_item, right_item)
      end;
      if not pair_conflict then
        return false;
      end if;
    end loop;
  end loop;
  return true;
end;
$$;

create or replace function public._roommate_scale_any(
  p_a text[],
  p_b text[],
  p_order text[],
  p_full integer,
  p_near integer,
  p_far integer,
  p_unknown integer
) returns integer
language plpgsql
immutable
set search_path = public
as $$
declare
  left_item text;
  right_item text;
  left_index integer;
  right_index integer;
  best integer := null;
  distance integer;
begin
  if public._roommate_open_values(p_a) or public._roommate_open_values(p_b) then
    return p_full;
  end if;
  for left_item in
    select item from unnest(public._roommate_norm_values(p_a)) as item
  loop
    for right_item in
      select item from unnest(public._roommate_norm_values(p_b)) as item
    loop
      left_index := array_position(p_order, left_item);
      right_index := array_position(p_order, right_item);
      if left_index is null or right_index is null then
        continue;
      end if;
      distance := abs(left_index - right_index);
      if distance = 0 then
        return p_full;
      end if;
      if best is null or distance < best then
        best := distance;
      end if;
    end loop;
  end loop;
  if best is null then
    return p_unknown;
  end if;
  if best = 1 then
    return p_near;
  end if;
  return p_far;
end;
$$;

revoke all on function public._roommate_norm_values(text[]) from public, anon, authenticated;
revoke all on function public._roommate_open_values(text[]) from public, anon, authenticated;
revoke all on function public._roommate_food_pair_conflict(text, text) from public, anon, authenticated;
revoke all on function public._roommate_smoke_pair_conflict(text, text) from public, anon, authenticated;
revoke all on function public._roommate_pet_pair_conflict(text, text) from public, anon, authenticated;
revoke all on function public._roommate_any_conflict(text[], text[], text) from public, anon, authenticated;
revoke all on function public._roommate_scale_any(text[], text[], text[], integer, integer, integer, integer) from public, anon, authenticated;

create or replace function public._roommate_compatibility_detail(p_a uuid, p_b uuid)
returns jsonb
language plpgsql stable
security definer
set search_path = public
as $$
declare
  l public.roommate_profiles;
  r public.roommate_profiles;
  v_city integer;
  v_locality integer;
  v_budget integer;
  v_move integer;
  v_gender integer;
  v_occupancy integer;
  v_food integer;
  v_smoking integer;
  v_pets integer;
  v_sleep integer;
  v_clean integer;
  v_social integer;
  v_wfh integer;
  v_cooking integer;
  v_guests integer;
  v_languages integer;
  v_hobbies integer;
  v_thoughts integer;
  v_food_conflict boolean;
  v_smoke_conflict boolean;
  v_pet_conflict boolean;
  v_rows jsonb := '[]'::jsonb;
  v_highlights jsonb := '[]'::jsonb;
  v_score integer;
  v_label text;
  v_days integer;
begin
  select * into l from public.roommate_profiles where user_id = p_a;
  select * into r from public.roommate_profiles where user_id = p_b;
  if l.user_id is null or r.user_id is null then
    return jsonb_build_object('score', 0, 'rows', '[]'::jsonb, 'highlights', '[]'::jsonb);
  end if;

  if lower(btrim(coalesce(l.city, ''))) <> ''
     and lower(btrim(l.city)) = lower(btrim(coalesce(r.city, ''))) then
    v_city := 12;
  else
    v_city := 0;
  end if;
  v_locality := public._roommate_locality_points(l.city, r.city, l.localities, r.localities);
  v_budget := public._roommate_budget_points(
    l.budget_min_inr, l.budget_max_inr, r.budget_min_inr, r.budget_max_inr
  );
  if l.move_in_date is null or r.move_in_date is null then
    v_move := 8;
  else
    v_days := abs(l.move_in_date - r.move_in_date);
    v_move := case when v_days <= 30 then 8 when v_days <= 60 then 4 else 0 end;
  end if;
  if public._roommate_accepts(l.gender_preference, l.gender, r.gender)
     and public._roommate_accepts(r.gender_preference, r.gender, l.gender) then
    v_gender := 8;
  else
    v_gender := 0;
  end if;
  if lower(btrim(coalesce(l.occupancy, ''))) = ''
     or lower(btrim(coalesce(r.occupancy, ''))) = ''
     or lower(btrim(l.occupancy)) = 'any'
     or lower(btrim(r.occupancy)) = 'any'
     or lower(btrim(l.occupancy)) = lower(btrim(r.occupancy)) then
    v_occupancy := 4;
  else
    v_occupancy := 0;
  end if;

  v_food_conflict := public._roommate_any_conflict(l.food, r.food, 'food');
  v_food := case
    when v_food_conflict and (l.food_dealbreaker or r.food_dealbreaker) then 0
    else 2
  end;

  v_smoke_conflict := public._roommate_any_conflict(l.smoking, r.smoking, 'smoking');
  v_smoking := case
    when v_smoke_conflict and (l.smoking_dealbreaker or r.smoking_dealbreaker) then 0
    else 2
  end;

  v_pet_conflict := public._roommate_any_conflict(l.pets, r.pets, 'pets');
  v_pets := case
    when v_pet_conflict and (l.pets_dealbreaker or r.pets_dealbreaker) then 0
    else 2
  end;

  v_sleep := public._roommate_scale_any(l.sleep, r.sleep, array['early', 'flexible', 'night'], 5, 3, 0, 3);
  if l.cleanliness is null or r.cleanliness is null
     or l.cleanliness < 1 or l.cleanliness > 5
     or r.cleanliness < 1 or r.cleanliness > 5 then
    v_clean := 3;
  else
    v_clean := case abs(l.cleanliness - r.cleanliness)
      when 0 then 5
      when 1 then 3
      when 2 then 1
      else 0
    end;
  end if;
  v_social := public._roommate_scale_any(l.social, r.social, array['quiet', 'balanced', 'social'], 5, 3, 0, 3);
  if lower(btrim(coalesce(l.wfh, ''))) = '' or lower(btrim(coalesce(r.wfh, ''))) = '' then
    v_wfh := 2;
  elsif lower(btrim(l.wfh)) = lower(btrim(r.wfh)) then
    v_wfh := 4;
  elsif lower(btrim(l.wfh)) = 'hybrid' or lower(btrim(r.wfh)) = 'hybrid' then
    v_wfh := 2;
  else
    v_wfh := 0;
  end if;
  v_cooking := public._roommate_scale_any(l.cooking, r.cooking, array['rarely', 'sometimes', 'often'], 4, 2, 0, 2);
  v_guests := public._roommate_scale_any(l.guests, r.guests, array['rare', 'sometimes', 'often'], 4, 2, 0, 2);
  v_languages := public._roommate_list_points(l.languages, r.languages);
  v_hobbies := public._roommate_list_points(l.hobbies, r.hobbies);
  v_thoughts := public._roommate_thought_points(l.thoughts, r.thoughts);

  v_rows := jsonb_build_array(
    public._roommate_row('city', 'City', v_city, 12, case when v_city = 12 then 'Same city.' else 'Different cities.' end),
    public._roommate_row('locality', 'Locality', v_locality, 10, case v_locality when 10 then 'Shared locality.' when 6 then 'Locality not set.' when 4 then 'Same city, different localities.' else 'No shared locality.' end),
    public._roommate_row('budget', 'Budget', v_budget, 12, case
      when l.budget_min_inr is null and l.budget_max_inr is null then 'Budgets are not set.'
      when r.budget_min_inr is null and r.budget_max_inr is null then 'Budgets are not set.'
      when v_budget = 12 then 'Budgets overlap.'
      when v_budget = 6 then 'Budgets are close.'
      else 'Budgets do not overlap.'
    end),
    public._roommate_row('move_in', 'Move-in', v_move, 8, case
      when l.move_in_date is null or r.move_in_date is null then 'Move-in is flexible.'
      when v_move = 8 then 'Move-in dates are within a month.'
      when v_move = 4 then 'Move-in dates are within two months.'
      else 'Move-in dates are far apart.'
    end),
    public._roommate_row('gender', 'Gender preference', v_gender, 8, case when v_gender = 8 then 'Gender preferences fit.' else 'A gender preference does not fit.' end),
    public._roommate_row('occupancy', 'Occupancy', v_occupancy, 4, case when v_occupancy = 4 then 'Occupancy preferences fit.' else 'Occupancy preferences differ.' end),
    public._roommate_row('food', 'Food', v_food, 2, case when v_food = 2 then 'Food habits fit.' else 'A food dealbreaker conflicts.' end),
    public._roommate_row('smoking', 'Smoking', v_smoking, 2, case when v_smoking = 2 then 'Smoking habits fit.' else 'A smoking dealbreaker conflicts.' end),
    public._roommate_row('pets', 'Pets', v_pets, 2, case when v_pets = 2 then 'Pet habits fit.' else 'A pet dealbreaker conflicts.' end),
    public._roommate_row('sleep', 'Sleep', v_sleep, 5, case when v_sleep = 5 then 'Sleep schedules match.' when v_sleep = 0 then 'Sleep schedules differ.' else 'Sleep schedules are close or not set.' end),
    public._roommate_row('cleanliness', 'Cleanliness', v_clean, 5, case when v_clean = 5 then 'Cleanliness matches.' when v_clean = 0 then 'Cleanliness is far apart.' else 'Cleanliness is close or not set.' end),
    public._roommate_row('social', 'Social', v_social, 5, case when v_social = 5 then 'Social levels match.' when v_social = 0 then 'Social levels differ.' else 'Social levels are close or not set.' end),
    public._roommate_row('wfh', 'Work from home', v_wfh, 4, case when v_wfh = 4 then 'Work styles match.' when v_wfh = 0 then 'Work styles differ.' else 'Work styles are close or not set.' end),
    public._roommate_row('cooking', 'Cooking', v_cooking, 4, case when v_cooking = 4 then 'Cooking habits match.' when v_cooking = 0 then 'Cooking habits differ.' else 'Cooking habits are close or not set.' end),
    public._roommate_row('guests', 'Guests', v_guests, 4, case when v_guests = 4 then 'Guest habits match.' when v_guests = 0 then 'Guest habits differ.' else 'Guest habits are close or not set.' end),
    public._roommate_row('languages', 'Languages', v_languages, 4, case
      when coalesce(array_length(l.languages, 1), 0) = 0 or coalesce(array_length(r.languages, 1), 0) = 0 then 'A language list is not set.'
      when v_languages = 4 then 'You share a language.'
      else 'No shared language.'
    end),
    public._roommate_row('hobbies', 'Hobbies', v_hobbies, 4, case
      when coalesce(array_length(l.hobbies, 1), 0) = 0 or coalesce(array_length(r.hobbies, 1), 0) = 0 then 'A hobby list is not set.'
      when v_hobbies = 4 then 'You share a hobby.'
      else 'No shared hobby.'
    end),
    public._roommate_row('thoughts', 'Flatmate notes', v_thoughts, 5, case
      when coalesce(array_length(public._roommate_thought_tokens(l.thoughts), 1), 0) = 0
        or coalesce(array_length(public._roommate_thought_tokens(r.thoughts), 1), 0) = 0
        then 'Flatmate notes are not set.'
      when v_thoughts = 5 then 'Flatmate notes overlap.'
      when v_thoughts = 3 then 'Flatmate notes share a little.'
      else 'Flatmate notes do not overlap.'
    end)
  );

  if v_city = 12 then
    v_highlights := v_highlights || jsonb_build_array(
      'You both look in ' || btrim(l.city) || '.'
    );
  end if;
  select btrim(left_item) into v_label
  from unnest(l.localities) as left_item
  where btrim(left_item) <> ''
    and exists (
      select 1 from unnest(r.localities) as right_item
      where lower(btrim(right_item)) = lower(btrim(left_item))
        and btrim(right_item) <> ''
    )
  limit 1;
  if v_label is not null then
    v_highlights := v_highlights || jsonb_build_array('You both named ' || v_label || '.');
  end if;
  if v_budget = 12 then
    v_highlights := v_highlights || jsonb_build_array('You both fit an overlapping budget.');
  end if;
  if l.move_in_date is not null and r.move_in_date is not null and v_move = 8 then
    v_highlights := v_highlights || jsonb_build_array(
      'You both want to move within a month of each other.'
    );
  end if;
  v_label := null;
  select item into v_label
  from unnest(public._roommate_norm_values(l.sleep)) as item
  where item in (select unnest(public._roommate_norm_values(r.sleep)))
  limit 1;
  if v_label is not null and v_label in ('early', 'flexible', 'night') then
    v_highlights := v_highlights || jsonb_build_array(
      case v_label
        when 'early' then 'You both keep early hours.'
        when 'night' then 'You both keep late hours.'
        else 'You both keep flexible hours.'
      end
    );
  end if;
  v_label := null;
  if l.cleanliness is not null and r.cleanliness is not null
     and l.cleanliness >= 4 and r.cleanliness >= 4
     and abs(l.cleanliness - r.cleanliness) <= 1 then
    v_highlights := v_highlights || jsonb_build_array('You both like a tidy home.');
  end if;
  v_label := null;
  select item into v_label
  from unnest(public._roommate_norm_values(l.social)) as item
  where item in (select unnest(public._roommate_norm_values(r.social)))
  limit 1;
  if v_label is not null and v_label in ('quiet', 'balanced', 'social') then
    v_highlights := v_highlights || jsonb_build_array(
      case v_label
        when 'quiet' then 'You both want a quiet home.'
        when 'social' then 'You both want a social home.'
        else 'You both want a balanced home.'
      end
    );
  end if;
  v_label := null;
  if lower(btrim(coalesce(l.wfh, ''))) <> ''
     and lower(btrim(l.wfh)) = lower(btrim(coalesce(r.wfh, ''))) then
    v_highlights := v_highlights || jsonb_build_array(
      case lower(btrim(l.wfh))
        when 'home' then 'You both work from home.'
        when 'office' then 'You both work from an office.'
        else 'You both work a hybrid week.'
      end
    );
  end if;
  for v_label in
    select btrim(left_item)
    from unnest(l.languages) as left_item
    where btrim(left_item) <> ''
      and lower(btrim(left_item)) in (
        select lower(btrim(right_item))
        from unnest(r.languages) as right_item
        where btrim(right_item) <> ''
      )
    limit 2
  loop
    v_highlights := v_highlights || jsonb_build_array('You both speak ' || v_label || '.');
  end loop;
  for v_label in
    select btrim(left_item)
    from unnest(l.hobbies) as left_item
    where btrim(left_item) <> ''
      and lower(btrim(left_item)) in (
        select lower(btrim(right_item))
        from unnest(r.hobbies) as right_item
        where btrim(right_item) <> ''
      )
    limit 2
  loop
    v_highlights := v_highlights || jsonb_build_array('You both enjoy ' || v_label || '.');
  end loop;

  v_score := v_city + v_locality + v_budget + v_move + v_gender + v_occupancy
    + v_food + v_smoking + v_pets + v_sleep + v_clean + v_social + v_wfh
    + v_cooking + v_guests + v_languages + v_hobbies + v_thoughts;
  if v_score < 0 then
    v_score := 0;
  elsif v_score > 100 then
    v_score := 100;
  end if;
  return jsonb_build_object('score', v_score, 'rows', v_rows, 'highlights', v_highlights);
end;
$$;


revoke all on function public._roommate_compatibility_detail(uuid, uuid) from public, anon, authenticated;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261019103000',
  'requirement_multi_select',
  array['docs/staging_apply_M_1019.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
