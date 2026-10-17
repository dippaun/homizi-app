-- HOMIZI slice F. Paste into the Supabase SQL editor after the schema
-- migrations through 20261017180400 are applied. Safe to run again.
-- It may run before or after the Ahmedabad locality file: those rows
-- are inserted with on conflict do nothing.
--
-- Adds published homes so every filter option matches at least one row,
-- attaches 3-6 Unsplash WebP photos to every seed listing, and sets
-- avatar URLs on the seed host and seed tenant.
-- Photo and avatar URLs are absolute Netlify paths. No phone numbers,
-- street addresses, or secrets are inserted.
do $homizi_seed_host$
declare
  v_host uuid := 'c0ffee00-0000-4000-8000-000000000001';
  v_email text := 'seed-host@example.test';
  cols text[] := array['id'];
  vals text[] := array[quote_literal(v_host) || '::uuid'];
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
  if exists (select 1 from auth.users where id <> v_host and email = v_email) then
    raise exception 'seed host email already belongs to a different account';
  end if;

  if not exists (select 1 from auth.users where id = v_host) then
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
      vals := array_append(
        vals,
        'extensions.crypt(gen_random_uuid()::text, extensions.gen_salt(''bf''))'
      );
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
      vals := array_append(vals, quote_literal('{"seed":"staging-catalog"}') || '::jsonb');
    end if;

    foreach colname in array array['email_confirmed_at', 'created_at', 'updated_at']
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
      where table_schema = 'auth' and table_name = 'users'
        and column_name = 'email_change_confirm_status'
        and is_generated = 'NEVER'
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
  end if;

  if to_regclass('auth.identities') is not null
     and not exists (select 1 from auth.identities where user_id = v_host) then
    begin
      execute format(
        'insert into auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at)
         values (gen_random_uuid(), %L::uuid, %L::jsonb, ''email'', %L, now(), now())',
        v_host,
        json_build_object('sub', v_host::text, 'email', v_email)::text,
        v_host::text
      );
    exception
      when others then
        raise notice 'auth.identities insert skipped: %', sqlerrm;
    end;
  end if;

  insert into public.users (id, status, primary_role)
  values (v_host, 'active', 'host')
  on conflict (id) do update
  set status = 'active', primary_role = 'host';

  insert into public.profiles (
    user_id, display_name, occupation, public_bio, verification_status
  ) values (
    v_host,
    'Asha V.',
    'Owner',
    'Staging catalog host. Public listings show locality and city only.',
    'mock_verified'
  )
  on conflict (user_id) do update
  set display_name = excluded.display_name,
      occupation = excluded.occupation,
      public_bio = excluded.public_bio,
      verification_status = excluded.verification_status;

  insert into public.host_profiles (user_id, host_category)
  values (v_host, 'owner')
  on conflict (user_id) do update
  set host_category = excluded.host_category;

  insert into public.private_contacts (user_id, email, phone)
  values (v_host, v_email, null)
  on conflict (user_id) do update
  set email = excluded.email,
      phone = null;
end
$homizi_seed_host$;

update public.profiles
set avatar_path = 'https://homizi.netlify.app/demo_media/avatar_01.webp'
where user_id = 'c0ffee00-0000-4000-8000-000000000001'::uuid;
do $homizi_seed_tenant$
declare
  v_host uuid := 'c0ffee00-0000-4000-8000-000000000002';
  v_email text := 'seed-tenant@example.test';
  cols text[] := array['id'];
  vals text[] := array[quote_literal(v_host) || '::uuid'];
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
  if exists (select 1 from auth.users where id <> v_host and email = v_email) then
    raise exception 'seed host email already belongs to a different account';
  end if;

  if not exists (select 1 from auth.users where id = v_host) then
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
      vals := array_append(
        vals,
        'extensions.crypt(gen_random_uuid()::text, extensions.gen_salt(''bf''))'
      );
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
      vals := array_append(vals, quote_literal('{"seed":"staging-catalog"}') || '::jsonb');
    end if;

    foreach colname in array array['email_confirmed_at', 'created_at', 'updated_at']
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
      where table_schema = 'auth' and table_name = 'users'
        and column_name = 'email_change_confirm_status'
        and is_generated = 'NEVER'
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
  end if;

  if to_regclass('auth.identities') is not null
     and not exists (select 1 from auth.identities where user_id = v_host) then
    begin
      execute format(
        'insert into auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at)
         values (gen_random_uuid(), %L::uuid, %L::jsonb, ''email'', %L, now(), now())',
        v_host,
        json_build_object('sub', v_host::text, 'email', v_email)::text,
        v_host::text
      );
    exception
      when others then
        raise notice 'auth.identities insert skipped: %', sqlerrm;
    end;
  end if;

  insert into public.users (id, status, primary_role)
  values (v_host, 'active', 'tenant')
  on conflict (id) do update
  set status = 'active', primary_role = 'tenant';

  insert into public.profiles (
    user_id, display_name, occupation, public_bio, verification_status
  ) values (
    v_host,
    'Neel R.',
    'Analyst',
    'Staging catalog tenant. Looking across cities. Contact stays private.',
    'mock_verified'
  )
  on conflict (user_id) do update
  set display_name = excluded.display_name,
      occupation = excluded.occupation,
      public_bio = excluded.public_bio,
      verification_status = excluded.verification_status;


  insert into public.private_contacts (user_id, email, phone)
  values (v_host, v_email, null)
  on conflict (user_id) do update
  set email = excluded.email,
      phone = null;
end
$homizi_seed_tenant$;

update public.profiles
set avatar_path = 'https://homizi.netlify.app/demo_media/avatar_02.webp'
where user_id = 'c0ffee00-0000-4000-8000-000000000002'::uuid;

do $homizi_ahmedabad_localities$
begin
  if to_regclass('public.localities') is null then
    raise notice 'localities table is absent; Ahmedabad rows skipped';
    return;
  end if;
  insert into public.localities (city, name, slug, popularity)
  values
    ('Ahmedabad', 'Satellite', 'satellite', 90),
    ('Ahmedabad', 'Bodakdev', 'bodakdev', 88),
    ('Ahmedabad', 'Prahlad Nagar', 'prahlad-nagar', 86),
    ('Ahmedabad', 'Vastrapur', 'vastrapur', 84),
    ('Ahmedabad', 'SG Highway', 'sg-highway', 82),
    ('Ahmedabad', 'Thaltej', 'thaltej', 80),
    ('Ahmedabad', 'Navrangpura', 'navrangpura', 78),
    ('Ahmedabad', 'Bopal', 'bopal', 76)
  on conflict (city, slug) do nothing;
end
$homizi_ahmedabad_localities$;

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, deposit_inr, brokerage_inr, maintenance_inr, status,
  occupancy_max, available_from, published_at, address_visibility,
  area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
  gated_society, floor_no, total_floors, approx_latitude, approx_longitude
)
select
  id,
  'c0ffee00-0000-4000-8000-000000000001'::uuid,
  title,
  locality,
  city,
  property_type,
  furnishing,
  rent_inr,
  deposit_inr,
  brokerage_inr,
  maintenance_inr,
  'published'::public.listing_status,
  occupancy_max,
  available_from,
  published_at,
  'locality_only'::public.address_visibility,
  area_sqft,
  preferred_tenants,
  parking,
  pets_allowed,
  non_veg_allowed,
  gated_society,
  floor_no,
  total_floors,
  approx_latitude,
  approx_longitude
from (
  values
  ('d1000201-0000-4000-8000-000000000201'::uuid, 'PG bed near Malleswaram 18th Cross', 'Malleswaram', 'Bengaluru', 'pg'::public.property_type, 'furnished'::public.furnishing, 11000, 22000, 0, 800, 2, null::date, timestamptz '2026-10-02 09:00:00+00', 350, array['female']::text[], false, true, false, true, 2, 4, 13.006, 77.570),
  ('d1000202-0000-4000-8000-000000000202'::uuid, 'Unfurnished 1 BHK in Dadar', 'Dadar', 'Mumbai', 'apartment'::public.property_type, 'unfurnished'::public.furnishing, 14500, 45000, 0, 800, 2, (current_date + 10), timestamptz '2026-10-02 09:00:00+00', 560, array['bachelors']::text[], true, false, true, false, 0, 5, 19.021, 72.844),
  ('d1000203-0000-4000-8000-000000000203'::uuid, 'Furnished studio in Hadapsar', 'Hadapsar', 'Pune', 'studio'::public.property_type, 'furnished'::public.furnishing, 9500, 19000, 0, 800, 1, null::date, timestamptz '2026-10-02 09:00:00+00', 280, array['any']::text[], false, false, true, false, 1, 4, 18.502, 73.926),
  ('d1000204-0000-4000-8000-000000000204'::uuid, 'Semi-furnished 2 BHK in Rohini', 'Rohini', 'Delhi NCR', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 22000, 66000, 0, 800, 4, null::date, timestamptz '2026-10-02 09:00:00+00', 980, array['family']::text[], true, false, false, true, 6, 12, 28.749, 77.056),
  ('d1000205-0000-4000-8000-000000000205'::uuid, 'Furnished 4 BHK in Jubilee Hills', 'Jubilee Hills', 'Hyderabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 62000, 186000, 0, 800, 6, (current_date + 120), timestamptz '2026-10-02 09:00:00+00', 2100, array['family']::text[], true, true, true, true, 12, 14, 17.432, 78.407),
  ('d1000206-0000-4000-8000-000000000206'::uuid, 'Semi-furnished 3 BHK in Adyar', 'Adyar', 'Chennai', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 35000, 105000, 0, 800, 5, (current_date + 10), timestamptz '2026-10-02 09:00:00+00', 1450, array['family']::text[], true, false, true, true, 4, 8, 13.001, 80.257),
  ('d1000207-0000-4000-8000-000000000207'::uuid, 'Furnished 2 BHK near T. Nagar', 'T. Nagar', 'Chennai', 'apartment'::public.property_type, 'furnished'::public.furnishing, 27000, 81000, 0, 800, 3, null::date, timestamptz '2026-10-02 09:00:00+00', 1100, array['bachelors']::text[], false, false, true, false, 3, 6, 13.041, 80.234),
  ('d1000208-0000-4000-8000-000000000208'::uuid, 'Shared room in Velachery', 'Velachery', 'Chennai', 'shared_room'::public.property_type, 'unfurnished'::public.furnishing, 8000, 16000, 0, 800, 2, null::date, timestamptz '2026-10-02 09:00:00+00', 180, array['female']::text[], false, false, false, false, 1, 3, 12.976, 80.221),
  ('d1000209-0000-4000-8000-000000000209'::uuid, 'Furnished 3 BHK in Satellite', 'Satellite', 'Ahmedabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 28000, 84000, 0, 800, 5, null::date, timestamptz '2026-10-02 09:00:00+00', 1500, array['family']::text[], true, false, false, true, 7, 10, 23.030, 72.518),
  ('d1000210-0000-4000-8000-000000000210'::uuid, 'Semi-furnished 2 BHK in Bodakdev', 'Bodakdev', 'Ahmedabad', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 24000, 72000, 0, 800, 3, (current_date + 10), timestamptz '2026-10-02 09:00:00+00', 1200, array['bachelors']::text[], true, true, true, true, 5, 9, 23.041, 72.512),
  ('d1000211-0000-4000-8000-000000000211'::uuid, 'Furnished 1 BHK in Prahlad Nagar', 'Prahlad Nagar', 'Ahmedabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 16000, 48000, 0, 800, 2, null::date, timestamptz '2026-10-02 09:00:00+00', 640, array['female']::text[], false, false, false, true, 2, 7, 23.012, 72.512),
  ('d1000212-0000-4000-8000-000000000212'::uuid, '4 BHK apartment in Vastrapur', 'Vastrapur', 'Ahmedabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 48000, 144000, 0, 800, 6, (current_date + 120), timestamptz '2026-10-02 09:00:00+00', 2400, array['family']::text[], true, true, false, true, 9, 12, 23.039, 72.529),
  ('d1000213-0000-4000-8000-000000000213'::uuid, 'Villa on SG Highway', 'SG Highway', 'Ahmedabad', 'villa'::public.property_type, 'furnished'::public.furnishing, 75000, 225000, 0, 800, 8, null::date, timestamptz '2026-10-02 09:00:00+00', 3600, array['family']::text[], true, true, true, true, 1, 2, 23.046, 72.518),
  ('d1000214-0000-4000-8000-000000000214'::uuid, 'Independent house in Thaltej', 'Thaltej', 'Ahmedabad', 'independent_house'::public.property_type, 'semi_furnished'::public.furnishing, 32000, 96000, 0, 800, 5, null::date, timestamptz '2026-10-02 09:00:00+00', 1800, array['family']::text[], true, true, true, false, 0, 2, 23.049, 72.496),
  ('d1000215-0000-4000-8000-000000000215'::uuid, 'Studio near Navrangpura', 'Navrangpura', 'Ahmedabad', 'studio'::public.property_type, 'furnished'::public.furnishing, 13000, 26000, 0, 800, 1, (current_date + 10), timestamptz '2026-10-02 09:00:00+00', 420, array['any']::text[], false, false, true, false, 3, 5, 23.037, 72.566),
  ('d1000216-0000-4000-8000-000000000216'::uuid, 'Private room in Bopal', 'Bopal', 'Ahmedabad', 'private_room'::public.property_type, 'semi_furnished'::public.furnishing, 7000, 14000, 0, 800, 1, null::date, timestamptz '2026-10-02 09:00:00+00', 220, array['female']::text[], false, true, false, false, 1, 3, 22.998, 72.465),
  ('d1000217-0000-4000-8000-000000000217'::uuid, 'Villa in Kalyani Nagar', 'Kalyani Nagar', 'Pune', 'villa'::public.property_type, 'furnished'::public.furnishing, 52000, 156000, 0, 800, 6, (current_date + 120), timestamptz '2026-10-02 09:00:00+00', 2800, array['family']::text[], true, true, false, true, 2, 2, 18.548, 73.902),
  ('d1000218-0000-4000-8000-000000000218'::uuid, 'Independent house in Juhu', 'Juhu', 'Mumbai', 'independent_house'::public.property_type, 'unfurnished'::public.furnishing, 40000, 120000, 0, 800, 4, null::date, timestamptz '2026-10-02 09:00:00+00', 1600, array['bachelors']::text[], true, false, true, false, 0, 2, 19.107, 72.826),
  ('d1000219-0000-4000-8000-000000000219'::uuid, 'High-floor 2 BHK in Whitefield', 'Whitefield', 'Bengaluru', 'apartment'::public.property_type, 'furnished'::public.furnishing, 26000, 78000, 0, 800, 3, (current_date + 10), timestamptz '2026-10-02 09:00:00+00', 900, array['bachelors', 'female']::text[], true, false, true, true, 18, 20, 12.969, 77.750),
  ('d1000220-0000-4000-8000-000000000220'::uuid, 'Semi-furnished 1 BHK in Anna Nagar', 'Anna Nagar', 'Chennai', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 18000, 54000, 0, 800, 2, null::date, timestamptz '2026-10-02 09:00:00+00', 700, array['any']::text[], true, false, false, true, 8, 10, 13.085, 80.210),
  ('d1000221-0000-4000-8000-000000000221'::uuid, 'PG room in Manikonda', 'Manikonda', 'Hyderabad', 'pg'::public.property_type, 'semi_furnished'::public.furnishing, 10000, 20000, 0, 800, 1, null::date, timestamptz '2026-10-02 09:00:00+00', 240, array['bachelors']::text[], false, false, true, false, 2, 4, 17.406, 78.376),
  ('d1000222-0000-4000-8000-000000000222'::uuid, 'Shared room near Porur', 'Porur', 'Chennai', 'shared_room'::public.property_type, 'semi_furnished'::public.furnishing, 9000, 18000, 0, 800, 2, null::date, timestamptz '2026-10-02 09:00:00+00', 200, array['bachelors']::text[], false, false, true, false, 0, 2, 13.038, 80.156)
) as seed (
  id, title, locality, city, property_type, furnishing,
  rent_inr, deposit_inr, brokerage_inr, maintenance_inr,
  occupancy_max, available_from, published_at,
  area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
  gated_society, floor_no, total_floors, approx_latitude, approx_longitude
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
    brokerage_inr = excluded.brokerage_inr,
    maintenance_inr = excluded.maintenance_inr,
    status = 'published',
    occupancy_max = excluded.occupancy_max,
    available_from = excluded.available_from,
    published_at = excluded.published_at,
    address_visibility = 'locality_only',
    area_sqft = excluded.area_sqft,
    preferred_tenants = excluded.preferred_tenants,
    parking = excluded.parking,
    pets_allowed = excluded.pets_allowed,
    non_veg_allowed = excluded.non_veg_allowed,
    gated_society = excluded.gated_society,
    floor_no = excluded.floor_no,
    total_floors = excluded.total_floors,
    approx_latitude = excluded.approx_latitude,
    approx_longitude = excluded.approx_longitude;

insert into public.property_features (property_id, feature_key, value)
select property_id, feature_key, value
from (
  values
  ('d1000201-0000-4000-8000-000000000201'::uuid, 'bedrooms', '1'),
  ('d1000202-0000-4000-8000-000000000202'::uuid, 'bedrooms', '1'),
  ('d1000203-0000-4000-8000-000000000203'::uuid, 'bedrooms', '0'),
  ('d1000204-0000-4000-8000-000000000204'::uuid, 'bedrooms', '2'),
  ('d1000205-0000-4000-8000-000000000205'::uuid, 'bedrooms', '4'),
  ('d1000206-0000-4000-8000-000000000206'::uuid, 'bedrooms', '3'),
  ('d1000207-0000-4000-8000-000000000207'::uuid, 'bedrooms', '2'),
  ('d1000208-0000-4000-8000-000000000208'::uuid, 'bedrooms', '1'),
  ('d1000209-0000-4000-8000-000000000209'::uuid, 'bedrooms', '3'),
  ('d1000210-0000-4000-8000-000000000210'::uuid, 'bedrooms', '2'),
  ('d1000211-0000-4000-8000-000000000211'::uuid, 'bedrooms', '1'),
  ('d1000212-0000-4000-8000-000000000212'::uuid, 'bedrooms', '4'),
  ('d1000213-0000-4000-8000-000000000213'::uuid, 'bedrooms', '4'),
  ('d1000214-0000-4000-8000-000000000214'::uuid, 'bedrooms', '3'),
  ('d1000215-0000-4000-8000-000000000215'::uuid, 'bedrooms', '0'),
  ('d1000216-0000-4000-8000-000000000216'::uuid, 'bedrooms', '1'),
  ('d1000217-0000-4000-8000-000000000217'::uuid, 'bedrooms', '3'),
  ('d1000218-0000-4000-8000-000000000218'::uuid, 'bedrooms', '2'),
  ('d1000219-0000-4000-8000-000000000219'::uuid, 'bedrooms', '2'),
  ('d1000220-0000-4000-8000-000000000220'::uuid, 'bedrooms', '1'),
  ('d1000221-0000-4000-8000-000000000221'::uuid, 'bedrooms', '1'),
  ('d1000222-0000-4000-8000-000000000222'::uuid, 'bedrooms', '1')
) as seed (property_id, feature_key, value)
where exists (
  select 1 from public.properties p where p.id = seed.property_id
)
on conflict (property_id, feature_key) do update
set value = excluded.value;

update public.properties
set approx_latitude = 12.935, approx_longitude = 77.624
where id = 'd1000001-0000-4000-8000-000000000001'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 12.912, approx_longitude = 77.638
where id = 'd1000002-0000-4000-8000-000000000002'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 12.978, approx_longitude = 77.641
where id = 'd1000003-0000-4000-8000-000000000003'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 18.559, approx_longitude = 73.787
where id = 'd1000004-0000-4000-8000-000000000004'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 18.553, approx_longitude = 73.944
where id = 'd1000005-0000-4000-8000-000000000005'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 18.507, approx_longitude = 73.807
where id = 'd1000006-0000-4000-8000-000000000006'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 19.136, approx_longitude = 72.829
where id = 'd1000007-0000-4000-8000-000000000007'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 19.117, approx_longitude = 72.905
where id = 'd1000008-0000-4000-8000-000000000008'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 17.440, approx_longitude = 78.349
where id = 'd1000009-0000-4000-8000-000000000009'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 28.459, approx_longitude = 77.026
where id = 'd1000010-0000-4000-8000-000000000010'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 12.969, approx_longitude = 77.750
where id = 'd1000011-0000-4000-8000-000000000011'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 12.930, approx_longitude = 77.583
where id = 'd1000012-0000-4000-8000-000000000012'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 12.926, approx_longitude = 77.676
where id = 'd1000013-0000-4000-8000-000000000013'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 12.959, approx_longitude = 77.701
where id = 'd1000014-0000-4000-8000-000000000014'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 12.907, approx_longitude = 77.585
where id = 'd1000015-0000-4000-8000-000000000015'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 13.035, approx_longitude = 77.597
where id = 'd1000016-0000-4000-8000-000000000016'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 12.916, approx_longitude = 77.610
where id = 'd1000017-0000-4000-8000-000000000017'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 12.845, approx_longitude = 77.660
where id = 'd1000018-0000-4000-8000-000000000018'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 18.567, approx_longitude = 73.914
where id = 'd1000019-0000-4000-8000-000000000019'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 18.599, approx_longitude = 73.763
where id = 'd1000020-0000-4000-8000-000000000020'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 18.591, approx_longitude = 73.739
where id = 'd1000021-0000-4000-8000-000000000021'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 18.536, approx_longitude = 73.894
where id = 'd1000022-0000-4000-8000-000000000022'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 18.558, approx_longitude = 73.807
where id = 'd1000023-0000-4000-8000-000000000023'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 18.507, approx_longitude = 73.807
where id = 'd1000024-0000-4000-8000-000000000024'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 19.060, approx_longitude = 72.830
where id = 'd1000025-0000-4000-8000-000000000025'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 19.166, approx_longitude = 72.850
where id = 'd1000026-0000-4000-8000-000000000026'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 19.052, approx_longitude = 72.900
where id = 'd1000027-0000-4000-8000-000000000027'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 19.218, approx_longitude = 72.978
where id = 'd1000028-0000-4000-8000-000000000028'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 19.172, approx_longitude = 72.956
where id = 'd1000029-0000-4000-8000-000000000029'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 19.187, approx_longitude = 72.835
where id = 'd1000030-0000-4000-8000-000000000030'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 17.448, approx_longitude = 78.391
where id = 'd1000031-0000-4000-8000-000000000031'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 17.464, approx_longitude = 78.366
where id = 'd1000032-0000-4000-8000-000000000032'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 17.443, approx_longitude = 78.377
where id = 'd1000033-0000-4000-8000-000000000033'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 17.415, approx_longitude = 78.434
where id = 'd1000034-0000-4000-8000-000000000034'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 17.494, approx_longitude = 78.399
where id = 'd1000035-0000-4000-8000-000000000035'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 28.627, approx_longitude = 77.371
where id = 'd1000036-0000-4000-8000-000000000036'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 28.582, approx_longitude = 77.050
where id = 'd1000037-0000-4000-8000-000000000037'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 28.524, approx_longitude = 77.207
where id = 'd1000038-0000-4000-8000-000000000038'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 28.474, approx_longitude = 77.504
where id = 'd1000039-0000-4000-8000-000000000039'::uuid
  and approx_latitude is null;
update public.properties
set approx_latitude = 28.641, approx_longitude = 77.371
where id = 'd1000040-0000-4000-8000-000000000040'::uuid
  and approx_latitude is null;

delete from public.property_photos
where property_id in ('d1000001-0000-4000-8000-000000000001'::uuid, 'd1000002-0000-4000-8000-000000000002'::uuid, 'd1000003-0000-4000-8000-000000000003'::uuid, 'd1000004-0000-4000-8000-000000000004'::uuid, 'd1000005-0000-4000-8000-000000000005'::uuid, 'd1000006-0000-4000-8000-000000000006'::uuid, 'd1000007-0000-4000-8000-000000000007'::uuid, 'd1000008-0000-4000-8000-000000000008'::uuid, 'd1000009-0000-4000-8000-000000000009'::uuid, 'd1000010-0000-4000-8000-000000000010'::uuid, 'd1000011-0000-4000-8000-000000000011'::uuid, 'd1000012-0000-4000-8000-000000000012'::uuid, 'd1000013-0000-4000-8000-000000000013'::uuid, 'd1000014-0000-4000-8000-000000000014'::uuid, 'd1000015-0000-4000-8000-000000000015'::uuid, 'd1000016-0000-4000-8000-000000000016'::uuid, 'd1000017-0000-4000-8000-000000000017'::uuid, 'd1000018-0000-4000-8000-000000000018'::uuid, 'd1000019-0000-4000-8000-000000000019'::uuid, 'd1000020-0000-4000-8000-000000000020'::uuid, 'd1000021-0000-4000-8000-000000000021'::uuid, 'd1000022-0000-4000-8000-000000000022'::uuid, 'd1000023-0000-4000-8000-000000000023'::uuid, 'd1000024-0000-4000-8000-000000000024'::uuid, 'd1000025-0000-4000-8000-000000000025'::uuid, 'd1000026-0000-4000-8000-000000000026'::uuid, 'd1000027-0000-4000-8000-000000000027'::uuid, 'd1000028-0000-4000-8000-000000000028'::uuid, 'd1000029-0000-4000-8000-000000000029'::uuid, 'd1000030-0000-4000-8000-000000000030'::uuid, 'd1000031-0000-4000-8000-000000000031'::uuid, 'd1000032-0000-4000-8000-000000000032'::uuid, 'd1000033-0000-4000-8000-000000000033'::uuid, 'd1000034-0000-4000-8000-000000000034'::uuid, 'd1000035-0000-4000-8000-000000000035'::uuid, 'd1000036-0000-4000-8000-000000000036'::uuid, 'd1000037-0000-4000-8000-000000000037'::uuid, 'd1000038-0000-4000-8000-000000000038'::uuid, 'd1000039-0000-4000-8000-000000000039'::uuid, 'd1000040-0000-4000-8000-000000000040'::uuid, 'd1000201-0000-4000-8000-000000000201'::uuid, 'd1000202-0000-4000-8000-000000000202'::uuid, 'd1000203-0000-4000-8000-000000000203'::uuid, 'd1000204-0000-4000-8000-000000000204'::uuid, 'd1000205-0000-4000-8000-000000000205'::uuid, 'd1000206-0000-4000-8000-000000000206'::uuid, 'd1000207-0000-4000-8000-000000000207'::uuid, 'd1000208-0000-4000-8000-000000000208'::uuid, 'd1000209-0000-4000-8000-000000000209'::uuid, 'd1000210-0000-4000-8000-000000000210'::uuid, 'd1000211-0000-4000-8000-000000000211'::uuid, 'd1000212-0000-4000-8000-000000000212'::uuid, 'd1000213-0000-4000-8000-000000000213'::uuid, 'd1000214-0000-4000-8000-000000000214'::uuid, 'd1000215-0000-4000-8000-000000000215'::uuid, 'd1000216-0000-4000-8000-000000000216'::uuid, 'd1000217-0000-4000-8000-000000000217'::uuid, 'd1000218-0000-4000-8000-000000000218'::uuid, 'd1000219-0000-4000-8000-000000000219'::uuid, 'd1000220-0000-4000-8000-000000000220'::uuid, 'd1000221-0000-4000-8000-000000000221'::uuid, 'd1000222-0000-4000-8000-000000000222'::uuid)
  and id not in ('e1000001-0000-4000-8000-000000000000'::uuid, 'e1000001-0000-4000-8000-000000000001'::uuid, 'e1000001-0000-4000-8000-000000000002'::uuid, 'e1000002-0000-4000-8000-000000000000'::uuid, 'e1000002-0000-4000-8000-000000000001'::uuid, 'e1000002-0000-4000-8000-000000000002'::uuid, 'e1000002-0000-4000-8000-000000000003'::uuid, 'e1000003-0000-4000-8000-000000000000'::uuid, 'e1000003-0000-4000-8000-000000000001'::uuid, 'e1000003-0000-4000-8000-000000000002'::uuid, 'e1000003-0000-4000-8000-000000000003'::uuid, 'e1000003-0000-4000-8000-000000000004'::uuid, 'e1000004-0000-4000-8000-000000000000'::uuid, 'e1000004-0000-4000-8000-000000000001'::uuid, 'e1000004-0000-4000-8000-000000000002'::uuid, 'e1000004-0000-4000-8000-000000000003'::uuid, 'e1000004-0000-4000-8000-000000000004'::uuid, 'e1000004-0000-4000-8000-000000000005'::uuid, 'e1000005-0000-4000-8000-000000000000'::uuid, 'e1000005-0000-4000-8000-000000000001'::uuid, 'e1000005-0000-4000-8000-000000000002'::uuid, 'e1000006-0000-4000-8000-000000000000'::uuid, 'e1000006-0000-4000-8000-000000000001'::uuid, 'e1000006-0000-4000-8000-000000000002'::uuid, 'e1000006-0000-4000-8000-000000000003'::uuid, 'e1000007-0000-4000-8000-000000000000'::uuid, 'e1000007-0000-4000-8000-000000000001'::uuid, 'e1000007-0000-4000-8000-000000000002'::uuid, 'e1000007-0000-4000-8000-000000000003'::uuid, 'e1000007-0000-4000-8000-000000000004'::uuid, 'e1000008-0000-4000-8000-000000000000'::uuid, 'e1000008-0000-4000-8000-000000000001'::uuid, 'e1000008-0000-4000-8000-000000000002'::uuid, 'e1000008-0000-4000-8000-000000000003'::uuid, 'e1000008-0000-4000-8000-000000000004'::uuid, 'e1000008-0000-4000-8000-000000000005'::uuid, 'e1000009-0000-4000-8000-000000000000'::uuid, 'e1000009-0000-4000-8000-000000000001'::uuid, 'e1000009-0000-4000-8000-000000000002'::uuid, 'e1000010-0000-4000-8000-000000000000'::uuid, 'e1000010-0000-4000-8000-000000000001'::uuid, 'e1000010-0000-4000-8000-000000000002'::uuid, 'e1000010-0000-4000-8000-000000000003'::uuid, 'e1000011-0000-4000-8000-000000000000'::uuid, 'e1000011-0000-4000-8000-000000000001'::uuid, 'e1000011-0000-4000-8000-000000000002'::uuid, 'e1000011-0000-4000-8000-000000000003'::uuid, 'e1000011-0000-4000-8000-000000000004'::uuid, 'e1000012-0000-4000-8000-000000000000'::uuid, 'e1000012-0000-4000-8000-000000000001'::uuid, 'e1000012-0000-4000-8000-000000000002'::uuid, 'e1000012-0000-4000-8000-000000000003'::uuid, 'e1000012-0000-4000-8000-000000000004'::uuid, 'e1000012-0000-4000-8000-000000000005'::uuid, 'e1000013-0000-4000-8000-000000000000'::uuid, 'e1000013-0000-4000-8000-000000000001'::uuid, 'e1000013-0000-4000-8000-000000000002'::uuid, 'e1000014-0000-4000-8000-000000000000'::uuid, 'e1000014-0000-4000-8000-000000000001'::uuid, 'e1000014-0000-4000-8000-000000000002'::uuid, 'e1000014-0000-4000-8000-000000000003'::uuid, 'e1000015-0000-4000-8000-000000000000'::uuid, 'e1000015-0000-4000-8000-000000000001'::uuid, 'e1000015-0000-4000-8000-000000000002'::uuid, 'e1000015-0000-4000-8000-000000000003'::uuid, 'e1000015-0000-4000-8000-000000000004'::uuid, 'e1000016-0000-4000-8000-000000000000'::uuid, 'e1000016-0000-4000-8000-000000000001'::uuid, 'e1000016-0000-4000-8000-000000000002'::uuid, 'e1000016-0000-4000-8000-000000000003'::uuid, 'e1000016-0000-4000-8000-000000000004'::uuid, 'e1000016-0000-4000-8000-000000000005'::uuid, 'e1000017-0000-4000-8000-000000000000'::uuid, 'e1000017-0000-4000-8000-000000000001'::uuid, 'e1000017-0000-4000-8000-000000000002'::uuid, 'e1000018-0000-4000-8000-000000000000'::uuid, 'e1000018-0000-4000-8000-000000000001'::uuid, 'e1000018-0000-4000-8000-000000000002'::uuid, 'e1000018-0000-4000-8000-000000000003'::uuid, 'e1000019-0000-4000-8000-000000000000'::uuid, 'e1000019-0000-4000-8000-000000000001'::uuid, 'e1000019-0000-4000-8000-000000000002'::uuid, 'e1000019-0000-4000-8000-000000000003'::uuid, 'e1000019-0000-4000-8000-000000000004'::uuid, 'e1000020-0000-4000-8000-000000000000'::uuid, 'e1000020-0000-4000-8000-000000000001'::uuid, 'e1000020-0000-4000-8000-000000000002'::uuid, 'e1000020-0000-4000-8000-000000000003'::uuid, 'e1000020-0000-4000-8000-000000000004'::uuid, 'e1000020-0000-4000-8000-000000000005'::uuid, 'e1000021-0000-4000-8000-000000000000'::uuid, 'e1000021-0000-4000-8000-000000000001'::uuid, 'e1000021-0000-4000-8000-000000000002'::uuid, 'e1000022-0000-4000-8000-000000000000'::uuid, 'e1000022-0000-4000-8000-000000000001'::uuid, 'e1000022-0000-4000-8000-000000000002'::uuid, 'e1000022-0000-4000-8000-000000000003'::uuid, 'e1000023-0000-4000-8000-000000000000'::uuid, 'e1000023-0000-4000-8000-000000000001'::uuid, 'e1000023-0000-4000-8000-000000000002'::uuid, 'e1000023-0000-4000-8000-000000000003'::uuid, 'e1000023-0000-4000-8000-000000000004'::uuid, 'e1000024-0000-4000-8000-000000000000'::uuid, 'e1000024-0000-4000-8000-000000000001'::uuid, 'e1000024-0000-4000-8000-000000000002'::uuid, 'e1000024-0000-4000-8000-000000000003'::uuid, 'e1000024-0000-4000-8000-000000000004'::uuid, 'e1000024-0000-4000-8000-000000000005'::uuid, 'e1000025-0000-4000-8000-000000000000'::uuid, 'e1000025-0000-4000-8000-000000000001'::uuid, 'e1000025-0000-4000-8000-000000000002'::uuid, 'e1000026-0000-4000-8000-000000000000'::uuid, 'e1000026-0000-4000-8000-000000000001'::uuid, 'e1000026-0000-4000-8000-000000000002'::uuid, 'e1000026-0000-4000-8000-000000000003'::uuid, 'e1000027-0000-4000-8000-000000000000'::uuid, 'e1000027-0000-4000-8000-000000000001'::uuid, 'e1000027-0000-4000-8000-000000000002'::uuid, 'e1000027-0000-4000-8000-000000000003'::uuid, 'e1000027-0000-4000-8000-000000000004'::uuid, 'e1000028-0000-4000-8000-000000000000'::uuid, 'e1000028-0000-4000-8000-000000000001'::uuid, 'e1000028-0000-4000-8000-000000000002'::uuid, 'e1000028-0000-4000-8000-000000000003'::uuid, 'e1000028-0000-4000-8000-000000000004'::uuid, 'e1000028-0000-4000-8000-000000000005'::uuid, 'e1000029-0000-4000-8000-000000000000'::uuid, 'e1000029-0000-4000-8000-000000000001'::uuid, 'e1000029-0000-4000-8000-000000000002'::uuid, 'e1000030-0000-4000-8000-000000000000'::uuid, 'e1000030-0000-4000-8000-000000000001'::uuid, 'e1000030-0000-4000-8000-000000000002'::uuid, 'e1000030-0000-4000-8000-000000000003'::uuid, 'e1000031-0000-4000-8000-000000000000'::uuid, 'e1000031-0000-4000-8000-000000000001'::uuid, 'e1000031-0000-4000-8000-000000000002'::uuid, 'e1000031-0000-4000-8000-000000000003'::uuid, 'e1000031-0000-4000-8000-000000000004'::uuid, 'e1000032-0000-4000-8000-000000000000'::uuid, 'e1000032-0000-4000-8000-000000000001'::uuid, 'e1000032-0000-4000-8000-000000000002'::uuid, 'e1000032-0000-4000-8000-000000000003'::uuid, 'e1000032-0000-4000-8000-000000000004'::uuid, 'e1000032-0000-4000-8000-000000000005'::uuid, 'e1000033-0000-4000-8000-000000000000'::uuid, 'e1000033-0000-4000-8000-000000000001'::uuid, 'e1000033-0000-4000-8000-000000000002'::uuid, 'e1000034-0000-4000-8000-000000000000'::uuid, 'e1000034-0000-4000-8000-000000000001'::uuid, 'e1000034-0000-4000-8000-000000000002'::uuid, 'e1000034-0000-4000-8000-000000000003'::uuid, 'e1000035-0000-4000-8000-000000000000'::uuid, 'e1000035-0000-4000-8000-000000000001'::uuid, 'e1000035-0000-4000-8000-000000000002'::uuid, 'e1000035-0000-4000-8000-000000000003'::uuid, 'e1000035-0000-4000-8000-000000000004'::uuid, 'e1000036-0000-4000-8000-000000000000'::uuid, 'e1000036-0000-4000-8000-000000000001'::uuid, 'e1000036-0000-4000-8000-000000000002'::uuid, 'e1000036-0000-4000-8000-000000000003'::uuid, 'e1000036-0000-4000-8000-000000000004'::uuid, 'e1000036-0000-4000-8000-000000000005'::uuid, 'e1000037-0000-4000-8000-000000000000'::uuid, 'e1000037-0000-4000-8000-000000000001'::uuid, 'e1000037-0000-4000-8000-000000000002'::uuid, 'e1000038-0000-4000-8000-000000000000'::uuid, 'e1000038-0000-4000-8000-000000000001'::uuid, 'e1000038-0000-4000-8000-000000000002'::uuid, 'e1000038-0000-4000-8000-000000000003'::uuid, 'e1000039-0000-4000-8000-000000000000'::uuid, 'e1000039-0000-4000-8000-000000000001'::uuid, 'e1000039-0000-4000-8000-000000000002'::uuid, 'e1000039-0000-4000-8000-000000000003'::uuid, 'e1000039-0000-4000-8000-000000000004'::uuid, 'e1000040-0000-4000-8000-000000000000'::uuid, 'e1000040-0000-4000-8000-000000000001'::uuid, 'e1000040-0000-4000-8000-000000000002'::uuid, 'e1000040-0000-4000-8000-000000000003'::uuid, 'e1000040-0000-4000-8000-000000000004'::uuid, 'e1000040-0000-4000-8000-000000000005'::uuid, 'e1000201-0000-4000-8000-000000000000'::uuid, 'e1000201-0000-4000-8000-000000000001'::uuid, 'e1000201-0000-4000-8000-000000000002'::uuid, 'e1000202-0000-4000-8000-000000000000'::uuid, 'e1000202-0000-4000-8000-000000000001'::uuid, 'e1000202-0000-4000-8000-000000000002'::uuid, 'e1000202-0000-4000-8000-000000000003'::uuid, 'e1000203-0000-4000-8000-000000000000'::uuid, 'e1000203-0000-4000-8000-000000000001'::uuid, 'e1000203-0000-4000-8000-000000000002'::uuid, 'e1000203-0000-4000-8000-000000000003'::uuid, 'e1000203-0000-4000-8000-000000000004'::uuid, 'e1000204-0000-4000-8000-000000000000'::uuid, 'e1000204-0000-4000-8000-000000000001'::uuid, 'e1000204-0000-4000-8000-000000000002'::uuid, 'e1000204-0000-4000-8000-000000000003'::uuid, 'e1000204-0000-4000-8000-000000000004'::uuid, 'e1000204-0000-4000-8000-000000000005'::uuid, 'e1000205-0000-4000-8000-000000000000'::uuid, 'e1000205-0000-4000-8000-000000000001'::uuid, 'e1000205-0000-4000-8000-000000000002'::uuid, 'e1000206-0000-4000-8000-000000000000'::uuid, 'e1000206-0000-4000-8000-000000000001'::uuid, 'e1000206-0000-4000-8000-000000000002'::uuid, 'e1000206-0000-4000-8000-000000000003'::uuid, 'e1000207-0000-4000-8000-000000000000'::uuid, 'e1000207-0000-4000-8000-000000000001'::uuid, 'e1000207-0000-4000-8000-000000000002'::uuid, 'e1000207-0000-4000-8000-000000000003'::uuid, 'e1000207-0000-4000-8000-000000000004'::uuid, 'e1000208-0000-4000-8000-000000000000'::uuid, 'e1000208-0000-4000-8000-000000000001'::uuid, 'e1000208-0000-4000-8000-000000000002'::uuid, 'e1000208-0000-4000-8000-000000000003'::uuid, 'e1000208-0000-4000-8000-000000000004'::uuid, 'e1000208-0000-4000-8000-000000000005'::uuid, 'e1000209-0000-4000-8000-000000000000'::uuid, 'e1000209-0000-4000-8000-000000000001'::uuid, 'e1000209-0000-4000-8000-000000000002'::uuid, 'e1000210-0000-4000-8000-000000000000'::uuid, 'e1000210-0000-4000-8000-000000000001'::uuid, 'e1000210-0000-4000-8000-000000000002'::uuid, 'e1000210-0000-4000-8000-000000000003'::uuid, 'e1000211-0000-4000-8000-000000000000'::uuid, 'e1000211-0000-4000-8000-000000000001'::uuid, 'e1000211-0000-4000-8000-000000000002'::uuid, 'e1000211-0000-4000-8000-000000000003'::uuid, 'e1000211-0000-4000-8000-000000000004'::uuid, 'e1000212-0000-4000-8000-000000000000'::uuid, 'e1000212-0000-4000-8000-000000000001'::uuid, 'e1000212-0000-4000-8000-000000000002'::uuid, 'e1000212-0000-4000-8000-000000000003'::uuid, 'e1000212-0000-4000-8000-000000000004'::uuid, 'e1000212-0000-4000-8000-000000000005'::uuid, 'e1000213-0000-4000-8000-000000000000'::uuid, 'e1000213-0000-4000-8000-000000000001'::uuid, 'e1000213-0000-4000-8000-000000000002'::uuid, 'e1000214-0000-4000-8000-000000000000'::uuid, 'e1000214-0000-4000-8000-000000000001'::uuid, 'e1000214-0000-4000-8000-000000000002'::uuid, 'e1000214-0000-4000-8000-000000000003'::uuid, 'e1000215-0000-4000-8000-000000000000'::uuid, 'e1000215-0000-4000-8000-000000000001'::uuid, 'e1000215-0000-4000-8000-000000000002'::uuid, 'e1000215-0000-4000-8000-000000000003'::uuid, 'e1000215-0000-4000-8000-000000000004'::uuid, 'e1000216-0000-4000-8000-000000000000'::uuid, 'e1000216-0000-4000-8000-000000000001'::uuid, 'e1000216-0000-4000-8000-000000000002'::uuid, 'e1000216-0000-4000-8000-000000000003'::uuid, 'e1000216-0000-4000-8000-000000000004'::uuid, 'e1000216-0000-4000-8000-000000000005'::uuid, 'e1000217-0000-4000-8000-000000000000'::uuid, 'e1000217-0000-4000-8000-000000000001'::uuid, 'e1000217-0000-4000-8000-000000000002'::uuid, 'e1000218-0000-4000-8000-000000000000'::uuid, 'e1000218-0000-4000-8000-000000000001'::uuid, 'e1000218-0000-4000-8000-000000000002'::uuid, 'e1000218-0000-4000-8000-000000000003'::uuid, 'e1000219-0000-4000-8000-000000000000'::uuid, 'e1000219-0000-4000-8000-000000000001'::uuid, 'e1000219-0000-4000-8000-000000000002'::uuid, 'e1000219-0000-4000-8000-000000000003'::uuid, 'e1000219-0000-4000-8000-000000000004'::uuid, 'e1000220-0000-4000-8000-000000000000'::uuid, 'e1000220-0000-4000-8000-000000000001'::uuid, 'e1000220-0000-4000-8000-000000000002'::uuid, 'e1000220-0000-4000-8000-000000000003'::uuid, 'e1000220-0000-4000-8000-000000000004'::uuid, 'e1000220-0000-4000-8000-000000000005'::uuid, 'e1000221-0000-4000-8000-000000000000'::uuid, 'e1000221-0000-4000-8000-000000000001'::uuid, 'e1000221-0000-4000-8000-000000000002'::uuid, 'e1000222-0000-4000-8000-000000000000'::uuid, 'e1000222-0000-4000-8000-000000000001'::uuid, 'e1000222-0000-4000-8000-000000000002'::uuid, 'e1000222-0000-4000-8000-000000000003'::uuid);

insert into public.property_photos (
  id, property_id, storage_path, sort_order, photo_type, moderation_status
)
select
  id,
  property_id,
  storage_path,
  sort_order,
  photo_type::public.photo_type,
  'approved'::public.moderation_status
from (
  values
  ('e1000001-0000-4000-8000-000000000000'::uuid, 'd1000001-0000-4000-8000-000000000001'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000001-0000-4000-8000-000000000001'::uuid, 'd1000001-0000-4000-8000-000000000001'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000001-0000-4000-8000-000000000002'::uuid, 'd1000001-0000-4000-8000-000000000001'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000002-0000-4000-8000-000000000000'::uuid, 'd1000002-0000-4000-8000-000000000002'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000002-0000-4000-8000-000000000001'::uuid, 'd1000002-0000-4000-8000-000000000002'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000002-0000-4000-8000-000000000002'::uuid, 'd1000002-0000-4000-8000-000000000002'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000002-0000-4000-8000-000000000003'::uuid, 'd1000002-0000-4000-8000-000000000002'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000003-0000-4000-8000-000000000000'::uuid, 'd1000003-0000-4000-8000-000000000003'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000003-0000-4000-8000-000000000001'::uuid, 'd1000003-0000-4000-8000-000000000003'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000003-0000-4000-8000-000000000002'::uuid, 'd1000003-0000-4000-8000-000000000003'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000003-0000-4000-8000-000000000003'::uuid, 'd1000003-0000-4000-8000-000000000003'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000003-0000-4000-8000-000000000004'::uuid, 'd1000003-0000-4000-8000-000000000003'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 4, 'exterior'),
  ('e1000004-0000-4000-8000-000000000000'::uuid, 'd1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000004-0000-4000-8000-000000000001'::uuid, 'd1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000004-0000-4000-8000-000000000002'::uuid, 'd1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000004-0000-4000-8000-000000000003'::uuid, 'd1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000004-0000-4000-8000-000000000004'::uuid, 'd1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000004-0000-4000-8000-000000000005'::uuid, 'd1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 5, 'exterior'),
  ('e1000005-0000-4000-8000-000000000000'::uuid, 'd1000005-0000-4000-8000-000000000005'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000005-0000-4000-8000-000000000001'::uuid, 'd1000005-0000-4000-8000-000000000005'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000005-0000-4000-8000-000000000002'::uuid, 'd1000005-0000-4000-8000-000000000005'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000006-0000-4000-8000-000000000000'::uuid, 'd1000006-0000-4000-8000-000000000006'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000006-0000-4000-8000-000000000001'::uuid, 'd1000006-0000-4000-8000-000000000006'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000006-0000-4000-8000-000000000002'::uuid, 'd1000006-0000-4000-8000-000000000006'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000006-0000-4000-8000-000000000003'::uuid, 'd1000006-0000-4000-8000-000000000006'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000007-0000-4000-8000-000000000000'::uuid, 'd1000007-0000-4000-8000-000000000007'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000007-0000-4000-8000-000000000001'::uuid, 'd1000007-0000-4000-8000-000000000007'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000007-0000-4000-8000-000000000002'::uuid, 'd1000007-0000-4000-8000-000000000007'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000007-0000-4000-8000-000000000003'::uuid, 'd1000007-0000-4000-8000-000000000007'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000007-0000-4000-8000-000000000004'::uuid, 'd1000007-0000-4000-8000-000000000007'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 4, 'exterior'),
  ('e1000008-0000-4000-8000-000000000000'::uuid, 'd1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000008-0000-4000-8000-000000000001'::uuid, 'd1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000008-0000-4000-8000-000000000002'::uuid, 'd1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000008-0000-4000-8000-000000000003'::uuid, 'd1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000008-0000-4000-8000-000000000004'::uuid, 'd1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000008-0000-4000-8000-000000000005'::uuid, 'd1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 5, 'exterior'),
  ('e1000009-0000-4000-8000-000000000000'::uuid, 'd1000009-0000-4000-8000-000000000009'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000009-0000-4000-8000-000000000001'::uuid, 'd1000009-0000-4000-8000-000000000009'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000009-0000-4000-8000-000000000002'::uuid, 'd1000009-0000-4000-8000-000000000009'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000010-0000-4000-8000-000000000000'::uuid, 'd1000010-0000-4000-8000-000000000010'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000010-0000-4000-8000-000000000001'::uuid, 'd1000010-0000-4000-8000-000000000010'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000010-0000-4000-8000-000000000002'::uuid, 'd1000010-0000-4000-8000-000000000010'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000010-0000-4000-8000-000000000003'::uuid, 'd1000010-0000-4000-8000-000000000010'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000011-0000-4000-8000-000000000000'::uuid, 'd1000011-0000-4000-8000-000000000011'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000011-0000-4000-8000-000000000001'::uuid, 'd1000011-0000-4000-8000-000000000011'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000011-0000-4000-8000-000000000002'::uuid, 'd1000011-0000-4000-8000-000000000011'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000011-0000-4000-8000-000000000003'::uuid, 'd1000011-0000-4000-8000-000000000011'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000011-0000-4000-8000-000000000004'::uuid, 'd1000011-0000-4000-8000-000000000011'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 4, 'exterior'),
  ('e1000012-0000-4000-8000-000000000000'::uuid, 'd1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000012-0000-4000-8000-000000000001'::uuid, 'd1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000012-0000-4000-8000-000000000002'::uuid, 'd1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000012-0000-4000-8000-000000000003'::uuid, 'd1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000012-0000-4000-8000-000000000004'::uuid, 'd1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000012-0000-4000-8000-000000000005'::uuid, 'd1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 5, 'exterior'),
  ('e1000013-0000-4000-8000-000000000000'::uuid, 'd1000013-0000-4000-8000-000000000013'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000013-0000-4000-8000-000000000001'::uuid, 'd1000013-0000-4000-8000-000000000013'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000013-0000-4000-8000-000000000002'::uuid, 'd1000013-0000-4000-8000-000000000013'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000014-0000-4000-8000-000000000000'::uuid, 'd1000014-0000-4000-8000-000000000014'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000014-0000-4000-8000-000000000001'::uuid, 'd1000014-0000-4000-8000-000000000014'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000014-0000-4000-8000-000000000002'::uuid, 'd1000014-0000-4000-8000-000000000014'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000014-0000-4000-8000-000000000003'::uuid, 'd1000014-0000-4000-8000-000000000014'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000015-0000-4000-8000-000000000000'::uuid, 'd1000015-0000-4000-8000-000000000015'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000015-0000-4000-8000-000000000001'::uuid, 'd1000015-0000-4000-8000-000000000015'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000015-0000-4000-8000-000000000002'::uuid, 'd1000015-0000-4000-8000-000000000015'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000015-0000-4000-8000-000000000003'::uuid, 'd1000015-0000-4000-8000-000000000015'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000015-0000-4000-8000-000000000004'::uuid, 'd1000015-0000-4000-8000-000000000015'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 4, 'exterior'),
  ('e1000016-0000-4000-8000-000000000000'::uuid, 'd1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000016-0000-4000-8000-000000000001'::uuid, 'd1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000016-0000-4000-8000-000000000002'::uuid, 'd1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000016-0000-4000-8000-000000000003'::uuid, 'd1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000016-0000-4000-8000-000000000004'::uuid, 'd1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000016-0000-4000-8000-000000000005'::uuid, 'd1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 5, 'exterior'),
  ('e1000017-0000-4000-8000-000000000000'::uuid, 'd1000017-0000-4000-8000-000000000017'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000017-0000-4000-8000-000000000001'::uuid, 'd1000017-0000-4000-8000-000000000017'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000017-0000-4000-8000-000000000002'::uuid, 'd1000017-0000-4000-8000-000000000017'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000018-0000-4000-8000-000000000000'::uuid, 'd1000018-0000-4000-8000-000000000018'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000018-0000-4000-8000-000000000001'::uuid, 'd1000018-0000-4000-8000-000000000018'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000018-0000-4000-8000-000000000002'::uuid, 'd1000018-0000-4000-8000-000000000018'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000018-0000-4000-8000-000000000003'::uuid, 'd1000018-0000-4000-8000-000000000018'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000019-0000-4000-8000-000000000000'::uuid, 'd1000019-0000-4000-8000-000000000019'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000019-0000-4000-8000-000000000001'::uuid, 'd1000019-0000-4000-8000-000000000019'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000019-0000-4000-8000-000000000002'::uuid, 'd1000019-0000-4000-8000-000000000019'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000019-0000-4000-8000-000000000003'::uuid, 'd1000019-0000-4000-8000-000000000019'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000019-0000-4000-8000-000000000004'::uuid, 'd1000019-0000-4000-8000-000000000019'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 4, 'exterior'),
  ('e1000020-0000-4000-8000-000000000000'::uuid, 'd1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000020-0000-4000-8000-000000000001'::uuid, 'd1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000020-0000-4000-8000-000000000002'::uuid, 'd1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000020-0000-4000-8000-000000000003'::uuid, 'd1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000020-0000-4000-8000-000000000004'::uuid, 'd1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000020-0000-4000-8000-000000000005'::uuid, 'd1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 5, 'exterior'),
  ('e1000021-0000-4000-8000-000000000000'::uuid, 'd1000021-0000-4000-8000-000000000021'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000021-0000-4000-8000-000000000001'::uuid, 'd1000021-0000-4000-8000-000000000021'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000021-0000-4000-8000-000000000002'::uuid, 'd1000021-0000-4000-8000-000000000021'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000022-0000-4000-8000-000000000000'::uuid, 'd1000022-0000-4000-8000-000000000022'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000022-0000-4000-8000-000000000001'::uuid, 'd1000022-0000-4000-8000-000000000022'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000022-0000-4000-8000-000000000002'::uuid, 'd1000022-0000-4000-8000-000000000022'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000022-0000-4000-8000-000000000003'::uuid, 'd1000022-0000-4000-8000-000000000022'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000023-0000-4000-8000-000000000000'::uuid, 'd1000023-0000-4000-8000-000000000023'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000023-0000-4000-8000-000000000001'::uuid, 'd1000023-0000-4000-8000-000000000023'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000023-0000-4000-8000-000000000002'::uuid, 'd1000023-0000-4000-8000-000000000023'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000023-0000-4000-8000-000000000003'::uuid, 'd1000023-0000-4000-8000-000000000023'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000023-0000-4000-8000-000000000004'::uuid, 'd1000023-0000-4000-8000-000000000023'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 4, 'exterior'),
  ('e1000024-0000-4000-8000-000000000000'::uuid, 'd1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000024-0000-4000-8000-000000000001'::uuid, 'd1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000024-0000-4000-8000-000000000002'::uuid, 'd1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000024-0000-4000-8000-000000000003'::uuid, 'd1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000024-0000-4000-8000-000000000004'::uuid, 'd1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000024-0000-4000-8000-000000000005'::uuid, 'd1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 5, 'exterior'),
  ('e1000025-0000-4000-8000-000000000000'::uuid, 'd1000025-0000-4000-8000-000000000025'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000025-0000-4000-8000-000000000001'::uuid, 'd1000025-0000-4000-8000-000000000025'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000025-0000-4000-8000-000000000002'::uuid, 'd1000025-0000-4000-8000-000000000025'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000026-0000-4000-8000-000000000000'::uuid, 'd1000026-0000-4000-8000-000000000026'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000026-0000-4000-8000-000000000001'::uuid, 'd1000026-0000-4000-8000-000000000026'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000026-0000-4000-8000-000000000002'::uuid, 'd1000026-0000-4000-8000-000000000026'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000026-0000-4000-8000-000000000003'::uuid, 'd1000026-0000-4000-8000-000000000026'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000027-0000-4000-8000-000000000000'::uuid, 'd1000027-0000-4000-8000-000000000027'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000027-0000-4000-8000-000000000001'::uuid, 'd1000027-0000-4000-8000-000000000027'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000027-0000-4000-8000-000000000002'::uuid, 'd1000027-0000-4000-8000-000000000027'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000027-0000-4000-8000-000000000003'::uuid, 'd1000027-0000-4000-8000-000000000027'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000027-0000-4000-8000-000000000004'::uuid, 'd1000027-0000-4000-8000-000000000027'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 4, 'exterior'),
  ('e1000028-0000-4000-8000-000000000000'::uuid, 'd1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000028-0000-4000-8000-000000000001'::uuid, 'd1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000028-0000-4000-8000-000000000002'::uuid, 'd1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000028-0000-4000-8000-000000000003'::uuid, 'd1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000028-0000-4000-8000-000000000004'::uuid, 'd1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000028-0000-4000-8000-000000000005'::uuid, 'd1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 5, 'exterior'),
  ('e1000029-0000-4000-8000-000000000000'::uuid, 'd1000029-0000-4000-8000-000000000029'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000029-0000-4000-8000-000000000001'::uuid, 'd1000029-0000-4000-8000-000000000029'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000029-0000-4000-8000-000000000002'::uuid, 'd1000029-0000-4000-8000-000000000029'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000030-0000-4000-8000-000000000000'::uuid, 'd1000030-0000-4000-8000-000000000030'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000030-0000-4000-8000-000000000001'::uuid, 'd1000030-0000-4000-8000-000000000030'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000030-0000-4000-8000-000000000002'::uuid, 'd1000030-0000-4000-8000-000000000030'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000030-0000-4000-8000-000000000003'::uuid, 'd1000030-0000-4000-8000-000000000030'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000031-0000-4000-8000-000000000000'::uuid, 'd1000031-0000-4000-8000-000000000031'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000031-0000-4000-8000-000000000001'::uuid, 'd1000031-0000-4000-8000-000000000031'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000031-0000-4000-8000-000000000002'::uuid, 'd1000031-0000-4000-8000-000000000031'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000031-0000-4000-8000-000000000003'::uuid, 'd1000031-0000-4000-8000-000000000031'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000031-0000-4000-8000-000000000004'::uuid, 'd1000031-0000-4000-8000-000000000031'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 4, 'exterior'),
  ('e1000032-0000-4000-8000-000000000000'::uuid, 'd1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000032-0000-4000-8000-000000000001'::uuid, 'd1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000032-0000-4000-8000-000000000002'::uuid, 'd1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000032-0000-4000-8000-000000000003'::uuid, 'd1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000032-0000-4000-8000-000000000004'::uuid, 'd1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000032-0000-4000-8000-000000000005'::uuid, 'd1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 5, 'exterior'),
  ('e1000033-0000-4000-8000-000000000000'::uuid, 'd1000033-0000-4000-8000-000000000033'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000033-0000-4000-8000-000000000001'::uuid, 'd1000033-0000-4000-8000-000000000033'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000033-0000-4000-8000-000000000002'::uuid, 'd1000033-0000-4000-8000-000000000033'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000034-0000-4000-8000-000000000000'::uuid, 'd1000034-0000-4000-8000-000000000034'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000034-0000-4000-8000-000000000001'::uuid, 'd1000034-0000-4000-8000-000000000034'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000034-0000-4000-8000-000000000002'::uuid, 'd1000034-0000-4000-8000-000000000034'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000034-0000-4000-8000-000000000003'::uuid, 'd1000034-0000-4000-8000-000000000034'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000035-0000-4000-8000-000000000000'::uuid, 'd1000035-0000-4000-8000-000000000035'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000035-0000-4000-8000-000000000001'::uuid, 'd1000035-0000-4000-8000-000000000035'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000035-0000-4000-8000-000000000002'::uuid, 'd1000035-0000-4000-8000-000000000035'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000035-0000-4000-8000-000000000003'::uuid, 'd1000035-0000-4000-8000-000000000035'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000035-0000-4000-8000-000000000004'::uuid, 'd1000035-0000-4000-8000-000000000035'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 4, 'exterior'),
  ('e1000036-0000-4000-8000-000000000000'::uuid, 'd1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000036-0000-4000-8000-000000000001'::uuid, 'd1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000036-0000-4000-8000-000000000002'::uuid, 'd1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000036-0000-4000-8000-000000000003'::uuid, 'd1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000036-0000-4000-8000-000000000004'::uuid, 'd1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000036-0000-4000-8000-000000000005'::uuid, 'd1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 5, 'exterior'),
  ('e1000037-0000-4000-8000-000000000000'::uuid, 'd1000037-0000-4000-8000-000000000037'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000037-0000-4000-8000-000000000001'::uuid, 'd1000037-0000-4000-8000-000000000037'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000037-0000-4000-8000-000000000002'::uuid, 'd1000037-0000-4000-8000-000000000037'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000038-0000-4000-8000-000000000000'::uuid, 'd1000038-0000-4000-8000-000000000038'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000038-0000-4000-8000-000000000001'::uuid, 'd1000038-0000-4000-8000-000000000038'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000038-0000-4000-8000-000000000002'::uuid, 'd1000038-0000-4000-8000-000000000038'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000038-0000-4000-8000-000000000003'::uuid, 'd1000038-0000-4000-8000-000000000038'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000039-0000-4000-8000-000000000000'::uuid, 'd1000039-0000-4000-8000-000000000039'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000039-0000-4000-8000-000000000001'::uuid, 'd1000039-0000-4000-8000-000000000039'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000039-0000-4000-8000-000000000002'::uuid, 'd1000039-0000-4000-8000-000000000039'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000039-0000-4000-8000-000000000003'::uuid, 'd1000039-0000-4000-8000-000000000039'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000039-0000-4000-8000-000000000004'::uuid, 'd1000039-0000-4000-8000-000000000039'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 4, 'exterior'),
  ('e1000040-0000-4000-8000-000000000000'::uuid, 'd1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000040-0000-4000-8000-000000000001'::uuid, 'd1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000040-0000-4000-8000-000000000002'::uuid, 'd1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000040-0000-4000-8000-000000000003'::uuid, 'd1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000040-0000-4000-8000-000000000004'::uuid, 'd1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000040-0000-4000-8000-000000000005'::uuid, 'd1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 5, 'exterior'),
  ('e1000201-0000-4000-8000-000000000000'::uuid, 'd1000201-0000-4000-8000-000000000201'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000201-0000-4000-8000-000000000001'::uuid, 'd1000201-0000-4000-8000-000000000201'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000201-0000-4000-8000-000000000002'::uuid, 'd1000201-0000-4000-8000-000000000201'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000202-0000-4000-8000-000000000000'::uuid, 'd1000202-0000-4000-8000-000000000202'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000202-0000-4000-8000-000000000001'::uuid, 'd1000202-0000-4000-8000-000000000202'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000202-0000-4000-8000-000000000002'::uuid, 'd1000202-0000-4000-8000-000000000202'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000202-0000-4000-8000-000000000003'::uuid, 'd1000202-0000-4000-8000-000000000202'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000203-0000-4000-8000-000000000000'::uuid, 'd1000203-0000-4000-8000-000000000203'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000203-0000-4000-8000-000000000001'::uuid, 'd1000203-0000-4000-8000-000000000203'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000203-0000-4000-8000-000000000002'::uuid, 'd1000203-0000-4000-8000-000000000203'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000203-0000-4000-8000-000000000003'::uuid, 'd1000203-0000-4000-8000-000000000203'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000203-0000-4000-8000-000000000004'::uuid, 'd1000203-0000-4000-8000-000000000203'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 4, 'exterior'),
  ('e1000204-0000-4000-8000-000000000000'::uuid, 'd1000204-0000-4000-8000-000000000204'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000204-0000-4000-8000-000000000001'::uuid, 'd1000204-0000-4000-8000-000000000204'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000204-0000-4000-8000-000000000002'::uuid, 'd1000204-0000-4000-8000-000000000204'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000204-0000-4000-8000-000000000003'::uuid, 'd1000204-0000-4000-8000-000000000204'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000204-0000-4000-8000-000000000004'::uuid, 'd1000204-0000-4000-8000-000000000204'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000204-0000-4000-8000-000000000005'::uuid, 'd1000204-0000-4000-8000-000000000204'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 5, 'exterior'),
  ('e1000205-0000-4000-8000-000000000000'::uuid, 'd1000205-0000-4000-8000-000000000205'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000205-0000-4000-8000-000000000001'::uuid, 'd1000205-0000-4000-8000-000000000205'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000205-0000-4000-8000-000000000002'::uuid, 'd1000205-0000-4000-8000-000000000205'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000206-0000-4000-8000-000000000000'::uuid, 'd1000206-0000-4000-8000-000000000206'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000206-0000-4000-8000-000000000001'::uuid, 'd1000206-0000-4000-8000-000000000206'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000206-0000-4000-8000-000000000002'::uuid, 'd1000206-0000-4000-8000-000000000206'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000206-0000-4000-8000-000000000003'::uuid, 'd1000206-0000-4000-8000-000000000206'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000207-0000-4000-8000-000000000000'::uuid, 'd1000207-0000-4000-8000-000000000207'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000207-0000-4000-8000-000000000001'::uuid, 'd1000207-0000-4000-8000-000000000207'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000207-0000-4000-8000-000000000002'::uuid, 'd1000207-0000-4000-8000-000000000207'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000207-0000-4000-8000-000000000003'::uuid, 'd1000207-0000-4000-8000-000000000207'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000207-0000-4000-8000-000000000004'::uuid, 'd1000207-0000-4000-8000-000000000207'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 4, 'exterior'),
  ('e1000208-0000-4000-8000-000000000000'::uuid, 'd1000208-0000-4000-8000-000000000208'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000208-0000-4000-8000-000000000001'::uuid, 'd1000208-0000-4000-8000-000000000208'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000208-0000-4000-8000-000000000002'::uuid, 'd1000208-0000-4000-8000-000000000208'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000208-0000-4000-8000-000000000003'::uuid, 'd1000208-0000-4000-8000-000000000208'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000208-0000-4000-8000-000000000004'::uuid, 'd1000208-0000-4000-8000-000000000208'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000208-0000-4000-8000-000000000005'::uuid, 'd1000208-0000-4000-8000-000000000208'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 5, 'exterior'),
  ('e1000209-0000-4000-8000-000000000000'::uuid, 'd1000209-0000-4000-8000-000000000209'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000209-0000-4000-8000-000000000001'::uuid, 'd1000209-0000-4000-8000-000000000209'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000209-0000-4000-8000-000000000002'::uuid, 'd1000209-0000-4000-8000-000000000209'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000210-0000-4000-8000-000000000000'::uuid, 'd1000210-0000-4000-8000-000000000210'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000210-0000-4000-8000-000000000001'::uuid, 'd1000210-0000-4000-8000-000000000210'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000210-0000-4000-8000-000000000002'::uuid, 'd1000210-0000-4000-8000-000000000210'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000210-0000-4000-8000-000000000003'::uuid, 'd1000210-0000-4000-8000-000000000210'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000211-0000-4000-8000-000000000000'::uuid, 'd1000211-0000-4000-8000-000000000211'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000211-0000-4000-8000-000000000001'::uuid, 'd1000211-0000-4000-8000-000000000211'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000211-0000-4000-8000-000000000002'::uuid, 'd1000211-0000-4000-8000-000000000211'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000211-0000-4000-8000-000000000003'::uuid, 'd1000211-0000-4000-8000-000000000211'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000211-0000-4000-8000-000000000004'::uuid, 'd1000211-0000-4000-8000-000000000211'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 4, 'exterior'),
  ('e1000212-0000-4000-8000-000000000000'::uuid, 'd1000212-0000-4000-8000-000000000212'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000212-0000-4000-8000-000000000001'::uuid, 'd1000212-0000-4000-8000-000000000212'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000212-0000-4000-8000-000000000002'::uuid, 'd1000212-0000-4000-8000-000000000212'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000212-0000-4000-8000-000000000003'::uuid, 'd1000212-0000-4000-8000-000000000212'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000212-0000-4000-8000-000000000004'::uuid, 'd1000212-0000-4000-8000-000000000212'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000212-0000-4000-8000-000000000005'::uuid, 'd1000212-0000-4000-8000-000000000212'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 5, 'exterior'),
  ('e1000213-0000-4000-8000-000000000000'::uuid, 'd1000213-0000-4000-8000-000000000213'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000213-0000-4000-8000-000000000001'::uuid, 'd1000213-0000-4000-8000-000000000213'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000213-0000-4000-8000-000000000002'::uuid, 'd1000213-0000-4000-8000-000000000213'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000214-0000-4000-8000-000000000000'::uuid, 'd1000214-0000-4000-8000-000000000214'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000214-0000-4000-8000-000000000001'::uuid, 'd1000214-0000-4000-8000-000000000214'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000214-0000-4000-8000-000000000002'::uuid, 'd1000214-0000-4000-8000-000000000214'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000214-0000-4000-8000-000000000003'::uuid, 'd1000214-0000-4000-8000-000000000214'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000215-0000-4000-8000-000000000000'::uuid, 'd1000215-0000-4000-8000-000000000215'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000215-0000-4000-8000-000000000001'::uuid, 'd1000215-0000-4000-8000-000000000215'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000215-0000-4000-8000-000000000002'::uuid, 'd1000215-0000-4000-8000-000000000215'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000215-0000-4000-8000-000000000003'::uuid, 'd1000215-0000-4000-8000-000000000215'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000215-0000-4000-8000-000000000004'::uuid, 'd1000215-0000-4000-8000-000000000215'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 4, 'exterior'),
  ('e1000216-0000-4000-8000-000000000000'::uuid, 'd1000216-0000-4000-8000-000000000216'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000216-0000-4000-8000-000000000001'::uuid, 'd1000216-0000-4000-8000-000000000216'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000216-0000-4000-8000-000000000002'::uuid, 'd1000216-0000-4000-8000-000000000216'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000216-0000-4000-8000-000000000003'::uuid, 'd1000216-0000-4000-8000-000000000216'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000216-0000-4000-8000-000000000004'::uuid, 'd1000216-0000-4000-8000-000000000216'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000216-0000-4000-8000-000000000005'::uuid, 'd1000216-0000-4000-8000-000000000216'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 5, 'exterior'),
  ('e1000217-0000-4000-8000-000000000000'::uuid, 'd1000217-0000-4000-8000-000000000217'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000217-0000-4000-8000-000000000001'::uuid, 'd1000217-0000-4000-8000-000000000217'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000217-0000-4000-8000-000000000002'::uuid, 'd1000217-0000-4000-8000-000000000217'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000218-0000-4000-8000-000000000000'::uuid, 'd1000218-0000-4000-8000-000000000218'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 0, 'living'),
  ('e1000218-0000-4000-8000-000000000001'::uuid, 'd1000218-0000-4000-8000-000000000218'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000218-0000-4000-8000-000000000002'::uuid, 'd1000218-0000-4000-8000-000000000218'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000218-0000-4000-8000-000000000003'::uuid, 'd1000218-0000-4000-8000-000000000218'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000219-0000-4000-8000-000000000000'::uuid, 'd1000219-0000-4000-8000-000000000219'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'),
  ('e1000219-0000-4000-8000-000000000001'::uuid, 'd1000219-0000-4000-8000-000000000219'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 1, 'bedroom'),
  ('e1000219-0000-4000-8000-000000000002'::uuid, 'd1000219-0000-4000-8000-000000000219'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000219-0000-4000-8000-000000000003'::uuid, 'd1000219-0000-4000-8000-000000000219'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'),
  ('e1000219-0000-4000-8000-000000000004'::uuid, 'd1000219-0000-4000-8000-000000000219'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 4, 'exterior'),
  ('e1000220-0000-4000-8000-000000000000'::uuid, 'd1000220-0000-4000-8000-000000000220'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 0, 'living'),
  ('e1000220-0000-4000-8000-000000000001'::uuid, 'd1000220-0000-4000-8000-000000000220'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'),
  ('e1000220-0000-4000-8000-000000000002'::uuid, 'd1000220-0000-4000-8000-000000000220'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 2, 'kitchen'),
  ('e1000220-0000-4000-8000-000000000003'::uuid, 'd1000220-0000-4000-8000-000000000220'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom'),
  ('e1000220-0000-4000-8000-000000000004'::uuid, 'd1000220-0000-4000-8000-000000000220'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 4, 'other'),
  ('e1000220-0000-4000-8000-000000000005'::uuid, 'd1000220-0000-4000-8000-000000000220'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 5, 'exterior'),
  ('e1000221-0000-4000-8000-000000000000'::uuid, 'd1000221-0000-4000-8000-000000000221'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e1000221-0000-4000-8000-000000000001'::uuid, 'd1000221-0000-4000-8000-000000000221'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e1000221-0000-4000-8000-000000000002'::uuid, 'd1000221-0000-4000-8000-000000000221'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'),
  ('e1000222-0000-4000-8000-000000000000'::uuid, 'd1000222-0000-4000-8000-000000000222'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 0, 'living'),
  ('e1000222-0000-4000-8000-000000000001'::uuid, 'd1000222-0000-4000-8000-000000000222'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 1, 'bedroom'),
  ('e1000222-0000-4000-8000-000000000002'::uuid, 'd1000222-0000-4000-8000-000000000222'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 2, 'kitchen'),
  ('e1000222-0000-4000-8000-000000000003'::uuid, 'd1000222-0000-4000-8000-000000000222'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 3, 'bathroom')
) as seed (id, property_id, storage_path, sort_order, photo_type)
where exists (
  select 1 from public.properties p where p.id = seed.property_id
)
on conflict (id) do update
set property_id = excluded.property_id,
    storage_path = excluded.storage_path,
    sort_order = excluded.sort_order,
    photo_type = excluded.photo_type,
    moderation_status = excluded.moderation_status;

delete from public.property_photos
where property_id = '22222222-2222-4222-8222-222222222201'::uuid
  and id not in ('e2222222-0000-4000-8000-000000000000'::uuid, 'e2222222-0000-4000-8000-000000000001'::uuid, 'e2222222-0000-4000-8000-000000000002'::uuid);

insert into public.property_photos (
  id, property_id, storage_path, sort_order, photo_type, moderation_status
)
select
  id, property_id, storage_path, sort_order,
  photo_type::public.photo_type,
  'approved'::public.moderation_status
from (
  values
  ('e2222222-0000-4000-8000-000000000000'::uuid, '22222222-2222-4222-8222-222222222201'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'),
  ('e2222222-0000-4000-8000-000000000001'::uuid, '22222222-2222-4222-8222-222222222201'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'),
  ('e2222222-0000-4000-8000-000000000002'::uuid, '22222222-2222-4222-8222-222222222201'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen')
) as seed (id, property_id, storage_path, sort_order, photo_type)
where exists (
  select 1 from public.properties p where p.id = seed.property_id
)
on conflict (id) do update
set storage_path = excluded.storage_path,
    sort_order = excluded.sort_order,
    photo_type = excluded.photo_type,
    moderation_status = excluded.moderation_status;


-- Replace every published seed-host gallery so the first frame is a room
-- and each home has 3 to 6 photos. Exterior frames stay last.
do $homizi_room_photos$
declare
  rec record;
  n int := 0;
  total int;
  i int;
  digest text;
  rooms text[] := array[
    'living_01.webp', 'living_02.webp', 'living_03.webp',
    'living_04.webp', 'living_05.webp'
  ];
  beds text[] := array[
    'bed_01.webp', 'bed_02.webp', 'bed_03.webp', 'bed_04.webp'
  ];
  kitchens text[] := array[
    'kitchen_01.webp', 'kitchen_02.webp', 'kitchen_03.webp'
  ];
  baths text[] := array['bath_01.webp', 'bath_02.webp'];
  extras text[] := array[
    'dining_01.webp', 'workspace_01.webp', 'balcony_01.webp'
  ];
  exteriors text[] := array[
    'exterior_01.webp', 'exterior_02.webp', 'exterior_03.webp'
  ];
  chosen text[];
  chosen_types public.photo_type[];
begin
  for rec in
    select id
    from public.properties
    where host_user_id = 'c0ffee00-0000-4000-8000-000000000001'::uuid
      and status = 'published'
    order by id
  loop
    delete from public.property_photos where property_id = rec.id;
    total := 3 + (n % 4);
    chosen := array[
      rooms[1 + (n % array_length(rooms, 1))],
      beds[1 + (n % array_length(beds, 1))],
      kitchens[1 + (n % array_length(kitchens, 1))]
    ];
    chosen_types := array['living', 'bedroom', 'kitchen']::public.photo_type[];
    if total >= 4 then
      chosen := chosen || baths[1 + (n % array_length(baths, 1))];
      chosen_types := chosen_types || 'bathroom'::public.photo_type;
    end if;
    if total >= 6 then
      chosen := chosen || extras[1 + (n % array_length(extras, 1))];
      chosen_types := chosen_types || 'other'::public.photo_type;
    end if;
    if total >= 5 then
      chosen := chosen || exteriors[1 + (n % array_length(exteriors, 1))];
      chosen_types := chosen_types || 'exterior'::public.photo_type;
    end if;
    for i in 1..array_length(chosen, 1) loop
      digest := md5(rec.id::text || ':' || i::text);
      insert into public.property_photos (
        id, property_id, storage_path, sort_order, photo_type, moderation_status
      ) values (
        (
          substr(digest, 1, 8) || '-' ||
          substr(digest, 9, 4) || '-' ||
          '4' || substr(digest, 14, 3) || '-' ||
          '8' || substr(digest, 18, 3) || '-' ||
          substr(digest, 21, 12)
        )::uuid,
        rec.id,
        'https://homizi.netlify.app/demo_media/' || chosen[i],
        i - 1,
        chosen_types[i],
        'approved'
      )
      on conflict (id) do update
      set property_id = excluded.property_id,
          storage_path = excluded.storage_path,
          sort_order = excluded.sort_order,
          photo_type = excluded.photo_type,
          moderation_status = excluded.moderation_status;
    end loop;
    n := n + 1;
  end loop;
end
$homizi_room_photos$;

do $homizi_filter_coverage$
declare
  missing text := '';
  n int;
  bad_photos int;
  bad_primary int;
begin
  select count(*) into n
  from public.properties
  where id in (
    select id from public.properties
    where title in (
      'PG bed near Malleswaram 18th Cross',
      'Villa on SG Highway',
      '4 BHK apartment in Vastrapur'
    )
  )
    and status = 'published';
  if n <> 3 then
    missing := missing || 'coverage listings missing; ';
  end if;

  if (select count(*) from public.properties
      where host_user_id = 'c0ffee00-0000-4000-8000-000000000001'::uuid
        and status = 'published'
        and id >= 'd1000201-0000-4000-8000-000000000201'::uuid
        and id <= 'd1000222-0000-4000-8000-000000000222'::uuid) <> 22 then
    missing := missing || 'expected 22 new published listings; ';
  end if;

  -- Cities
  perform 1;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Bengaluru'
  ) then
    missing := missing || 'city Bengaluru; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Mumbai'
  ) then
    missing := missing || 'city Mumbai; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Pune'
  ) then
    missing := missing || 'city Pune; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Delhi NCR'
  ) then
    missing := missing || 'city Delhi NCR; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Hyderabad'
  ) then
    missing := missing || 'city Hyderabad; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Chennai'
  ) then
    missing := missing || 'city Chennai; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Ahmedabad'
  ) then
    missing := missing || 'city Ahmedabad; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Ahmedabad' and locality = 'Satellite'
  ) then
    missing := missing || 'Ahmedabad Satellite; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Ahmedabad' and locality = 'Bodakdev'
  ) then
    missing := missing || 'Ahmedabad Bodakdev; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Ahmedabad' and locality = 'Prahlad Nagar'
  ) then
    missing := missing || 'Ahmedabad Prahlad Nagar; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Ahmedabad' and locality = 'Vastrapur'
  ) then
    missing := missing || 'Ahmedabad Vastrapur; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Ahmedabad' and locality = 'SG Highway'
  ) then
    missing := missing || 'Ahmedabad SG Highway; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Ahmedabad' and locality = 'Thaltej'
  ) then
    missing := missing || 'Ahmedabad Thaltej; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Ahmedabad' and locality = 'Navrangpura'
  ) then
    missing := missing || 'Ahmedabad Navrangpura; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and city = 'Ahmedabad' and locality = 'Bopal'
  ) then
    missing := missing || 'Ahmedabad Bopal; ';
  end if;
  if not exists (
    select 1 from public.properties p
    left join public.property_features f
      on f.property_id = p.id and f.feature_key = 'bedrooms'
    where p.status = 'published'
      and (p.property_type = 'studio' or coalesce(f.value, '0')::int <= 0)
  ) then
    missing := missing || '1RK; ';
  end if;
  if not exists (
    select 1 from public.properties p
    left join public.property_features f
      on f.property_id = p.id and f.feature_key = 'bedrooms'
    where p.status = 'published'
      and coalesce(f.value, '0')::int = 1 and p.property_type in ('apartment', 'independent_house', 'villa')
  ) then
    missing := missing || '1BHK; ';
  end if;
  if not exists (
    select 1 from public.properties p
    left join public.property_features f
      on f.property_id = p.id and f.feature_key = 'bedrooms'
    where p.status = 'published'
      and coalesce(f.value, '0')::int = 2 and p.property_type in ('apartment', 'independent_house', 'villa')
  ) then
    missing := missing || '2BHK; ';
  end if;
  if not exists (
    select 1 from public.properties p
    left join public.property_features f
      on f.property_id = p.id and f.feature_key = 'bedrooms'
    where p.status = 'published'
      and coalesce(f.value, '0')::int >= 3 and p.property_type in ('apartment', 'independent_house', 'villa')
  ) then
    missing := missing || '3BHK; ';
  end if;
  if not exists (
    select 1 from public.properties p
    left join public.property_features f
      on f.property_id = p.id and f.feature_key = 'bedrooms'
    where p.status = 'published'
      and coalesce(f.value, '0')::int >= 4 and p.property_type in ('apartment', 'independent_house', 'villa')
  ) then
    missing := missing || '4BHK+; ';
  end if;
  if not exists (
    select 1 from public.properties p
    left join public.property_features f
      on f.property_id = p.id and f.feature_key = 'bedrooms'
    where p.status = 'published'
      and p.property_type in ('pg', 'shared_room')
  ) then
    missing := missing || 'PG; ';
  end if;
  if not exists (
    select 1 from public.properties p
    left join public.property_features f
      on f.property_id = p.id and f.feature_key = 'bedrooms'
    where p.status = 'published'
      and p.property_type in ('private_room', 'shared_room')
  ) then
    missing := missing || 'flatmate; ';
  end if;
  if not exists (
    select 1 from public.properties p
    left join public.property_features f
      on f.property_id = p.id and f.feature_key = 'bedrooms'
    where p.status = 'published'
      and p.property_type in ('apartment', 'independent_house', 'villa')
  ) then
    missing := missing || 'full house; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and property_type = 'apartment'::public.property_type
  ) then
    missing := missing || 'type apartment; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and property_type = 'independent_house'::public.property_type
  ) then
    missing := missing || 'type independent_house; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and property_type = 'villa'::public.property_type
  ) then
    missing := missing || 'type villa; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and property_type = 'pg'::public.property_type
  ) then
    missing := missing || 'type pg; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and property_type = 'studio'::public.property_type
  ) then
    missing := missing || 'type studio; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and property_type = 'shared_room'::public.property_type
  ) then
    missing := missing || 'type shared_room; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and property_type = 'private_room'::public.property_type
  ) then
    missing := missing || 'type private_room; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and furnishing = 'unfurnished'::public.furnishing
  ) then
    missing := missing || 'furnishing unfurnished; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and furnishing = 'semi_furnished'::public.furnishing
  ) then
    missing := missing || 'furnishing semi_furnished; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and furnishing = 'furnished'::public.furnishing
  ) then
    missing := missing || 'furnishing furnished; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and rent_inr <= 9999
  ) then
    missing := missing || 'budget under 10000; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and rent_inr between 10000 and 14999
  ) then
    missing := missing || 'budget 10000-14999; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and rent_inr between 15000 and 19999
  ) then
    missing := missing || 'budget 15000-19999; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and rent_inr between 20000 and 29999
  ) then
    missing := missing || 'budget 20000-29999; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and rent_inr between 30000 and 39999
  ) then
    missing := missing || 'budget 30000-39999; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and rent_inr between 40000 and 49999
  ) then
    missing := missing || 'budget 40000-49999; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and rent_inr between 50000 and 59999
  ) then
    missing := missing || 'budget 50000-59999; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and rent_inr >= 60000
  ) then
    missing := missing || 'budget 60000 plus; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
      and (preferred_tenants @> array['family']::text[] or preferred_tenants @> array['any']::text[])
  ) then
    missing := missing || 'tenant family; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
      and (preferred_tenants @> array['bachelors']::text[] or preferred_tenants @> array['any']::text[])
  ) then
    missing := missing || 'tenant bachelors; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
      and (preferred_tenants @> array['female']::text[] or preferred_tenants @> array['any']::text[])
  ) then
    missing := missing || 'tenant female; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
      and (preferred_tenants @> array['any']::text[] or preferred_tenants @> array['any']::text[])
  ) then
    missing := missing || 'tenant any; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and parking
  ) then
    missing := missing || 'parking; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and pets_allowed
  ) then
    missing := missing || 'pets; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and non_veg_allowed
  ) then
    missing := missing || 'non-veg; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and gated_society
  ) then
    missing := missing || 'gated society; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and area_sqft between 50 and 499
  ) then
    missing := missing || 'area 50-499; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and area_sqft between 500 and 799
  ) then
    missing := missing || 'area 500-799; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and area_sqft between 800 and 1199
  ) then
    missing := missing || 'area 800-1199; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and area_sqft between 1200 and 1799
  ) then
    missing := missing || 'area 1200-1799; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and area_sqft between 1800 and 2499
  ) then
    missing := missing || 'area 1800-2499; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and area_sqft between 2500 and 4000
  ) then
    missing := missing || 'area 2500-4000; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and floor_no between 0 and 0
  ) then
    missing := missing || 'floor 0-0; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and floor_no between 1 and 4
  ) then
    missing := missing || 'floor 1-4; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and floor_no between 5 and 9
  ) then
    missing := missing || 'floor 5-9; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and floor_no between 10 and 15
  ) then
    missing := missing || 'floor 10-15; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published' and floor_no between 16 and 20
  ) then
    missing := missing || 'floor 16-20; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
      and (available_from is null or available_from <= current_date)
  ) then
    missing := missing || 'move-in immediate; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
      and available_from is not null
      and available_from <= current_date + 30
      and available_from > current_date
  ) then
    missing := missing || 'move-in within 30 days; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
      and available_from > current_date + 90
  ) then
    missing := missing || 'move-in later; ';
  end if;
  if not exists (
    select 1
    from public.properties p
    join public.profiles h on h.user_id = p.host_user_id
    where p.status = 'published'
      and h.verification_status = 'mock_verified'
  ) then
    missing := missing || 'verified hosts; ';
  end if;
  if not exists (
    select 1
    from public.properties p
    join public.property_photos ph on ph.property_id = p.id
    where p.status = 'published'
      and ph.moderation_status <> 'rejected'
  ) then
    missing := missing || 'photos only; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
    order by published_at desc nulls last
    limit 1
  ) then
    missing := missing || 'sort newest; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
    order by rent_inr asc
    limit 1
  ) then
    missing := missing || 'sort rent low; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
    order by rent_inr desc
    limit 1
  ) then
    missing := missing || 'sort rent high; ';
  end if;
  if not exists (
    select 1 from public.properties
    where status = 'published'
    order by available_from asc nulls first
    limit 1
  ) then
    missing := missing || 'sort move-in; ';
  end if;
  if not exists (
    select 1 from public.properties p
    where p.status = 'published'
    order by (
      select count(*) from public.listing_views v
      where v.property_id = p.id
    ) desc, p.published_at desc nulls last
    limit 1
  ) then
    missing := missing || 'sort most viewed; ';
  end if;

  select count(*) into bad_photos
  from (
    select p.id
    from public.properties p
    join public.property_photos ph on ph.property_id = p.id
    where p.host_user_id = 'c0ffee00-0000-4000-8000-000000000001'::uuid
      and p.status = 'published'
      and ph.moderation_status <> 'rejected'
      and ph.storage_path like 'https://homizi.netlify.app/demo_media/%'
    group by p.id
    having count(*) < 3 or count(*) > 6
  ) gaps;
  if bad_photos <> 0 then
    missing := missing || 'seed photo count; ';
  end if;

  select count(*) into bad_primary
  from public.properties p
  join public.property_photos ph on ph.property_id = p.id and ph.sort_order = 0
  where p.host_user_id = 'c0ffee00-0000-4000-8000-000000000001'::uuid
    and p.status = 'published'
    and ph.photo_type not in ('living', 'bedroom', 'kitchen', 'bathroom');
  if bad_primary <> 0 then
    missing := missing || 'primary photo is not a room; ';
  end if;

  if not exists (
    select 1 from public.profiles
    where user_id = 'c0ffee00-0000-4000-8000-000000000001'::uuid
      and avatar_path like 'https://homizi.netlify.app/demo_media/avatar_%'
  ) then
    missing := missing || 'host avatar; ';
  end if;
  if not exists (
    select 1 from public.profiles
    where user_id = 'c0ffee00-0000-4000-8000-000000000002'::uuid
      and avatar_path like 'https://homizi.netlify.app/demo_media/avatar_%'
  ) then
    missing := missing || 'tenant avatar; ';
  end if;

  if missing <> '' then
    raise exception 'filter coverage gaps: %', missing;
  end if;
end
$homizi_filter_coverage$;
