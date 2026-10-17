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
