-- HOMIZI slice E for a project that already ran docs/staging_seed.sql
-- and docs/staging_apply_D_1017b.sql.
-- Paste this whole file into the dashboard SQL editor. Running it again is safe.
--
-- It applies 20261017190000_avatars_swipe.sql (avatars, swipe undo,
-- interested tenants, chip counts, and Ahmedabad locality rows) and
-- 20261017190100_ahmedabad_coverage_seed.sql, then checks every filter.
-- Seed photos are public URLs. No phone is written on a listing.
-- Seed contact emails live only in private_contacts.

-- Avatars, swipe undo, host view of interested tenants, and chip counts.
-- Age range is a voluntary display string. Scoring does not read it.
-- No phone, email, or document number is added.

alter table public.profiles
  add column if not exists age_range text;

alter table public.profiles drop constraint if exists profiles_age_range;
alter table public.profiles
  add constraint profiles_age_range check (
    age_range is null
    or age_range in ('18-24', '25-30', '31-35', '36-45', '45+')
  );

comment on column public.profiles.age_range is
  'Coarse range the person chose to show. Not a date of birth and not a score input.';

grant update (age_range) on public.profiles to authenticated;

create or replace function public.saved_search_new_count(p_search_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_row public.saved_searches;
  v_filters jsonb;
  v_city text;
  v_locality text;
  v_count integer;
begin
  if v_user is null or p_search_id is null then
    return 0;
  end if;
  select * into v_row
  from public.saved_searches
  where id = p_search_id
    and user_id = v_user;
  if v_row.id is null then
    return 0;
  end if;
  v_filters := coalesce(v_row.filters, '{}'::jsonb);
  v_city := nullif(btrim(coalesce(v_row.city, v_filters ->> 'city', '')), '');
  v_locality := nullif(
    btrim(coalesce(v_row.locality, v_filters ->> 'locality', '')),
    ''
  );
  select count(*)::integer into v_count
  from public.properties p
  where p.status = 'published'
    and p.published_at is not null
    and p.published_at > v_row.last_checked_at
    and (v_city is null or p.city = v_city)
    and (v_locality is null or lower(p.locality) = lower(v_locality))
    and (
      v_filters ->> 'budget_min_inr' is null
      or p.rent_inr >= (v_filters ->> 'budget_min_inr')::integer
    )
    and (
      v_filters ->> 'budget_max_inr' is null
      or p.rent_inr <= (v_filters ->> 'budget_max_inr')::integer
    )
    and (
      v_filters ->> 'furnishing' is null
      or p.furnishing::text = v_filters ->> 'furnishing'
    )
    and (
      v_filters ->> 'property_type' is null
      or p.property_type::text = v_filters ->> 'property_type'
    )
    and (
      v_filters ->> 'area_min_sqft' is null
      or (
        p.area_sqft is not null
        and p.area_sqft >= (v_filters ->> 'area_min_sqft')::integer
      )
    )
    and (
      v_filters ->> 'area_max_sqft' is null
      or (
        p.area_sqft is not null
        and p.area_sqft <= (v_filters ->> 'area_max_sqft')::integer
      )
    )
    and (
      v_filters ->> 'preferred_tenant' is null
      or v_filters ->> 'preferred_tenant' = 'any'
      or p.preferred_tenants && array[
        v_filters ->> 'preferred_tenant',
        'any'
      ]::text[]
    )
    and (
      coalesce(v_filters ->> 'parking', '') <> 'true'
      or p.parking
    )
    and (
      coalesce(v_filters ->> 'pets_allowed', '') <> 'true'
      or p.pets_allowed
    )
    and (
      coalesce(v_filters ->> 'non_veg_allowed', '') <> 'true'
      or p.non_veg_allowed
    )
    and (
      coalesce(v_filters ->> 'gated_society', '') <> 'true'
      or p.gated_society
    )
    and (
      v_filters ->> 'floor_min' is null
      or (
        p.floor_no is not null
        and p.floor_no >= (v_filters ->> 'floor_min')::integer
      )
    )
    and (
      v_filters ->> 'floor_max' is null
      or (
        p.floor_no is not null
        and p.floor_no <= (v_filters ->> 'floor_max')::integer
      )
    )
    and (
      coalesce(v_filters ->> 'photos_only', '') <> 'true'
      or exists (
        select 1
        from public.property_photos ph
        where ph.property_id = p.id
          and ph.moderation_status <> 'rejected'
      )
    )
    and (
      coalesce(v_filters ->> 'verified_hosts_only', '') <> 'true'
      or exists (
        select 1
        from public.profiles pr
        where pr.user_id = p.host_user_id
          and pr.verification_status = 'mock_verified'
      )
    )
    and (
      coalesce(v_filters ->> 'query', '') = ''
      or p.title ilike '%' || (v_filters ->> 'query') || '%'
      or p.locality ilike '%' || (v_filters ->> 'query') || '%'
      or p.city ilike '%' || (v_filters ->> 'query') || '%'
    )
    and (
      v_filters ->> 'move_in_by' is null
      or p.available_from is null
      or p.available_from <= (v_filters ->> 'move_in_by')::date
    )
    and (
      v_filters ->> 'bedrooms' is null
      or exists (
        select 1
        from public.property_features f
        where f.property_id = p.id
          and f.feature_key = 'bedrooms'
          and f.value = v_filters ->> 'bedrooms'
      )
    )
    and (
      coalesce(v_filters ->> 'quick_chip', '') = ''
      or (
        v_filters ->> 'quick_chip' = '1rk'
        and (
          p.property_type = 'studio'
          or exists (
            select 1
            from public.property_features f
            where f.property_id = p.id
              and f.feature_key = 'bedrooms'
              and f.value ~ '^[0-9]+$'
              and (f.value)::integer <= 0
          )
        )
      )
      or (
        v_filters ->> 'quick_chip' = 'pg'
        and p.property_type in ('pg', 'shared_room')
      )
      or (
        v_filters ->> 'quick_chip' = 'flatmate'
        and (
          p.property_type in ('private_room', 'shared_room')
          or exists (
            select 1
            from public.host_profiles h
            where h.user_id = p.host_user_id
              and h.host_category = 'flatmate'
          )
        )
      )
      or (
        v_filters ->> 'quick_chip' = 'full_house'
        and p.property_type in ('apartment', 'independent_house', 'villa')
      )
      or (
        v_filters ->> 'quick_chip' in ('1bhk', '2bhk')
        and p.property_type in ('apartment', 'independent_house', 'villa')
        and exists (
          select 1
          from public.property_features f
          where f.property_id = p.id
            and f.feature_key = 'bedrooms'
            and f.value = case v_filters ->> 'quick_chip'
              when '1bhk' then '1'
              else '2'
            end
        )
      )
      or (
        v_filters ->> 'quick_chip' = '3bhk'
        and p.property_type in ('apartment', 'independent_house', 'villa')
        and exists (
          select 1
          from public.property_features f
          where f.property_id = p.id
            and f.feature_key = 'bedrooms'
            and f.value ~ '^[0-9]+$'
            and (f.value)::integer = 3
        )
      )
      or (
        v_filters ->> 'quick_chip' = '4bhk'
        and p.property_type in ('apartment', 'independent_house', 'villa')
        and exists (
          select 1
          from public.property_features f
          where f.property_id = p.id
            and f.feature_key = 'bedrooms'
            and f.value ~ '^[0-9]+$'
            and (f.value)::integer >= 4
        )
      )
    );
  return coalesce(v_count, 0);
end;
$$;

revoke all on function public.saved_search_new_count(uuid) from public, anon;
grant execute on function public.saved_search_new_count(uuid) to authenticated;


create or replace function public.undo_last_interest(
  p_target_type public.interest_target_type,
  p_target_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  delete from public.interests
  where id = (
    select i.id
    from public.interests i
    where i.actor_user_id = v_uid
      and i.target_type = p_target_type
      and i.target_id = p_target_id
      and i.action in ('like', 'pass')
    order by i.updated_at desc
    limit 1
  )
  returning id into v_id;
  if v_id is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'interest_id', v_id);
end;
$$;

revoke all on function public.undo_last_interest(public.interest_target_type, uuid) from public, anon;
grant execute on function public.undo_last_interest(public.interest_target_type, uuid) to authenticated;

create or replace function public.list_property_interests(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_host uuid;
  v_rows jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select host_user_id into v_host
  from public.properties
  where id = p_property_id;
  if v_host is null or v_host <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
    into v_rows
  from (
    select distinct on (i.actor_user_id)
      i.actor_user_id as user_id,
      pr.display_name,
      pr.occupation,
      pr.public_bio,
      pr.avatar_path,
      pr.age_range,
      tp.budget_min_inr,
      tp.budget_max_inr,
      tp.move_in_date,
      tp.lifestyle
    from public.interests i
    join public.profiles pr on pr.user_id = i.actor_user_id
    left join public.tenant_preferences tp on tp.user_id = i.actor_user_id
    where i.target_type = 'property'
      and i.target_id = p_property_id
      and i.action = 'like'
      and i.actor_user_id <> v_uid
    order by i.actor_user_id, i.updated_at desc
  ) t;
  return jsonb_build_object('ok', true, 'tenants', v_rows);
end;
$$;

revoke all on function public.list_property_interests(uuid) from public, anon;
grant execute on function public.list_property_interests(uuid) to authenticated;

comment on function public.list_property_interests(uuid) is
  'Host-only. Returns display fields for people who liked the home. No phone or email.';

do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; avatars bucket skipped';
    return;
  end if;
  insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict (id) do update set public = true;
  execute 'drop policy if exists avatars_public_read on storage.objects';
  execute 'drop policy if exists avatars_insert_own on storage.objects';
  execute 'drop policy if exists avatars_update_own on storage.objects';
  execute 'drop policy if exists avatars_delete_own on storage.objects';
  execute $policy$
    create policy avatars_public_read on storage.objects
    for select to public
    using (bucket_id = 'avatars')
  $policy$;
  execute $policy$
    create policy avatars_insert_own on storage.objects
    for insert to authenticated
    with check (
      bucket_id = 'avatars'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
  execute $policy$
    create policy avatars_update_own on storage.objects
    for update to authenticated
    using (
      bucket_id = 'avatars'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
  execute $policy$
    create policy avatars_delete_own on storage.objects
    for delete to authenticated
    using (
      bucket_id = 'avatars'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
exception
  when others then
    raise notice 'avatars storage policies skipped: %', sqlerrm;
end $$;

-- Ahmedabad locality rows. Listing seeds live in a later slice.
insert into public.localities (city, name, slug, popularity)
values
  ('Ahmedabad', 'Satellite', 'satellite', 96),
  ('Ahmedabad', 'Bodakdev', 'bodakdev', 94),
  ('Ahmedabad', 'Prahlad Nagar', 'prahlad-nagar', 92),
  ('Ahmedabad', 'Vastrapur', 'vastrapur', 90),
  ('Ahmedabad', 'SG Highway', 'sg-highway', 88),
  ('Ahmedabad', 'Thaltej', 'thaltej', 86),
  ('Ahmedabad', 'Navrangpura', 'navrangpura', 84),
  ('Ahmedabad', 'Maninagar', 'maninagar', 82),
  ('Ahmedabad', 'Chandkheda', 'chandkheda', 80),
  ('Ahmedabad', 'Gota', 'gota', 78),
  ('Ahmedabad', 'Bopal', 'bopal', 76),
  ('Ahmedabad', 'South Bopal', 'south-bopal', 74),
  ('Ahmedabad', 'Science City', 'science-city', 72),
  ('Ahmedabad', 'Paldi', 'paldi', 70),
  ('Ahmedabad', 'Naranpura', 'naranpura', 68)
on conflict (city, slug) do update
set name = excluded.name,
    popularity = excluded.popularity;

-- Ahmedabad localities, coverage listings, photos, and seed tenants.
-- Listings are inserted only when the staging host already exists, so a
-- local reset that has no auth user still applies.
-- Safe to run again. The same rows are in docs/staging_apply_E_1017c.sql.


create or replace function public.homizi_seed_auth_user(p_id uuid, p_email text)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  cols text[] := array['id'];
  vals text[] := array[quote_literal(p_id) || '::uuid'];
  colname text;
  token_cols text[] := array[
    'confirmation_token', 'recovery_token', 'email_change', 'email_change_token',
    'email_change_token_new', 'email_change_token_current', 'reauthentication_token',
    'phone_change', 'phone_change_token'
  ];
begin
  if to_regclass('auth.users') is null then
    return;
  end if;
  if exists (select 1 from auth.users where id <> p_id and email = p_email) then
    raise exception 'seed email % already belongs to a different account', p_email;
  end if;
  if exists (select 1 from auth.users where id = p_id) then
    return;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'users' and column_name = 'instance_id'
  ) then
    cols := array_append(cols, 'instance_id');
    vals := array_append(vals, quote_literal('00000000-0000-0000-0000-000000000000') || '::uuid');
  end if;
  cols := array_append(cols, 'email');
  vals := array_append(vals, quote_literal(p_email));
  if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'users' and column_name = 'aud') then
    cols := array_append(cols, 'aud');
    vals := array_append(vals, quote_literal('authenticated'));
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'users' and column_name = 'role') then
    cols := array_append(cols, 'role');
    vals := array_append(vals, quote_literal('authenticated'));
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'users' and column_name = 'encrypted_password') then
    cols := array_append(cols, 'encrypted_password');
    vals := array_append(vals, 'extensions.crypt(gen_random_uuid()::text, extensions.gen_salt(''bf''))');
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_app_meta_data') then
    cols := array_append(cols, 'raw_app_meta_data');
    vals := array_append(vals, quote_literal('{"provider":"email","providers":["email"]}') || '::jsonb');
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'users' and column_name = 'raw_user_meta_data') then
    cols := array_append(cols, 'raw_user_meta_data');
    vals := array_append(vals, quote_literal('{"seed":"staging-catalog"}') || '::jsonb');
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
  if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'users' and column_name = 'is_sso_user') then
    cols := array_append(cols, 'is_sso_user');
    vals := array_append(vals, 'false');
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'users' and column_name = 'is_anonymous') then
    cols := array_append(cols, 'is_anonymous');
    vals := array_append(vals, 'false');
  end if;
  execute format('insert into auth.users (%s) values (%s)', array_to_string(cols, ', '), array_to_string(vals, ', '));
  if to_regclass('auth.identities') is not null
     and not exists (select 1 from auth.identities where user_id = p_id) then
    begin
      execute format(
        'insert into auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at)
         values (gen_random_uuid(), %L::uuid, %L::jsonb, ''email'', %L, now(), now())',
        p_id,
        json_build_object('sub', p_id::text, 'email', p_email)::text,
        p_id::text
      );
    exception
      when others then
        raise notice 'auth.identities insert skipped: %', sqlerrm;
    end;
  end if;
end;
$$;

revoke all on function public.homizi_seed_auth_user(uuid, text) from public, anon, authenticated;


insert into public.localities (city, name, slug, popularity)
values
  ('Ahmedabad', 'Satellite', 'satellite', 96),
  ('Ahmedabad', 'Bodakdev', 'bodakdev', 94),
  ('Ahmedabad', 'Prahlad Nagar', 'prahlad-nagar', 92),
  ('Ahmedabad', 'Vastrapur', 'vastrapur', 90),
  ('Ahmedabad', 'SG Highway', 'sg-highway', 88),
  ('Ahmedabad', 'Thaltej', 'thaltej', 86),
  ('Ahmedabad', 'Navrangpura', 'navrangpura', 84),
  ('Ahmedabad', 'Maninagar', 'maninagar', 82),
  ('Ahmedabad', 'Chandkheda', 'chandkheda', 80),
  ('Ahmedabad', 'Gota', 'gota', 78),
  ('Ahmedabad', 'Bopal', 'bopal', 76),
  ('Ahmedabad', 'South Bopal', 'south-bopal', 74),
  ('Ahmedabad', 'Science City', 'science-city', 72),
  ('Ahmedabad', 'Paldi', 'paldi', 70),
  ('Ahmedabad', 'Naranpura', 'naranpura', 68)
on conflict (city, slug) do update
set name = excluded.name,
    popularity = excluded.popularity;

do $homizi_coverage_seed$
declare
  v_host uuid := 'c0ffee00-0000-4000-8000-000000000001';
  rec record;
begin
  if to_regclass('public.users') is null
     or not exists (
       select 1 from public.users
       where id = 'c0ffee00-0000-4000-8000-000000000001'
     ) then
    raise notice 'staging host missing; coverage listings skipped';
    return;
  end if;
  begin

      perform public.homizi_seed_auth_user(v_host, 'seed-host@example.test');
      insert into public.users (id, status, primary_role)
      values (v_host, 'active', 'host')
      on conflict (id) do update set status = 'active';
      insert into public.profiles (user_id, display_name, occupation, public_bio, verification_status)
      values (
        v_host, 'Asha V.', 'Owner',
        'Staging catalog host. Public listings show locality and city only.',
        'mock_verified'
      )
      on conflict (user_id) do update
      set verification_status = 'mock_verified',
          display_name = excluded.display_name;
      insert into public.host_profiles (user_id, host_category)
      values (v_host, 'owner')
      on conflict (user_id) do update set host_category = excluded.host_category;
      insert into public.private_contacts (user_id, email, phone)
      values (v_host, 'seed-host@example.test', null)
      on conflict (user_id) do update set phone = null;

      for rec in
        select * from (values
          ('b1000001-0000-4000-8000-000000000001'::uuid, 'e1000001-0000-4000-8000-000000000001'::uuid, 'seed-tenant-meera@example.test', 'Meera K.', 'Architect', '25-30', 'https://homizi.netlify.app/demo_media/avatar_01.webp', 'Ahmedabad', 15000, 28000, date '2026-11-15', 'I work from a studio three days a week and like a quiet flat.'),
          ('b1000002-0000-4000-8000-000000000002'::uuid, 'e1000002-0000-4000-8000-000000000002'::uuid, 'seed-tenant-arjun@example.test', 'Arjun P.', 'Software engineer', '25-30', 'https://homizi.netlify.app/demo_media/avatar_02.webp', 'Bengaluru', 18000, 32000, date '2026-12-01', 'Looking for a 2 BHK with a desk corner.'),
          ('b1000003-0000-4000-8000-000000000003'::uuid, 'e1000003-0000-4000-8000-000000000003'::uuid, 'seed-tenant-neha@example.test', 'Neha S.', 'School teacher', '31-35', 'https://homizi.netlify.app/demo_media/avatar_03.webp', 'Pune', 12000, 22000, date '2026-11-20', 'I need a home near a bus route.'),
          ('b1000004-0000-4000-8000-000000000004'::uuid, 'e1000004-0000-4000-8000-000000000004'::uuid, 'seed-tenant-kabir@example.test', 'Kabir R.', 'Chef', '18-24', 'https://homizi.netlify.app/demo_media/avatar_04.webp', 'Mumbai', 20000, 35000, date '2026-11-10', 'I cook most nights and keep a tidy kitchen.')
        ) as t(user_id, req_id, email, display_name, occupation, age_range, avatar, city, bmin, bmax, move_in, bio)
      loop
        perform public.homizi_seed_auth_user(rec.user_id, rec.email);
        insert into public.users (id, status, primary_role)
        values (rec.user_id, 'active', 'tenant')
        on conflict (id) do update set status = 'active';
        insert into public.profiles (
          user_id, display_name, occupation, public_bio, avatar_path, age_range
        ) values (
          rec.user_id, rec.display_name, rec.occupation, rec.bio, rec.avatar, rec.age_range
        )
        on conflict (user_id) do update
        set display_name = excluded.display_name,
            occupation = excluded.occupation,
            public_bio = excluded.public_bio,
            avatar_path = excluded.avatar_path,
            age_range = excluded.age_range;
        insert into public.private_contacts (user_id, email, phone)
        values (rec.user_id, rec.email, null)
        on conflict (user_id) do update set phone = null;
        insert into public.listing_requirements (
          id, user_id, city, localities, budget_min_inr, budget_max_inr,
          move_in_date, occupancy, property_types, furnishing, lifestyle, status
        ) values (
          rec.req_id, rec.user_id, rec.city, array[rec.city], rec.bmin, rec.bmax,
          rec.move_in, 1, array['apartment']::public.property_type[], 'furnished',
          array['wfh', 'non_smoker']::text[], 'published'
        )
        on conflict (id) do update
        set status = 'published',
            city = excluded.city,
            budget_min_inr = excluded.budget_min_inr,
            budget_max_inr = excluded.budget_max_inr,
            move_in_date = excluded.move_in_date;
        insert into public.tenant_preferences (
          user_id, budget_min_inr, budget_max_inr, move_in_date, lifestyle
        ) values (
          rec.user_id, rec.bmin, rec.bmax, rec.move_in, array['wfh', 'non_smoker']::text[]
        )
        on conflict (user_id) do update
        set budget_min_inr = excluded.budget_min_inr,
            budget_max_inr = excluded.budget_max_inr,
            move_in_date = excluded.move_in_date,
            lifestyle = excluded.lifestyle;
      end loop;



    insert into public.localities (city, name, slug, popularity)
    values
      ('Ahmedabad', 'Satellite', 'satellite', 96),
      ('Ahmedabad', 'Bodakdev', 'bodakdev', 94),
      ('Ahmedabad', 'Prahlad Nagar', 'prahlad-nagar', 92),
      ('Ahmedabad', 'Vastrapur', 'vastrapur', 90),
      ('Ahmedabad', 'SG Highway', 'sg-highway', 88),
      ('Ahmedabad', 'Thaltej', 'thaltej', 86),
      ('Ahmedabad', 'Navrangpura', 'navrangpura', 84),
      ('Ahmedabad', 'Maninagar', 'maninagar', 82),
      ('Ahmedabad', 'Chandkheda', 'chandkheda', 80),
      ('Ahmedabad', 'Gota', 'gota', 78),
      ('Ahmedabad', 'Bopal', 'bopal', 76),
      ('Ahmedabad', 'South Bopal', 'south-bopal', 74),
      ('Ahmedabad', 'Science City', 'science-city', 72),
      ('Ahmedabad', 'Paldi', 'paldi', 70),
      ('Ahmedabad', 'Naranpura', 'naranpura', 68)
    on conflict (city, slug) do update
    set name = excluded.name,
        popularity = excluded.popularity;


    insert into public.properties (
      id, host_user_id, title, locality, city, property_type, furnishing,
      rent_inr, deposit_inr, maintenance_inr, occupancy_max, status,
      available_from, published_at, address_visibility,
      area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
      gated_society, floor_no, total_floors, approx_latitude, approx_longitude
    )
    select
      id,
      'c0ffee00-0000-4000-8000-000000000001'::uuid,
      title, locality, city, property_type, furnishing,
      rent_inr, deposit_inr, maintenance_inr, occupancy_max,
      'published'::public.listing_status,
      available_from, published_at, 'locality_only'::public.address_visibility,
      area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
      gated_society, floor_no, total_floors, approx_latitude, approx_longitude
    from (
      values
      ('d1000101-0000-4000-8000-000000000101'::uuid, '2 BHK in Satellite', 'Satellite', 'Ahmedabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 22000, 44000, 1100, 2, date '2026-11-02', timestamptz '2026-10-16 10:00:00+00', 980, array['family']::text[], true, false, false, true, 3, 10, 23.03, 72.512),
      ('d1000102-0000-4000-8000-000000000102'::uuid, '3 BHK in Bodakdev', 'Bodakdev', 'Ahmedabad', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 38000, 76000, 1900, 2, date '2026-11-08', timestamptz '2026-10-16 10:00:00+00', 1400, array['family']::text[], false, true, false, false, 6, 12, 23.04, 72.512),
      ('d1000103-0000-4000-8000-000000000103'::uuid, '1 BHK in Prahlad Nagar', 'Prahlad Nagar', 'Ahmedabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 16000, 32000, 800, 2, date '2026-11-04', timestamptz '2026-10-16 10:00:00+00', 640, array['bachelors']::text[], false, false, false, false, 2, 8, 23.012, 72.511),
      ('d1000104-0000-4000-8000-000000000104'::uuid, 'Studio in Vastrapur', 'Vastrapur', 'Ahmedabad', 'studio'::public.property_type, 'furnished'::public.furnishing, 12000, 24000, 600, 2, date '2026-11-01', timestamptz '2026-10-16 10:00:00+00', 420, array['any']::text[], false, false, false, false, 1, 7, 23.039, 72.529),
      ('d1000105-0000-4000-8000-000000000105'::uuid, '4 BHK villa on SG Highway', 'SG Highway', 'Ahmedabad', 'villa'::public.property_type, 'furnished'::public.furnishing, 75000, 150000, 3750, 2, date '2026-10-01', timestamptz '2026-10-16 10:00:00+00', 2800, array['family']::text[], true, true, true, true, 0, 1, 23.047, 72.524),
      ('d1000106-0000-4000-8000-000000000106'::uuid, 'PG in Thaltej', 'Thaltej', 'Ahmedabad', 'pg'::public.property_type, 'unfurnished'::public.furnishing, 8000, 16000, 500, 2, date '2026-10-20', timestamptz '2026-10-16 10:00:00+00', 280, array['bachelors']::text[], false, false, false, false, 1, 4, 23.049, 72.494),
      ('d1000107-0000-4000-8000-000000000107'::uuid, 'Private room in Navrangpura', 'Navrangpura', 'Ahmedabad', 'private_room'::public.property_type, 'semi_furnished'::public.furnishing, 11000, 22000, 550, 2, date '2026-11-06', timestamptz '2026-10-16 10:00:00+00', 220, array['female']::text[], false, false, true, false, 2, 5, 23.037, 72.561),
      ('d1000108-0000-4000-8000-000000000108'::uuid, 'Independent house in Maninagar', 'Maninagar', 'Ahmedabad', 'independent_house'::public.property_type, 'unfurnished'::public.furnishing, 25000, 50000, 1250, 2, date '2026-11-15', timestamptz '2026-10-16 10:00:00+00', 1700, array['family']::text[], true, false, false, false, 0, 2, 22.996, 72.604),
      ('d1000109-0000-4000-8000-000000000109'::uuid, '2 BHK in Chandkheda', 'Chandkheda', 'Ahmedabad', 'apartment'::public.property_type, 'unfurnished'::public.furnishing, 14000, 28000, 700, 2, date '2026-11-18', timestamptz '2026-10-16 10:00:00+00', 900, array['bachelors']::text[], false, false, true, false, 4, 8, 23.11, 72.572),
      ('d1000110-0000-4000-8000-000000000110'::uuid, '1 BHK in Gota', 'Gota', 'Ahmedabad', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 13000, 26000, 650, 2, date '2026-11-09', timestamptz '2026-10-16 10:00:00+00', 700, array['any']::text[], false, true, false, false, 9, 12, 23.1, 72.541),
      ('d1000111-0000-4000-8000-000000000111'::uuid, 'Shared room in Bopal', 'Bopal', 'Ahmedabad', 'shared_room'::public.property_type, 'unfurnished'::public.furnishing, 7500, 15000, 500, 2, date '2026-10-25', timestamptz '2026-10-16 10:00:00+00', 200, array['bachelors']::text[], false, false, false, false, 1, 4, 23.032, 72.467),
      ('d1000112-0000-4000-8000-000000000112'::uuid, '2 BHK in South Bopal', 'South Bopal', 'Ahmedabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 20000, 40000, 1000, 2, date '2026-11-12', timestamptz '2026-10-16 10:00:00+00', 1100, array['family']::text[], true, false, false, true, 5, 10, 23.02, 72.468),
      ('d1000113-0000-4000-8000-000000000113'::uuid, '3 BHK near Science City', 'Science City', 'Ahmedabad', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 32000, 64000, 1600, 2, date '2026-11-20', timestamptz '2026-10-16 10:00:00+00', 1500, array['family']::text[], false, true, true, false, 11, 14, 23.073, 72.495),
      ('d1000114-0000-4000-8000-000000000114'::uuid, 'Studio in Paldi', 'Paldi', 'Ahmedabad', 'studio'::public.property_type, 'furnished'::public.furnishing, 15000, 30000, 750, 2, date '2026-11-03', timestamptz '2026-10-16 10:00:00+00', 450, array['female']::text[], false, false, false, false, 3, 6, 23.012, 72.563),
      ('d1000115-0000-4000-8000-000000000115'::uuid, '4 BHK in Naranpura', 'Naranpura', 'Ahmedabad', 'apartment'::public.property_type, 'furnished'::public.furnishing, 55000, 110000, 2750, 2, date '2026-12-01', timestamptz '2026-10-16 10:00:00+00', 2100, array['family']::text[], true, false, false, true, 7, 12, 23.053, 72.547),
      ('d1000116-0000-4000-8000-000000000116'::uuid, '2 BHK in Adyar', 'Adyar', 'Chennai', 'apartment'::public.property_type, 'furnished'::public.furnishing, 28000, 56000, 1400, 2, date '2026-11-11', timestamptz '2026-10-16 10:00:00+00', 1050, array['family']::text[], true, false, false, false, 4, 8, 13.001, 80.257),
      ('d1000117-0000-4000-8000-000000000117'::uuid, '1 BHK in T. Nagar', 'T. Nagar', 'Chennai', 'apartment'::public.property_type, 'semi_furnished'::public.furnishing, 18000, 36000, 900, 2, date '2026-11-07', timestamptz '2026-10-16 10:00:00+00', 720, array['bachelors']::text[], true, false, false, false, 2, 6, 13.041, 80.234)
    ) as seed (
      id, title, locality, city, property_type, furnishing,
      rent_inr, deposit_inr, maintenance_inr, occupancy_max,
      available_from, published_at,
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
        maintenance_inr = excluded.maintenance_inr,
        occupancy_max = excluded.occupancy_max,
        status = 'published',
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
      ('d1000101-0000-4000-8000-000000000101'::uuid, 'bedrooms', '2'),
      ('d1000102-0000-4000-8000-000000000102'::uuid, 'bedrooms', '3'),
      ('d1000103-0000-4000-8000-000000000103'::uuid, 'bedrooms', '1'),
      ('d1000104-0000-4000-8000-000000000104'::uuid, 'bedrooms', '0'),
      ('d1000105-0000-4000-8000-000000000105'::uuid, 'bedrooms', '4'),
      ('d1000106-0000-4000-8000-000000000106'::uuid, 'bedrooms', '1'),
      ('d1000107-0000-4000-8000-000000000107'::uuid, 'bedrooms', '1'),
      ('d1000108-0000-4000-8000-000000000108'::uuid, 'bedrooms', '3'),
      ('d1000109-0000-4000-8000-000000000109'::uuid, 'bedrooms', '2'),
      ('d1000110-0000-4000-8000-000000000110'::uuid, 'bedrooms', '1'),
      ('d1000111-0000-4000-8000-000000000111'::uuid, 'bedrooms', '1'),
      ('d1000112-0000-4000-8000-000000000112'::uuid, 'bedrooms', '2'),
      ('d1000113-0000-4000-8000-000000000113'::uuid, 'bedrooms', '3'),
      ('d1000114-0000-4000-8000-000000000114'::uuid, 'bedrooms', '0'),
      ('d1000115-0000-4000-8000-000000000115'::uuid, 'bedrooms', '4'),
      ('d1000116-0000-4000-8000-000000000116'::uuid, 'bedrooms', '2'),
      ('d1000117-0000-4000-8000-000000000117'::uuid, 'bedrooms', '1')
    ) as seed (property_id, feature_key, value)
    on conflict (property_id, feature_key) do update
    set value = excluded.value;

    update public.properties p
    set
      area_sqft = coalesce(p.area_sqft, case
        when p.rent_inr < 10000 then 320
        when p.rent_inr < 20000 then 720
        when p.rent_inr < 35000 then 1100
        when p.rent_inr < 50000 then 1500
        else 1800
      end),
      floor_no = coalesce(p.floor_no, 2),
      total_floors = coalesce(p.total_floors, 10),
      parking = p.parking or p.property_type in ('apartment', 'villa', 'independent_house'),
      preferred_tenants = case
        when p.preferred_tenants = '{}'::text[]
          and p.property_type in ('private_room', 'shared_room', 'pg')
          then array['bachelors']::text[]
        when p.preferred_tenants = '{}'::text[] then array['family']::text[]
        else p.preferred_tenants
      end,
      approx_latitude = coalesce(p.approx_latitude, case p.city
        when 'Bengaluru' then 12.972
        when 'Mumbai' then 19.076
        when 'Pune' then 18.520
        when 'Hyderabad' then 17.385
        when 'Delhi NCR' then 28.614
        when 'Chennai' then 13.083
        when 'Ahmedabad' then 23.023
        else 22.500
      end),
      approx_longitude = coalesce(p.approx_longitude, case p.city
        when 'Bengaluru' then 77.594
        when 'Mumbai' then 72.878
        when 'Pune' then 73.856
        when 'Hyderabad' then 78.487
        when 'Delhi NCR' then 77.209
        when 'Chennai' then 80.271
        when 'Ahmedabad' then 72.572
        else 79.000
      end)
    where p.host_user_id = 'c0ffee00-0000-4000-8000-000000000001'
      and p.id >= 'd1000001-0000-4000-8000-000000000001'::uuid
      and p.id <= 'd1000040-0000-4000-8000-000000000040'::uuid;

    delete from public.property_photos
    where property_id in (
      'd1000001-0000-4000-8000-000000000001'::uuid,
      'd1000002-0000-4000-8000-000000000002'::uuid,
      'd1000003-0000-4000-8000-000000000003'::uuid,
      'd1000004-0000-4000-8000-000000000004'::uuid,
      'd1000005-0000-4000-8000-000000000005'::uuid,
      'd1000006-0000-4000-8000-000000000006'::uuid,
      'd1000007-0000-4000-8000-000000000007'::uuid,
      'd1000008-0000-4000-8000-000000000008'::uuid,
      'd1000009-0000-4000-8000-000000000009'::uuid,
      'd1000010-0000-4000-8000-000000000010'::uuid,
      'd1000011-0000-4000-8000-000000000011'::uuid,
      'd1000012-0000-4000-8000-000000000012'::uuid,
      'd1000013-0000-4000-8000-000000000013'::uuid,
      'd1000014-0000-4000-8000-000000000014'::uuid,
      'd1000015-0000-4000-8000-000000000015'::uuid,
      'd1000016-0000-4000-8000-000000000016'::uuid,
      'd1000017-0000-4000-8000-000000000017'::uuid,
      'd1000018-0000-4000-8000-000000000018'::uuid,
      'd1000019-0000-4000-8000-000000000019'::uuid,
      'd1000020-0000-4000-8000-000000000020'::uuid,
      'd1000021-0000-4000-8000-000000000021'::uuid,
      'd1000022-0000-4000-8000-000000000022'::uuid,
      'd1000023-0000-4000-8000-000000000023'::uuid,
      'd1000024-0000-4000-8000-000000000024'::uuid,
      'd1000025-0000-4000-8000-000000000025'::uuid,
      'd1000026-0000-4000-8000-000000000026'::uuid,
      'd1000027-0000-4000-8000-000000000027'::uuid,
      'd1000028-0000-4000-8000-000000000028'::uuid,
      'd1000029-0000-4000-8000-000000000029'::uuid,
      'd1000030-0000-4000-8000-000000000030'::uuid,
      'd1000031-0000-4000-8000-000000000031'::uuid,
      'd1000032-0000-4000-8000-000000000032'::uuid,
      'd1000033-0000-4000-8000-000000000033'::uuid,
      'd1000034-0000-4000-8000-000000000034'::uuid,
      'd1000035-0000-4000-8000-000000000035'::uuid,
      'd1000036-0000-4000-8000-000000000036'::uuid,
      'd1000037-0000-4000-8000-000000000037'::uuid,
      'd1000038-0000-4000-8000-000000000038'::uuid,
      'd1000039-0000-4000-8000-000000000039'::uuid,
      'd1000040-0000-4000-8000-000000000040'::uuid,
      'd1000101-0000-4000-8000-000000000101'::uuid,
      'd1000102-0000-4000-8000-000000000102'::uuid,
      'd1000103-0000-4000-8000-000000000103'::uuid,
      'd1000104-0000-4000-8000-000000000104'::uuid,
      'd1000105-0000-4000-8000-000000000105'::uuid,
      'd1000106-0000-4000-8000-000000000106'::uuid,
      'd1000107-0000-4000-8000-000000000107'::uuid,
      'd1000108-0000-4000-8000-000000000108'::uuid,
      'd1000109-0000-4000-8000-000000000109'::uuid,
      'd1000110-0000-4000-8000-000000000110'::uuid,
      'd1000111-0000-4000-8000-000000000111'::uuid,
      'd1000112-0000-4000-8000-000000000112'::uuid,
      'd1000113-0000-4000-8000-000000000113'::uuid,
      'd1000114-0000-4000-8000-000000000114'::uuid,
      'd1000115-0000-4000-8000-000000000115'::uuid,
      'd1000116-0000-4000-8000-000000000116'::uuid,
      'd1000117-0000-4000-8000-000000000117'::uuid
    );

    insert into public.property_photos (
      property_id, storage_path, sort_order, photo_type, moderation_status
    )
    select property_id, storage_path, sort_order, photo_type, 'approved'::public.moderation_status
    from (
      values
      ('d1000001-0000-4000-8000-000000000001'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'::public.photo_type),
      ('d1000001-0000-4000-8000-000000000001'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000001-0000-4000-8000-000000000001'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000002-0000-4000-8000-000000000002'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 0, 'living'::public.photo_type),
      ('d1000002-0000-4000-8000-000000000002'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000002-0000-4000-8000-000000000002'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000002-0000-4000-8000-000000000002'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000003-0000-4000-8000-000000000003'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 0, 'living'::public.photo_type),
      ('d1000003-0000-4000-8000-000000000003'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000003-0000-4000-8000-000000000003'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000003-0000-4000-8000-000000000003'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000003-0000-4000-8000-000000000003'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 4, 'exterior'::public.photo_type),
      ('d1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 0, 'living'::public.photo_type),
      ('d1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 1, 'bedroom'::public.photo_type),
      ('d1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 3, 'bathroom'::public.photo_type),
      ('d1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000004-0000-4000-8000-000000000004'::uuid, 'https://homizi.netlify.app/demo_media/dining_01.webp', 5, 'other'::public.photo_type),
      ('d1000005-0000-4000-8000-000000000005'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 0, 'living'::public.photo_type),
      ('d1000005-0000-4000-8000-000000000005'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000005-0000-4000-8000-000000000005'::uuid, 'https://homizi.netlify.app/demo_media/dining_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000006-0000-4000-8000-000000000006'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'::public.photo_type),
      ('d1000006-0000-4000-8000-000000000006'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'::public.photo_type),
      ('d1000006-0000-4000-8000-000000000006'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000006-0000-4000-8000-000000000006'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000007-0000-4000-8000-000000000007'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 0, 'living'::public.photo_type),
      ('d1000007-0000-4000-8000-000000000007'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000007-0000-4000-8000-000000000007'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 2, 'kitchen'::public.photo_type),
      ('d1000007-0000-4000-8000-000000000007'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000007-0000-4000-8000-000000000007'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'::public.photo_type),
      ('d1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000008-0000-4000-8000-000000000008'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 5, 'other'::public.photo_type),
      ('d1000009-0000-4000-8000-000000000009'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 0, 'living'::public.photo_type),
      ('d1000009-0000-4000-8000-000000000009'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000009-0000-4000-8000-000000000009'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000010-0000-4000-8000-000000000010'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 0, 'living'::public.photo_type),
      ('d1000010-0000-4000-8000-000000000010'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000010-0000-4000-8000-000000000010'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000010-0000-4000-8000-000000000010'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000011-0000-4000-8000-000000000011'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 0, 'living'::public.photo_type),
      ('d1000011-0000-4000-8000-000000000011'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 1, 'bedroom'::public.photo_type),
      ('d1000011-0000-4000-8000-000000000011'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000011-0000-4000-8000-000000000011'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 3, 'bathroom'::public.photo_type),
      ('d1000011-0000-4000-8000-000000000011'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 0, 'living'::public.photo_type),
      ('d1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/dining_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 3, 'bathroom'::public.photo_type),
      ('d1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 4, 'exterior'::public.photo_type),
      ('d1000012-0000-4000-8000-000000000012'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 5, 'other'::public.photo_type),
      ('d1000013-0000-4000-8000-000000000013'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'::public.photo_type),
      ('d1000013-0000-4000-8000-000000000013'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'::public.photo_type),
      ('d1000013-0000-4000-8000-000000000013'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000014-0000-4000-8000-000000000014'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 0, 'living'::public.photo_type),
      ('d1000014-0000-4000-8000-000000000014'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000014-0000-4000-8000-000000000014'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 2, 'kitchen'::public.photo_type),
      ('d1000014-0000-4000-8000-000000000014'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000015-0000-4000-8000-000000000015'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'::public.photo_type),
      ('d1000015-0000-4000-8000-000000000015'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000015-0000-4000-8000-000000000015'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000015-0000-4000-8000-000000000015'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000015-0000-4000-8000-000000000015'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 0, 'living'::public.photo_type),
      ('d1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 4, 'exterior'::public.photo_type),
      ('d1000016-0000-4000-8000-000000000016'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 5, 'other'::public.photo_type),
      ('d1000017-0000-4000-8000-000000000017'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 0, 'living'::public.photo_type),
      ('d1000017-0000-4000-8000-000000000017'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000017-0000-4000-8000-000000000017'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000018-0000-4000-8000-000000000018'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 0, 'living'::public.photo_type),
      ('d1000018-0000-4000-8000-000000000018'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 1, 'bedroom'::public.photo_type),
      ('d1000018-0000-4000-8000-000000000018'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000018-0000-4000-8000-000000000018'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 3, 'bathroom'::public.photo_type),
      ('d1000019-0000-4000-8000-000000000019'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 0, 'living'::public.photo_type),
      ('d1000019-0000-4000-8000-000000000019'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000019-0000-4000-8000-000000000019'::uuid, 'https://homizi.netlify.app/demo_media/dining_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000019-0000-4000-8000-000000000019'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 3, 'bathroom'::public.photo_type),
      ('d1000019-0000-4000-8000-000000000019'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 4, 'exterior'::public.photo_type),
      ('d1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'::public.photo_type),
      ('d1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'::public.photo_type),
      ('d1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 4, 'exterior'::public.photo_type),
      ('d1000020-0000-4000-8000-000000000020'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 5, 'other'::public.photo_type),
      ('d1000021-0000-4000-8000-000000000021'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 0, 'living'::public.photo_type),
      ('d1000021-0000-4000-8000-000000000021'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000021-0000-4000-8000-000000000021'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 2, 'kitchen'::public.photo_type),
      ('d1000022-0000-4000-8000-000000000022'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'::public.photo_type),
      ('d1000022-0000-4000-8000-000000000022'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000022-0000-4000-8000-000000000022'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000022-0000-4000-8000-000000000022'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000023-0000-4000-8000-000000000023'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 0, 'living'::public.photo_type),
      ('d1000023-0000-4000-8000-000000000023'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000023-0000-4000-8000-000000000023'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000023-0000-4000-8000-000000000023'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000023-0000-4000-8000-000000000023'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 4, 'exterior'::public.photo_type),
      ('d1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 0, 'living'::public.photo_type),
      ('d1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 4, 'exterior'::public.photo_type),
      ('d1000024-0000-4000-8000-000000000024'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 5, 'other'::public.photo_type),
      ('d1000025-0000-4000-8000-000000000025'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 0, 'living'::public.photo_type),
      ('d1000025-0000-4000-8000-000000000025'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 1, 'bedroom'::public.photo_type),
      ('d1000025-0000-4000-8000-000000000025'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000026-0000-4000-8000-000000000026'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 0, 'living'::public.photo_type),
      ('d1000026-0000-4000-8000-000000000026'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000026-0000-4000-8000-000000000026'::uuid, 'https://homizi.netlify.app/demo_media/dining_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000026-0000-4000-8000-000000000026'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 3, 'bathroom'::public.photo_type),
      ('d1000027-0000-4000-8000-000000000027'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'::public.photo_type),
      ('d1000027-0000-4000-8000-000000000027'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'::public.photo_type),
      ('d1000027-0000-4000-8000-000000000027'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000027-0000-4000-8000-000000000027'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000027-0000-4000-8000-000000000027'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 4, 'exterior'::public.photo_type),
      ('d1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 0, 'living'::public.photo_type),
      ('d1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 2, 'kitchen'::public.photo_type),
      ('d1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000028-0000-4000-8000-000000000028'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 5, 'other'::public.photo_type),
      ('d1000029-0000-4000-8000-000000000029'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'::public.photo_type),
      ('d1000029-0000-4000-8000-000000000029'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000029-0000-4000-8000-000000000029'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000030-0000-4000-8000-000000000030'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 0, 'living'::public.photo_type),
      ('d1000030-0000-4000-8000-000000000030'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000030-0000-4000-8000-000000000030'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000030-0000-4000-8000-000000000030'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000031-0000-4000-8000-000000000031'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 0, 'living'::public.photo_type),
      ('d1000031-0000-4000-8000-000000000031'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000031-0000-4000-8000-000000000031'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000031-0000-4000-8000-000000000031'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000031-0000-4000-8000-000000000031'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 4, 'exterior'::public.photo_type),
      ('d1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 0, 'living'::public.photo_type),
      ('d1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 1, 'bedroom'::public.photo_type),
      ('d1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 3, 'bathroom'::public.photo_type),
      ('d1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000032-0000-4000-8000-000000000032'::uuid, 'https://homizi.netlify.app/demo_media/dining_01.webp', 5, 'other'::public.photo_type),
      ('d1000033-0000-4000-8000-000000000033'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 0, 'living'::public.photo_type),
      ('d1000033-0000-4000-8000-000000000033'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000033-0000-4000-8000-000000000033'::uuid, 'https://homizi.netlify.app/demo_media/dining_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000034-0000-4000-8000-000000000034'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'::public.photo_type),
      ('d1000034-0000-4000-8000-000000000034'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'::public.photo_type),
      ('d1000034-0000-4000-8000-000000000034'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000034-0000-4000-8000-000000000034'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000035-0000-4000-8000-000000000035'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 0, 'living'::public.photo_type),
      ('d1000035-0000-4000-8000-000000000035'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000035-0000-4000-8000-000000000035'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 2, 'kitchen'::public.photo_type),
      ('d1000035-0000-4000-8000-000000000035'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000035-0000-4000-8000-000000000035'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'::public.photo_type),
      ('d1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000036-0000-4000-8000-000000000036'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 5, 'other'::public.photo_type),
      ('d1000037-0000-4000-8000-000000000037'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 0, 'living'::public.photo_type),
      ('d1000037-0000-4000-8000-000000000037'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000037-0000-4000-8000-000000000037'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000038-0000-4000-8000-000000000038'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 0, 'living'::public.photo_type),
      ('d1000038-0000-4000-8000-000000000038'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000038-0000-4000-8000-000000000038'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000038-0000-4000-8000-000000000038'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000039-0000-4000-8000-000000000039'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 0, 'living'::public.photo_type),
      ('d1000039-0000-4000-8000-000000000039'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 1, 'bedroom'::public.photo_type),
      ('d1000039-0000-4000-8000-000000000039'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000039-0000-4000-8000-000000000039'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 3, 'bathroom'::public.photo_type),
      ('d1000039-0000-4000-8000-000000000039'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 0, 'living'::public.photo_type),
      ('d1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/dining_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 3, 'bathroom'::public.photo_type),
      ('d1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 4, 'exterior'::public.photo_type),
      ('d1000040-0000-4000-8000-000000000040'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 5, 'other'::public.photo_type),
      ('d1000101-0000-4000-8000-000000000101'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'::public.photo_type),
      ('d1000101-0000-4000-8000-000000000101'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'::public.photo_type),
      ('d1000101-0000-4000-8000-000000000101'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000102-0000-4000-8000-000000000102'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 0, 'living'::public.photo_type),
      ('d1000102-0000-4000-8000-000000000102'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000102-0000-4000-8000-000000000102'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 2, 'kitchen'::public.photo_type),
      ('d1000102-0000-4000-8000-000000000102'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000103-0000-4000-8000-000000000103'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'::public.photo_type),
      ('d1000103-0000-4000-8000-000000000103'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000103-0000-4000-8000-000000000103'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000103-0000-4000-8000-000000000103'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000103-0000-4000-8000-000000000103'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000104-0000-4000-8000-000000000104'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 0, 'living'::public.photo_type),
      ('d1000104-0000-4000-8000-000000000104'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000104-0000-4000-8000-000000000104'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000104-0000-4000-8000-000000000104'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000104-0000-4000-8000-000000000104'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 4, 'exterior'::public.photo_type),
      ('d1000104-0000-4000-8000-000000000104'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 5, 'other'::public.photo_type),
      ('d1000105-0000-4000-8000-000000000105'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 0, 'living'::public.photo_type),
      ('d1000105-0000-4000-8000-000000000105'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000105-0000-4000-8000-000000000105'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000106-0000-4000-8000-000000000106'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 0, 'living'::public.photo_type),
      ('d1000106-0000-4000-8000-000000000106'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 1, 'bedroom'::public.photo_type),
      ('d1000106-0000-4000-8000-000000000106'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000106-0000-4000-8000-000000000106'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 3, 'bathroom'::public.photo_type),
      ('d1000107-0000-4000-8000-000000000107'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 0, 'living'::public.photo_type),
      ('d1000107-0000-4000-8000-000000000107'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000107-0000-4000-8000-000000000107'::uuid, 'https://homizi.netlify.app/demo_media/dining_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000107-0000-4000-8000-000000000107'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 3, 'bathroom'::public.photo_type),
      ('d1000107-0000-4000-8000-000000000107'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 4, 'exterior'::public.photo_type),
      ('d1000108-0000-4000-8000-000000000108'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'::public.photo_type),
      ('d1000108-0000-4000-8000-000000000108'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'::public.photo_type),
      ('d1000108-0000-4000-8000-000000000108'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000108-0000-4000-8000-000000000108'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000108-0000-4000-8000-000000000108'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 4, 'exterior'::public.photo_type),
      ('d1000108-0000-4000-8000-000000000108'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 5, 'other'::public.photo_type),
      ('d1000109-0000-4000-8000-000000000109'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 0, 'living'::public.photo_type),
      ('d1000109-0000-4000-8000-000000000109'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000109-0000-4000-8000-000000000109'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 2, 'kitchen'::public.photo_type),
      ('d1000110-0000-4000-8000-000000000110'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'::public.photo_type),
      ('d1000110-0000-4000-8000-000000000110'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000110-0000-4000-8000-000000000110'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000110-0000-4000-8000-000000000110'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000111-0000-4000-8000-000000000111'::uuid, 'https://homizi.netlify.app/demo_media/bath_01.webp', 0, 'living'::public.photo_type),
      ('d1000111-0000-4000-8000-000000000111'::uuid, 'https://homizi.netlify.app/demo_media/exterior_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000111-0000-4000-8000-000000000111'::uuid, 'https://homizi.netlify.app/demo_media/living_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000111-0000-4000-8000-000000000111'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000111-0000-4000-8000-000000000111'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 4, 'exterior'::public.photo_type),
      ('d1000112-0000-4000-8000-000000000112'::uuid, 'https://homizi.netlify.app/demo_media/bed_02.webp', 0, 'living'::public.photo_type),
      ('d1000112-0000-4000-8000-000000000112'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000112-0000-4000-8000-000000000112'::uuid, 'https://homizi.netlify.app/demo_media/bath_02.webp', 2, 'kitchen'::public.photo_type),
      ('d1000112-0000-4000-8000-000000000112'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 3, 'bathroom'::public.photo_type),
      ('d1000112-0000-4000-8000-000000000112'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 4, 'exterior'::public.photo_type),
      ('d1000112-0000-4000-8000-000000000112'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 5, 'other'::public.photo_type),
      ('d1000113-0000-4000-8000-000000000113'::uuid, 'https://homizi.netlify.app/demo_media/exterior_02.webp', 0, 'living'::public.photo_type),
      ('d1000113-0000-4000-8000-000000000113'::uuid, 'https://homizi.netlify.app/demo_media/living_03.webp', 1, 'bedroom'::public.photo_type),
      ('d1000113-0000-4000-8000-000000000113'::uuid, 'https://homizi.netlify.app/demo_media/bed_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000114-0000-4000-8000-000000000114'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_03.webp', 0, 'living'::public.photo_type),
      ('d1000114-0000-4000-8000-000000000114'::uuid, 'https://homizi.netlify.app/demo_media/balcony_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000114-0000-4000-8000-000000000114'::uuid, 'https://homizi.netlify.app/demo_media/dining_01.webp', 2, 'kitchen'::public.photo_type),
      ('d1000114-0000-4000-8000-000000000114'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 3, 'bathroom'::public.photo_type),
      ('d1000115-0000-4000-8000-000000000115'::uuid, 'https://homizi.netlify.app/demo_media/living_04.webp', 0, 'living'::public.photo_type),
      ('d1000115-0000-4000-8000-000000000115'::uuid, 'https://homizi.netlify.app/demo_media/bed_04.webp', 1, 'bedroom'::public.photo_type),
      ('d1000115-0000-4000-8000-000000000115'::uuid, 'https://homizi.netlify.app/demo_media/exterior_03.webp', 2, 'kitchen'::public.photo_type),
      ('d1000115-0000-4000-8000-000000000115'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000115-0000-4000-8000-000000000115'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 4, 'exterior'::public.photo_type),
      ('d1000116-0000-4000-8000-000000000116'::uuid, 'https://homizi.netlify.app/demo_media/workspace_01.webp', 0, 'living'::public.photo_type),
      ('d1000116-0000-4000-8000-000000000116'::uuid, 'https://homizi.netlify.app/demo_media/balcony_02.webp', 1, 'bedroom'::public.photo_type),
      ('d1000116-0000-4000-8000-000000000116'::uuid, 'https://homizi.netlify.app/demo_media/living_05.webp', 2, 'kitchen'::public.photo_type),
      ('d1000116-0000-4000-8000-000000000116'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 3, 'bathroom'::public.photo_type),
      ('d1000116-0000-4000-8000-000000000116'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 4, 'exterior'::public.photo_type),
      ('d1000116-0000-4000-8000-000000000116'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 5, 'other'::public.photo_type),
      ('d1000117-0000-4000-8000-000000000117'::uuid, 'https://homizi.netlify.app/demo_media/living_01.webp', 0, 'living'::public.photo_type),
      ('d1000117-0000-4000-8000-000000000117'::uuid, 'https://homizi.netlify.app/demo_media/bed_01.webp', 1, 'bedroom'::public.photo_type),
      ('d1000117-0000-4000-8000-000000000117'::uuid, 'https://homizi.netlify.app/demo_media/kitchen_01.webp', 2, 'kitchen'::public.photo_type)
    ) as seed (property_id, storage_path, sort_order, photo_type);
  exception
    when others then
      raise notice 'coverage seed skipped: %', sqlerrm;
  end;
end
$homizi_coverage_seed$;


insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261017190000',
  'avatars_swipe',
  array['docs/staging_apply_E_1017c.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261017190100',
  'ahmedabad_coverage_seed',
  array['docs/staging_apply_E_1017c.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;


do $homizi_filter_assert$
declare
  host uuid := 'c0ffee00-0000-4000-8000-000000000001';
  n int;
  label text;
begin
  create temporary table homizi_filter_checks (
    label text primary key,
    n int not null
  ) on commit drop;

  insert into homizi_filter_checks (label, n)
  select city, count(*)
  from public.properties
  where host_user_id = host and status = 'published'
    and city in ('Bengaluru', 'Mumbai', 'Pune', 'Delhi NCR', 'Hyderabad', 'Chennai', 'Ahmedabad')
  group by city;

  insert into homizi_filter_checks (label, n)
  select 'type:' || property_type::text, count(*)
  from public.properties
  where host_user_id = host and status = 'published'
  group by property_type;

  insert into homizi_filter_checks (label, n)
  select 'furn:' || furnishing::text, count(*)
  from public.properties
  where host_user_id = host and status = 'published'
  group by furnishing;

  insert into homizi_filter_checks (label, n) values
    ('budget:under-10000', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and rent_inr <= 9999)),
    ('budget:10000-20000', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and rent_inr between 10000 and 20000)),
    ('budget:20000-35000', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and rent_inr between 20000 and 35000)),
    ('budget:35000-50000', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and rent_inr between 35000 and 50000)),
    ('budget:50000-plus', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and rent_inr >= 50000)),
    ('tenant:family', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published'
        and preferred_tenants && array['family', 'any']::text[])),
    ('tenant:bachelors', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published'
        and preferred_tenants && array['bachelors', 'any']::text[])),
    ('tenant:female', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published'
        and preferred_tenants && array['female', 'any']::text[])),
    ('tenant:any', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published')),
    ('flag:parking', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and parking)),
    ('flag:pets', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and pets_allowed)),
    ('flag:nonveg', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and non_veg_allowed)),
    ('flag:gated', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and gated_society)),
    ('area:under-600', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and area_sqft <= 599)),
    ('area:600-1000', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and area_sqft between 600 and 1000)),
    ('area:1000-1600', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and area_sqft between 1000 and 1600)),
    ('area:1600-plus', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and area_sqft >= 1600)),
    ('floor:ground', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and floor_no = 0)),
    ('floor:1-4', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and floor_no between 1 and 4)),
    ('floor:5-8', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and floor_no between 5 and 8)),
    ('floor:9-plus', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published' and floor_no >= 9)),
    ('move:2026-10-17', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published'
        and (available_from is null or available_from <= date '2026-10-17'))),
    ('move:2026-12-01', (
      select count(*) from public.properties
      where host_user_id = host and status = 'published'
        and (available_from is null or available_from <= date '2026-12-01'))),
    ('photos-only', (
      select count(*) from public.properties p
      where p.host_user_id = host and p.status = 'published'
        and exists (
          select 1 from public.property_photos ph
          where ph.property_id = p.id and ph.moderation_status <> 'rejected'
        ))),
    ('verified-only', (
      select count(*) from public.properties p
      join public.profiles pr on pr.user_id = p.host_user_id
      where p.host_user_id = host and p.status = 'published'
        and pr.verification_status = 'mock_verified'));

  insert into homizi_filter_checks (label, n)
  select 'chip:' || chip, count(*)
  from public.properties p
  cross join (
    values ('1rk'), ('1bhk'), ('2bhk'), ('3bhk'), ('4bhk'), ('pg'), ('flatmate'), ('full_house')
  ) as chips(chip)
  where p.host_user_id = host
    and p.status = 'published'
    and (
      (chip = '1rk' and (
        p.property_type = 'studio'
        or exists (
          select 1 from public.property_features f
          where f.property_id = p.id and f.feature_key = 'bedrooms'
            and f.value ~ '^[0-9]+$' and (f.value)::integer <= 0
        )
      ))
      or (chip = '1bhk' and p.property_type in ('apartment', 'independent_house', 'villa')
          and exists (
            select 1 from public.property_features f
            where f.property_id = p.id and f.feature_key = 'bedrooms' and f.value = '1'
          ))
      or (chip = '2bhk' and p.property_type in ('apartment', 'independent_house', 'villa')
          and exists (
            select 1 from public.property_features f
            where f.property_id = p.id and f.feature_key = 'bedrooms' and f.value = '2'
          ))
      or (chip = '3bhk' and p.property_type in ('apartment', 'independent_house', 'villa')
          and exists (
            select 1 from public.property_features f
            where f.property_id = p.id and f.feature_key = 'bedrooms' and f.value = '3'
          ))
      or (chip = '4bhk' and p.property_type in ('apartment', 'independent_house', 'villa')
          and exists (
            select 1 from public.property_features f
            where f.property_id = p.id and f.feature_key = 'bedrooms'
              and f.value ~ '^[0-9]+$' and (f.value)::integer >= 4
          ))
      or (chip = 'pg' and p.property_type in ('pg', 'shared_room'))
      or (chip = 'flatmate' and p.property_type in ('private_room', 'shared_room'))
      or (chip = 'full_house' and p.property_type in ('apartment', 'independent_house', 'villa'))
    )
  group by chip;

  insert into homizi_filter_checks (label, n) values
    ('sort:newest', (select count(*) from public.properties where host_user_id = host and status = 'published')),
    ('sort:rent-low', (select count(*) from public.properties where host_user_id = host and status = 'published')),
    ('sort:rent-high', (select count(*) from public.properties where host_user_id = host and status = 'published')),
    ('sort:move-in', (select count(*) from public.properties where host_user_id = host and status = 'published')),
    ('sort:most-viewed', (select count(*) from public.properties where host_user_id = host and status = 'published'));

  for label, n in select c.label, c.n from homizi_filter_checks c loop
    if n < 1 then
      raise exception 'filter % matched % published seed listings', label, n;
    end if;
  end loop;

  select count(*) into n
  from (
    values
      ('Ahmedabad', 'Satellite'), ('Ahmedabad', 'Bodakdev'), ('Ahmedabad', 'Prahlad Nagar'),
      ('Ahmedabad', 'Vastrapur'), ('Ahmedabad', 'SG Highway'), ('Ahmedabad', 'Thaltej'),
      ('Ahmedabad', 'Navrangpura'), ('Ahmedabad', 'Maninagar'), ('Ahmedabad', 'Chandkheda'),
      ('Ahmedabad', 'Gota'), ('Ahmedabad', 'Bopal'), ('Ahmedabad', 'South Bopal'),
      ('Ahmedabad', 'Science City'), ('Ahmedabad', 'Paldi'), ('Ahmedabad', 'Naranpura')
  ) as want(city, name)
  where not exists (
    select 1 from public.localities l
    where l.city = want.city and l.name = want.name
  );
  if n <> 0 then
    raise exception 'Ahmedabad locality seed is missing % names', n;
  end if;

  select count(*) into n
  from public.properties p
  where p.host_user_id = host
    and p.status = 'published'
    and (
      select count(*) from public.property_photos ph
      where ph.property_id = p.id and ph.moderation_status = 'approved'
    ) not between 3 and 6;
  if n <> 0 then
    raise exception '% seed listings do not have 3 to 6 approved photos', n;
  end if;
end
$homizi_filter_assert$;
