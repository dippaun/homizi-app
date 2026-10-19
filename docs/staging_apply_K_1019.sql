-- Listing match inputs and a detailed requirement for test@homizi.in.
-- The score itself stays in the client until requirement_listing_match lands.
-- Safe to run again.

alter table public.properties
  add column if not exists listing_verified boolean not null default false;

comment on column public.properties.listing_verified is
  'The listing was reviewed. This is not an Aadhaar or face check.';

alter table public.listing_requirements
  add column if not exists bedrooms smallint,
  add column if not exists food_rule text,
  add column if not exists pets_rule text,
  add column if not exists household_rule text,
  add column if not exists wanted_amenities text[] not null default '{}';

alter table public.listing_requirements
  drop constraint if exists listing_requirements_bedrooms;

alter table public.listing_requirements
  add constraint listing_requirements_bedrooms
  check (bedrooms is null or bedrooms between 0 and 10);

alter table public.listing_requirements
  drop constraint if exists listing_requirements_food_rule;

alter table public.listing_requirements
  add constraint listing_requirements_food_rule
  check (food_rule is null or food_rule in ('veg_only', 'non_veg_ok'));

alter table public.listing_requirements
  drop constraint if exists listing_requirements_pets_rule;

alter table public.listing_requirements
  add constraint listing_requirements_pets_rule
  check (pets_rule is null or pets_rule in ('required', 'avoid'));

alter table public.listing_requirements
  drop constraint if exists listing_requirements_household_rule;

alter table public.listing_requirements
  add constraint listing_requirements_household_rule
  check (
    household_rule is null
    or household_rule in ('family', 'bachelors', 'female', 'any')
  );

grant insert (
  bedrooms, food_rule, pets_rule, household_rule, wanted_amenities
) on public.listing_requirements to authenticated;

grant update (
  bedrooms, food_rule, pets_rule, household_rule, wanted_amenities
) on public.listing_requirements to authenticated;

do $homizi_match_seed$
declare
  v_host uuid := 'c0ffee00-0000-4000-8000-000000000001';
  v_tenant uuid;
  v_requirement uuid := 'a1019100-0000-4000-8000-0000000000aa';
begin
  if to_regclass('auth.users') is not null then
    select id into v_tenant
    from auth.users
    where lower(email) = 'test@homizi.in'
    limit 1;
  end if;

  if v_tenant is null then
    raise notice 'test@homizi.in is not in auth.users; requirement skipped';
  else
    insert into public.users (id, status)
    values (v_tenant, 'active')
    on conflict (id) do nothing;

    insert into public.profiles (user_id, display_name, occupation)
    values (v_tenant, 'Test tenant', 'Product designer')
    on conflict (user_id) do nothing;

    insert into public.listing_requirements (
      id, user_id, city, localities, budget_min_inr, budget_max_inr,
      move_in_date, occupancy, property_types, furnishing, lifestyle, status,
      bedrooms, food_rule, pets_rule, household_rule, wanted_amenities
    )
    values (
      v_requirement,
      v_tenant,
      'Bengaluru',
      array['Koramangala', 'Whitefield', 'HSR Layout'],
      18000,
      28000,
      date '2026-11-20',
      2,
      array['apartment']::public.property_type[],
      'furnished'::public.furnishing,
      array['pets_ok']::text[],
      'published'::public.listing_status,
      2,
      'non_veg_ok',
      'required',
      'family',
      array['Lift', 'Power backup']
    )
    on conflict (id) do update
    set user_id = excluded.user_id,
        city = excluded.city,
        localities = excluded.localities,
        budget_min_inr = excluded.budget_min_inr,
        budget_max_inr = excluded.budget_max_inr,
        move_in_date = excluded.move_in_date,
        occupancy = excluded.occupancy,
        property_types = excluded.property_types,
        furnishing = excluded.furnishing,
        lifestyle = excluded.lifestyle,
        status = excluded.status,
        bedrooms = excluded.bedrooms,
        food_rule = excluded.food_rule,
        pets_rule = excluded.pets_rule,
        household_rule = excluded.household_rule,
        wanted_amenities = excluded.wanted_amenities,
        updated_at = now();
  end if;

  if not exists (select 1 from public.users where id = v_host) then
    raise notice 'staging host missing; match listings skipped';
    return;
  end if;

  insert into public.properties (
    id, host_user_id, title, locality, city, property_type, furnishing,
    rent_inr, deposit_inr, maintenance_inr, occupancy_max, status,
    available_from, published_at, address_visibility,
    area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
    gated_society, floor_no, total_floors, approx_latitude, approx_longitude,
    listing_verified
  )
  values
    (
      'b1019101-0000-4000-8000-000000000101'::uuid, v_host,
      'Sunlit 2BHK in Koramangala', 'Koramangala', 'Bengaluru',
      'apartment'::public.property_type, 'furnished'::public.furnishing,
      22000, 80000, 1100, 3, 'published'::public.listing_status,
      date '2026-11-01', timestamptz '2026-10-16 09:00:00+00',
      'locality_only'::public.address_visibility,
      980, array['family']::text[], true, true, true, true, 3, 7,
      12.935, 77.624, true
    ),
    (
      'b1019102-0000-4000-8000-000000000102'::uuid, v_host,
      'Furnished 2BHK in Whitefield', 'Whitefield', 'Bengaluru',
      'apartment'::public.property_type, 'furnished'::public.furnishing,
      26000, 78000, 1200, 3, 'published'::public.listing_status,
      date '2026-11-05', timestamptz '2026-10-16 09:00:00+00',
      'locality_only'::public.address_visibility,
      1100, array['family']::text[], true, true, true, true, 4, 8,
      12.970, 77.750, true
    ),
    (
      'b1019103-0000-4000-8000-000000000103'::uuid, v_host,
      '2 BHK near HSR Layout BDA', 'HSR Layout', 'Bengaluru',
      'apartment'::public.property_type, 'semi_furnished'::public.furnishing,
      18500, 55000, 900, 2, 'published'::public.listing_status,
      date '2026-11-01', timestamptz '2026-10-16 09:00:00+00',
      'locality_only'::public.address_visibility,
      980, array['family']::text[], true, true, true, false, 2, 5,
      12.912, 77.645, true
    )
  on conflict (id) do update
  set host_user_id = excluded.host_user_id,
      title = excluded.title,
      locality = excluded.locality,
      city = excluded.city,
      property_type = excluded.property_type,
      furnishing = excluded.furnishing,
      rent_inr = excluded.rent_inr,
      deposit_inr = excluded.deposit_inr,
      status = 'published',
      available_from = excluded.available_from,
      published_at = excluded.published_at,
      preferred_tenants = excluded.preferred_tenants,
      pets_allowed = excluded.pets_allowed,
      non_veg_allowed = excluded.non_veg_allowed,
      listing_verified = excluded.listing_verified,
      approx_latitude = excluded.approx_latitude,
      approx_longitude = excluded.approx_longitude;

  insert into public.property_features (property_id, feature_key, value)
  values
    ('b1019101-0000-4000-8000-000000000101'::uuid, 'bedrooms', '2'),
    ('b1019101-0000-4000-8000-000000000101'::uuid, 'amenity:lift', 'yes'),
    ('b1019101-0000-4000-8000-000000000101'::uuid, 'amenity:power_backup', 'yes'),
    ('b1019102-0000-4000-8000-000000000102'::uuid, 'bedrooms', '2'),
    ('b1019102-0000-4000-8000-000000000102'::uuid, 'amenity:lift', 'yes'),
    ('b1019102-0000-4000-8000-000000000102'::uuid, 'amenity:power_backup', 'yes'),
    ('b1019103-0000-4000-8000-000000000103'::uuid, 'bedrooms', '2'),
    ('b1019103-0000-4000-8000-000000000103'::uuid, 'amenity:lift', 'yes'),
    ('b1019103-0000-4000-8000-000000000103'::uuid, 'amenity:power_backup', 'yes')
  on conflict (property_id, feature_key) do update
  set value = excluded.value;
end
$homizi_match_seed$;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261018130100',
  'listing_match_seed',
  array['docs/staging_apply_K_1019.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

-- Numbered staging testers. Paste this file after docs/staging_apply_M_1019.sql.
-- Body of 20261019102000_staging_numbered_test_mailboxes.sql.
-- test<N>@homizi.in for N = 1..9999 follows the qa+ path. test@homizi.in is unchanged.

-- Numbered staging testers: test<N>@homizi.in for N = 1..9999.
-- Same create and purge path as qa+ mailboxes. test@homizi.in stays the shared mailbox.
-- Safe to run again. Applies after 20261019101900, which creates these functions.

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
  v_password text := 'REDACTED_STAGING_PASSWORD';
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
  'Creates one empty qa+ or test<N> mailbox on staging when test_accounts_enabled is true. N is 1 to 9999. Callable by anon. Does not choose a role. Refuses test@homizi.in and every other email. At most 50 new mailboxes per UTC day.';

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

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261019102000',
  'staging_numbered_test_mailboxes',
  array['docs/staging_apply_K_1019.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
