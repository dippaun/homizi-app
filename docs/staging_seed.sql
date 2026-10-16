-- Staging catalog for the SQL editor. Run this after docs/staging_apply.sql.
-- Safe to run again. It refreshes these 40 rows and leaves every other listing alone.
-- The seed host password is generated in the database and is not written here.
-- Do not sign in as this host. Public property rows store a locality and a city only.

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

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing,
  rent_inr, deposit_inr, brokerage_inr, maintenance_inr, status,
  occupancy_max, available_from, published_at, address_visibility
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
  0,
  maintenance_inr,
  'published'::public.listing_status,
  occupancy_max,
  available_from,
  published_at,
  'locality_only'::public.address_visibility
from (
  values
  ('d1000001-0000-4000-8000-000000000001'::uuid, 'Sunlit 2BHK in Koramangala', 'Koramangala', 'Bengaluru', 'apartment'::public.property_type, 'furnished'::public.furnishing, 22000, 80000, 1100, 3, date '2026-11-01', timestamptz '2026-10-01 09:00:00+00' + interval '1 hours'),
  ('d1000002-0000-4000-8000-000000000002'::uuid, '2 BHK near HSR Layout BDA', 'HSR Layout', 'Bengaluru', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 18500, 55000, 900, 3, date '2026-11-02', timestamptz '2026-10-01 09:00:00+00' + interval '2 hours'),
  ('d1000003-0000-4000-8000-000000000003'::uuid, 'Studio near Indiranagar metro', 'Indiranagar', 'Bengaluru', 'studio'::public.property_type, 'furnished'::public.furnishing, 28000, 56000, 1400, 1, date '2026-11-03', timestamptz '2026-10-01 09:00:00+00' + interval '3 hours'),
  ('d1000004-0000-4000-8000-000000000004'::uuid, 'Private room in Baner', 'Baner', 'Pune', 'private_room'::public.property_type, 'semi_furnished'::public.furnishing, 14000, 28000, 700, 1, date '2026-11-04', timestamptz '2026-10-01 09:00:00+00' + interval '4 hours'),
  ('d1000005-0000-4000-8000-000000000005'::uuid, 'Furnished 3 BHK in Kharadi', 'Kharadi', 'Pune', 'apartment'::public.property_type, 'furnished'::public.furnishing, 32000, 96000, 1600, 4, date '2026-11-05', timestamptz '2026-10-01 09:00:00+00' + interval '5 hours'),
  ('d1000006-0000-4000-8000-000000000006'::uuid, 'Shared room in Kothrud', 'Kothrud', 'Pune', 'shared_room'::public.property_type, 'unfurnished'::public.furnishing, 9000, 18000, 500, 2, date '2026-11-06', timestamptz '2026-10-01 09:00:00+00' + interval '6 hours'),
  ('d1000007-0000-4000-8000-000000000007'::uuid, '1 BHK in Andheri West', 'Andheri West', 'Mumbai', 'apartment'::public.property_type, 'furnished'::public.furnishing, 28500, 100000, 1400, 2, date '2026-11-07', timestamptz '2026-10-01 09:00:00+00' + interval '7 hours'),
  ('d1000008-0000-4000-8000-000000000008'::uuid, '3 BHK with a Powai view', 'Powai', 'Mumbai', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 54000, 200000, 2700, 4, date '2026-11-08', timestamptz '2026-10-01 09:00:00+00' + interval '8 hours'),
  ('d1000009-0000-4000-8000-000000000009'::uuid, '2 BHK in Gachibowli', 'Gachibowli', 'Hyderabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 24000, 72000, 1200, 3, date '2026-11-09', timestamptz '2026-10-01 09:00:00+00' + interval '9 hours'),
  ('d1000010-0000-4000-8000-000000000010'::uuid, '3 BHK in Gurugram', 'Gurugram', 'Delhi NCR', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 42000, 126000, 2100, 4, date '2026-11-10', timestamptz '2026-10-01 09:00:00+00' + interval '10 hours'),
  ('d1000011-0000-4000-8000-000000000011'::uuid, 'Furnished 2BHK in Whitefield', 'Whitefield', 'Bengaluru', 'apartment'::public.property_type, 'furnished'::public.furnishing, 26000, 78000, 1300, 3, date '2026-11-11', timestamptz '2026-10-01 09:00:00+00' + interval '11 hours'),
  ('d1000012-0000-4000-8000-000000000012'::uuid, '3 BHK near Jayanagar 4th Block', 'Jayanagar', 'Bengaluru', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 35000, 105000, 1700, 4, date '2026-11-12', timestamptz '2026-10-01 09:00:00+00' + interval '12 hours'),
  ('d1000013-0000-4000-8000-000000000013'::uuid, 'Private room in Bellandur', 'Bellandur', 'Bengaluru', 'private_room'::public.property_type, 'semi_furnished'::public.furnishing, 16500, 33000, 800, 1, date '2026-11-13', timestamptz '2026-10-01 09:00:00+00' + interval '13 hours'),
  ('d1000014-0000-4000-8000-000000000014'::uuid, '1 BHK in Marathahalli', 'Marathahalli', 'Bengaluru', 'apartment'::public.property_type, 'furnished'::public.furnishing, 18000, 54000, 900, 2, date '2026-11-14', timestamptz '2026-10-01 09:00:00+00' + interval '14 hours'),
  ('d1000015-0000-4000-8000-000000000015'::uuid, 'Unfurnished 2 BHK in JP Nagar', 'JP Nagar', 'Bengaluru', 'apartment'::public.property_type, 'unfurnished'::public.furnishing, 17000, 51000, 800, 3, date '2026-11-15', timestamptz '2026-10-01 09:00:00+00' + interval '15 hours'),
  ('d1000016-0000-4000-8000-000000000016'::uuid, 'Studio near Hebbal', 'Hebbal', 'Bengaluru', 'studio'::public.property_type, 'furnished'::public.furnishing, 21000, 42000, 1000, 1, date '2026-11-16', timestamptz '2026-10-01 09:00:00+00' + interval '16 hours'),
  ('d1000017-0000-4000-8000-000000000017'::uuid, 'Shared room in BTM Layout', 'BTM Layout', 'Bengaluru', 'shared_room'::public.property_type, 'unfurnished'::public.furnishing, 8500, 17000, 500, 2, date '2026-11-17', timestamptz '2026-10-01 09:00:00+00' + interval '17 hours'),
  ('d1000018-0000-4000-8000-000000000018'::uuid, '2 BHK in Electronic City', 'Electronic City', 'Bengaluru', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 15500, 45000, 700, 3, date '2026-11-18', timestamptz '2026-10-01 09:00:00+00' + interval '18 hours'),
  ('d1000019-0000-4000-8000-000000000019'::uuid, 'Furnished 2 BHK in Viman Nagar', 'Viman Nagar', 'Pune', 'apartment'::public.property_type, 'furnished'::public.furnishing, 24500, 70000, 1200, 3, date '2026-11-19', timestamptz '2026-10-01 09:00:00+00' + interval '19 hours'),
  ('d1000020-0000-4000-8000-000000000020'::uuid, '1 BHK in Wakad', 'Wakad', 'Pune', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 16000, 32000, 800, 2, date '2026-11-20', timestamptz '2026-10-01 09:00:00+00' + interval '20 hours'),
  ('d1000021-0000-4000-8000-000000000021'::uuid, 'Private room in Hinjewadi', 'Hinjewadi', 'Pune', 'private_room'::public.property_type, 'furnished'::public.furnishing, 12500, 25000, 600, 1, date '2026-11-21', timestamptz '2026-10-01 09:00:00+00' + interval '21 hours'),
  ('d1000022-0000-4000-8000-000000000022'::uuid, '3 BHK in Koregaon Park', 'Koregaon Park', 'Pune', 'apartment'::public.property_type, 'furnished'::public.furnishing, 45000, 135000, 2200, 4, date '2026-11-22', timestamptz '2026-10-01 09:00:00+00' + interval '22 hours'),
  ('d1000023-0000-4000-8000-000000000023'::uuid, 'Semi-furnished 2 BHK in Aundh', 'Aundh', 'Pune', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 20000, 60000, 1000, 3, date '2026-11-23', timestamptz '2026-10-01 09:00:00+00' + interval '23 hours'),
  ('d1000024-0000-4000-8000-000000000024'::uuid, 'Private room in Kothrud', 'Kothrud', 'Pune', 'private_room'::public.property_type, 'semi_furnished'::public.furnishing, 11000, 22000, 500, 1, date '2026-11-24', timestamptz '2026-10-01 09:00:00+00' + interval '24 hours'),
  ('d1000025-0000-4000-8000-000000000025'::uuid, '2 BHK in Bandra West', 'Bandra West', 'Mumbai', 'apartment'::public.property_type, 'furnished'::public.furnishing, 65000, 200000, 3200, 3, date '2026-11-25', timestamptz '2026-10-01 09:00:00+00' + interval '25 hours'),
  ('d1000026-0000-4000-8000-000000000026'::uuid, '1 BHK in Goregaon East', 'Goregaon East', 'Mumbai', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 24000, 72000, 1200, 2, date '2026-11-26', timestamptz '2026-10-01 09:00:00+00' + interval '26 hours'),
  ('d1000027-0000-4000-8000-000000000027'::uuid, 'Unfurnished 2 BHK in Chembur', 'Chembur', 'Mumbai', 'apartment'::public.property_type, 'unfurnished'::public.furnishing, 28000, 84000, 1400, 3, date '2026-11-27', timestamptz '2026-10-01 09:00:00+00' + interval '27 hours'),
  ('d1000028-0000-4000-8000-000000000028'::uuid, '2 BHK in Thane', 'Thane', 'Mumbai', 'apartment'::public.property_type, 'furnished'::public.furnishing, 22000, 66000, 1100, 3, date '2026-11-28', timestamptz '2026-10-01 09:00:00+00' + interval '28 hours'),
  ('d1000029-0000-4000-8000-000000000029'::uuid, 'Private room in Mulund', 'Mulund', 'Mumbai', 'private_room'::public.property_type, 'semi_furnished'::public.furnishing, 15000, 30000, 700, 1, date '2026-11-01', timestamptz '2026-10-01 09:00:00+00' + interval '29 hours'),
  ('d1000030-0000-4000-8000-000000000030'::uuid, 'Furnished 1 BHK in Malad West', 'Malad West', 'Mumbai', 'apartment'::public.property_type, 'furnished'::public.furnishing, 23000, 69000, 1100, 2, date '2026-11-02', timestamptz '2026-10-01 09:00:00+00' + interval '30 hours'),
  ('d1000031-0000-4000-8000-000000000031'::uuid, '2 BHK in Madhapur', 'Madhapur', 'Hyderabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 28000, 84000, 1400, 3, date '2026-11-03', timestamptz '2026-10-01 09:00:00+00' + interval '31 hours'),
  ('d1000032-0000-4000-8000-000000000032'::uuid, '3 BHK in Kondapur', 'Kondapur', 'Hyderabad', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 36000, 108000, 1800, 4, date '2026-11-04', timestamptz '2026-10-01 09:00:00+00' + interval '32 hours'),
  ('d1000033-0000-4000-8000-000000000033'::uuid, 'Studio in Hitech City', 'Hitech City', 'Hyderabad', 'studio'::public.property_type, 'furnished'::public.furnishing, 19000, 38000, 900, 1, date '2026-11-05', timestamptz '2026-10-01 09:00:00+00' + interval '33 hours'),
  ('d1000034-0000-4000-8000-000000000034'::uuid, '3 BHK in Banjara Hills', 'Banjara Hills', 'Hyderabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 48000, 144000, 2400, 4, date '2026-11-06', timestamptz '2026-10-01 09:00:00+00' + interval '34 hours'),
  ('d1000035-0000-4000-8000-000000000035'::uuid, 'Unfurnished 2 BHK in Kukatpally', 'Kukatpally', 'Hyderabad', 'apartment'::public.property_type, 'unfurnished'::public.furnishing, 16000, 48000, 800, 3, date '2026-11-07', timestamptz '2026-10-01 09:00:00+00' + interval '35 hours'),
  ('d1000036-0000-4000-8000-000000000036'::uuid, '2 BHK in Noida Sector 62', 'Noida Sector 62', 'Delhi NCR', 'apartment'::public.property_type, 'furnished'::public.furnishing, 25000, 75000, 1200, 3, date '2026-11-08', timestamptz '2026-10-01 09:00:00+00' + interval '36 hours'),
  ('d1000037-0000-4000-8000-000000000037'::uuid, '3 BHK in Dwarka', 'Dwarka', 'Delhi NCR', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 32000, 96000, 1600, 4, date '2026-11-09', timestamptz '2026-10-01 09:00:00+00' + interval '37 hours'),
  ('d1000038-0000-4000-8000-000000000038'::uuid, 'Furnished 2 BHK in Saket', 'Saket', 'Delhi NCR', 'apartment'::public.property_type, 'furnished'::public.furnishing, 38000, 114000, 1900, 3, date '2026-11-10', timestamptz '2026-10-01 09:00:00+00' + interval '38 hours'),
  ('d1000039-0000-4000-8000-000000000039'::uuid, '1 BHK in Greater Noida', 'Greater Noida', 'Delhi NCR', 'apartment'::public.property_type, 'unfurnished'::public.furnishing, 14000, 28000, 700, 2, date '2026-11-11', timestamptz '2026-10-01 09:00:00+00' + interval '39 hours'),
  ('d1000040-0000-4000-8000-000000000040'::uuid, 'Private room in Indirapuram', 'Indirapuram', 'Delhi NCR', 'private_room'::public.property_type, 'semi_furnished'::public.furnishing, 13000, 26000, 600, 1, date '2026-11-12', timestamptz '2026-10-01 09:00:00+00' + interval '40 hours')
) as seed (
  id, title, locality, city, property_type, furnishing,
  rent_inr, deposit_inr, maintenance_inr, occupancy_max,
  available_from, published_at
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
    brokerage_inr = 0,
    maintenance_inr = excluded.maintenance_inr,
    status = 'published',
    occupancy_max = excluded.occupancy_max,
    available_from = excluded.available_from,
    published_at = excluded.published_at,
    address_visibility = 'locality_only';

insert into public.property_features (property_id, feature_key, value)
select property_id, feature_key, value
from (
  values
  ('d1000001-0000-4000-8000-000000000001'::uuid, 'bedrooms', '2'),
  ('d1000002-0000-4000-8000-000000000002'::uuid, 'bedrooms', '2'),
  ('d1000003-0000-4000-8000-000000000003'::uuid, 'bedrooms', '0'),
  ('d1000004-0000-4000-8000-000000000004'::uuid, 'bedrooms', '1'),
  ('d1000005-0000-4000-8000-000000000005'::uuid, 'bedrooms', '3'),
  ('d1000006-0000-4000-8000-000000000006'::uuid, 'bedrooms', '1'),
  ('d1000007-0000-4000-8000-000000000007'::uuid, 'bedrooms', '1'),
  ('d1000008-0000-4000-8000-000000000008'::uuid, 'bedrooms', '3'),
  ('d1000009-0000-4000-8000-000000000009'::uuid, 'bedrooms', '2'),
  ('d1000010-0000-4000-8000-000000000010'::uuid, 'bedrooms', '3'),
  ('d1000011-0000-4000-8000-000000000011'::uuid, 'bedrooms', '2'),
  ('d1000012-0000-4000-8000-000000000012'::uuid, 'bedrooms', '3'),
  ('d1000013-0000-4000-8000-000000000013'::uuid, 'bedrooms', '1'),
  ('d1000014-0000-4000-8000-000000000014'::uuid, 'bedrooms', '1'),
  ('d1000015-0000-4000-8000-000000000015'::uuid, 'bedrooms', '2'),
  ('d1000016-0000-4000-8000-000000000016'::uuid, 'bedrooms', '0'),
  ('d1000017-0000-4000-8000-000000000017'::uuid, 'bedrooms', '1'),
  ('d1000018-0000-4000-8000-000000000018'::uuid, 'bedrooms', '2'),
  ('d1000019-0000-4000-8000-000000000019'::uuid, 'bedrooms', '2'),
  ('d1000020-0000-4000-8000-000000000020'::uuid, 'bedrooms', '1'),
  ('d1000021-0000-4000-8000-000000000021'::uuid, 'bedrooms', '1'),
  ('d1000022-0000-4000-8000-000000000022'::uuid, 'bedrooms', '3'),
  ('d1000023-0000-4000-8000-000000000023'::uuid, 'bedrooms', '2'),
  ('d1000024-0000-4000-8000-000000000024'::uuid, 'bedrooms', '1'),
  ('d1000025-0000-4000-8000-000000000025'::uuid, 'bedrooms', '2'),
  ('d1000026-0000-4000-8000-000000000026'::uuid, 'bedrooms', '1'),
  ('d1000027-0000-4000-8000-000000000027'::uuid, 'bedrooms', '2'),
  ('d1000028-0000-4000-8000-000000000028'::uuid, 'bedrooms', '2'),
  ('d1000029-0000-4000-8000-000000000029'::uuid, 'bedrooms', '1'),
  ('d1000030-0000-4000-8000-000000000030'::uuid, 'bedrooms', '1'),
  ('d1000031-0000-4000-8000-000000000031'::uuid, 'bedrooms', '2'),
  ('d1000032-0000-4000-8000-000000000032'::uuid, 'bedrooms', '3'),
  ('d1000033-0000-4000-8000-000000000033'::uuid, 'bedrooms', '0'),
  ('d1000034-0000-4000-8000-000000000034'::uuid, 'bedrooms', '3'),
  ('d1000035-0000-4000-8000-000000000035'::uuid, 'bedrooms', '2'),
  ('d1000036-0000-4000-8000-000000000036'::uuid, 'bedrooms', '2'),
  ('d1000037-0000-4000-8000-000000000037'::uuid, 'bedrooms', '3'),
  ('d1000038-0000-4000-8000-000000000038'::uuid, 'bedrooms', '2'),
  ('d1000039-0000-4000-8000-000000000039'::uuid, 'bedrooms', '1'),
  ('d1000040-0000-4000-8000-000000000040'::uuid, 'bedrooms', '1')
) as seed (property_id, feature_key, value)
on conflict (property_id, feature_key) do update
set value = excluded.value;

do $homizi_seed_check$
declare
  n int;
  phones int;
begin
  select count(*) into n
  from public.properties
  where host_user_id = 'c0ffee00-0000-4000-8000-000000000001'
    and status = 'published';
  if n <> 40 then
    raise exception 'staging seed expected 40 published listings, found %', n;
  end if;
  select count(*) into phones
  from public.properties
  where host_user_id = 'c0ffee00-0000-4000-8000-000000000001'
    and (
      title ~ '[0-9]{10}'
      or locality ~ '@'
      or city ~ '@'
    );
  if phones <> 0 then
    raise exception 'staging seed wrote contact-like text onto a public listing';
  end if;
end
$homizi_seed_check$;
