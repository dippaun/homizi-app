-- Search and explore: localities, richer listing filters, view counts,
-- saved searches, and photo requests.
-- View counts are aggregates. A photo request stores the property id only.
-- No phone, email, or street address is added.

create table if not exists public.localities (
  id uuid primary key default gen_random_uuid(),
  city text not null,
  name text not null,
  slug text not null,
  popularity integer not null default 0,
  constraint localities_city_len check (char_length(city) between 2 and 40),
  constraint localities_name_len check (char_length(name) between 2 and 80),
  constraint localities_slug check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint localities_popularity check (popularity between 0 and 100000),
  constraint localities_city_slug unique (city, slug)
);

comment on table public.localities is
  'Curated locality names for search. Public read. Clients cannot write rows.';

create index if not exists localities_city_popularity_idx
  on public.localities (city, popularity desc);

alter table public.localities enable row level security;

drop policy if exists localities_public_read on public.localities;
create policy localities_public_read on public.localities
  for select to anon, authenticated
  using (true);

revoke all on public.localities from anon, authenticated;
grant select on public.localities to anon, authenticated;

insert into public.localities (city, name, slug, popularity)
values
  ('Bengaluru', 'Koramangala', 'koramangala', 98),
  ('Bengaluru', 'Indiranagar', 'indiranagar', 96),
  ('Bengaluru', 'HSR Layout', 'hsr-layout', 94),
  ('Bengaluru', 'Whitefield', 'whitefield', 90),
  ('Bengaluru', 'Jayanagar', 'jayanagar', 86),
  ('Bengaluru', 'Bellandur', 'bellandur', 84),
  ('Bengaluru', 'Marathahalli', 'marathahalli', 80),
  ('Bengaluru', 'JP Nagar', 'jp-nagar', 78),
  ('Bengaluru', 'Hebbal', 'hebbal', 74),
  ('Bengaluru', 'BTM Layout', 'btm-layout', 72),
  ('Bengaluru', 'Electronic City', 'electronic-city', 70),
  ('Bengaluru', 'Malleswaram', 'malleswaram', 66),
  ('Mumbai', 'Andheri West', 'andheri-west', 97),
  ('Mumbai', 'Bandra West', 'bandra-west', 95),
  ('Mumbai', 'Powai', 'powai', 92),
  ('Mumbai', 'Thane', 'thane', 88),
  ('Mumbai', 'Goregaon East', 'goregaon-east', 86),
  ('Mumbai', 'Malad West', 'malad-west', 82),
  ('Mumbai', 'Dadar', 'dadar', 80),
  ('Mumbai', 'Chembur', 'chembur', 78),
  ('Mumbai', 'Mulund', 'mulund', 76),
  ('Mumbai', 'Juhu', 'juhu', 74),
  ('Pune', 'Baner', 'baner', 94),
  ('Pune', 'Kharadi', 'kharadi', 92),
  ('Pune', 'Kothrud', 'kothrud', 90),
  ('Pune', 'Viman Nagar', 'viman-nagar', 86),
  ('Pune', 'Wakad', 'wakad', 84),
  ('Pune', 'Hinjewadi', 'hinjewadi', 82),
  ('Pune', 'Koregaon Park', 'koregaon-park', 80),
  ('Pune', 'Aundh', 'aundh', 78),
  ('Pune', 'Kalyani Nagar', 'kalyani-nagar', 74),
  ('Pune', 'Hadapsar', 'hadapsar', 70),
  ('Delhi NCR', 'Gurugram', 'gurugram', 96),
  ('Delhi NCR', 'Noida Sector 62', 'noida-sector-62', 90),
  ('Delhi NCR', 'Dwarka', 'dwarka', 88),
  ('Delhi NCR', 'Noida', 'noida', 86),
  ('Delhi NCR', 'Saket', 'saket', 84),
  ('Delhi NCR', 'Greater Noida', 'greater-noida', 80),
  ('Delhi NCR', 'Indirapuram', 'indirapuram', 78),
  ('Delhi NCR', 'Rohini', 'rohini', 72),
  ('Hyderabad', 'Gachibowli', 'gachibowli', 96),
  ('Hyderabad', 'Madhapur', 'madhapur', 92),
  ('Hyderabad', 'Hitech City', 'hitech-city', 90),
  ('Hyderabad', 'Kondapur', 'kondapur', 88),
  ('Hyderabad', 'Banjara Hills', 'banjara-hills', 86),
  ('Hyderabad', 'Jubilee Hills', 'jubilee-hills', 84),
  ('Hyderabad', 'Kukatpally', 'kukatpally', 82),
  ('Hyderabad', 'Manikonda', 'manikonda', 74),
  ('Chennai', 'Adyar', 'adyar', 92),
  ('Chennai', 'T. Nagar', 't-nagar', 90),
  ('Chennai', 'Velachery', 'velachery', 88),
  ('Chennai', 'Anna Nagar', 'anna-nagar', 86),
  ('Chennai', 'OMR', 'omr', 84),
  ('Chennai', 'Porur', 'porur', 76),
  ('Chennai', 'Besant Nagar', 'besant-nagar', 74),
  ('Chennai', 'Mylapore', 'mylapore', 72),
  ('Chennai', 'Tambaram', 'tambaram', 70),
  ('Chennai', 'Guindy', 'guindy', 68)
on conflict (city, slug) do update
set name = excluded.name,
    popularity = excluded.popularity;

alter table public.properties
  add column if not exists area_sqft integer,
  add column if not exists preferred_tenants text[] not null default '{}',
  add column if not exists parking boolean not null default false,
  add column if not exists pets_allowed boolean not null default false,
  add column if not exists non_veg_allowed boolean not null default false,
  add column if not exists gated_society boolean not null default false,
  add column if not exists floor_no smallint,
  add column if not exists total_floors smallint;

alter table public.properties drop constraint if exists properties_area_sqft;
alter table public.properties
  add constraint properties_area_sqft check (
    area_sqft is null or area_sqft between 50 and 20000
  );

alter table public.properties drop constraint if exists properties_preferred_tenants;
alter table public.properties
  add constraint properties_preferred_tenants check (
    preferred_tenants <@ array['family', 'bachelors', 'female', 'any']::text[]
  );

alter table public.properties drop constraint if exists properties_floor_no;
alter table public.properties
  add constraint properties_floor_no check (
    floor_no is null or floor_no between 0 and 60
  );

alter table public.properties drop constraint if exists properties_total_floors;
alter table public.properties
  add constraint properties_total_floors check (
    total_floors is null or total_floors between 1 and 60
  );

alter table public.properties drop constraint if exists properties_floor_within;
alter table public.properties
  add constraint properties_floor_within check (
    floor_no is null or total_floors is null or floor_no <= total_floors
  );

comment on column public.properties.area_sqft is
  'Built-up area in square feet. Null when the host has not entered it.';
comment on column public.properties.preferred_tenants is
  'Who the host will consider: family, bachelors, female, any. Not a protected-class score.';

grant insert (
  area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
  gated_society, floor_no, total_floors
) on public.properties to authenticated;
grant update (
  area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
  gated_society, floor_no, total_floors
) on public.properties to authenticated;

create table if not exists public.listing_views (
  viewer_id uuid not null references public.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  viewed_on date not null,
  created_at timestamptz not null default now(),
  primary key (viewer_id, property_id, viewed_on)
);

comment on table public.listing_views is
  'One row per viewer, listing, and India-calendar day. Aggregates do not return viewer ids.';

create index if not exists listing_views_property_day_idx
  on public.listing_views (property_id, viewed_on);

alter table public.listing_views enable row level security;

drop policy if exists listing_views_select_own on public.listing_views;
create policy listing_views_select_own on public.listing_views
  for select to authenticated
  using (viewer_id = auth.uid());

revoke all on public.listing_views from anon, authenticated;
grant select on public.listing_views to authenticated;

create or replace function public.record_listing_view(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_viewer uuid := auth.uid();
  v_host uuid;
  v_status public.listing_status;
  v_day date := (timezone('Asia/Kolkata', now()))::date;
begin
  if v_viewer is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select host_user_id, status into v_host, v_status
  from public.properties
  where id = p_property_id;
  if v_host is null or v_status is distinct from 'published' then
    return jsonb_build_object('ok', false, 'error', 'not_visible');
  end if;
  if v_host = v_viewer then
    return jsonb_build_object('ok', true, 'recorded', false);
  end if;
  insert into public.listing_views (viewer_id, property_id, viewed_on)
  values (v_viewer, p_property_id, v_day)
  on conflict (viewer_id, property_id, viewed_on) do nothing;
  return jsonb_build_object('ok', true, 'recorded', true);
end;
$$;

create or replace function public.get_listing_view_counts(p_property_ids uuid[])
returns table (property_id uuid, views_today integer, views_total integer)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    coalesce(sum(
      case
        when v.viewed_on = (timezone('Asia/Kolkata', now()))::date
          or v.viewed_on = current_date then 1
        else 0
      end
    ), 0)::integer as views_today,
    coalesce(count(v.property_id), 0)::integer as views_total
  from unnest(coalesce(p_property_ids, array[]::uuid[])) as ids(id)
  join public.properties p
    on p.id = ids.id
   and p.status = 'published'
  left join public.listing_views v on v.property_id = p.id
  group by p.id;
$$;

comment on function public.get_listing_view_counts(uuid[]) is
  'Aggregate view counts for published homes. The result has no viewer id.';

revoke all on function public.record_listing_view(uuid) from public, anon;
grant execute on function public.record_listing_view(uuid) to authenticated;
revoke all on function public.get_listing_view_counts(uuid[]) from public;
grant execute on function public.get_listing_view_counts(uuid[]) to anon, authenticated;

create table if not exists public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  label text not null,
  city text,
  locality text,
  filters jsonb not null default '{}'::jsonb,
  last_checked_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint saved_searches_label_len check (char_length(label) between 1 and 80),
  constraint saved_searches_filters_obj check (
    jsonb_typeof(filters) = 'object'
    and not (
      filters ? 'phone'
      or filters ? 'email'
      or filters ? 'aadhaar'
      or filters ? 'address_line'
      or filters ? 'landmark'
      or filters ? 'latitude'
      or filters ? 'longitude'
    )
  )
);

comment on table public.saved_searches is
  'A person''s saved explore filters. New-since-last-check counts published homes only.';

alter table public.saved_searches enable row level security;

drop policy if exists saved_searches_own on public.saved_searches;
create policy saved_searches_own on public.saved_searches
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.saved_searches to authenticated;

create table if not exists public.recent_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  city text,
  locality text,
  query text not null default '',
  created_at timestamptz not null default now(),
  constraint recent_searches_query_len check (char_length(query) <= 80),
  constraint recent_searches_has_text check (
    char_length(btrim(query)) > 0
    or char_length(btrim(coalesce(locality, ''))) > 0
  ),
  constraint recent_searches_plain check (
    position('@' in query) = 0
    and query !~ '\+91'
  )
);

comment on table public.recent_searches is
  'Recent locality and text searches for the signed-in person. Own rows only.';

alter table public.recent_searches enable row level security;

drop policy if exists recent_searches_own on public.recent_searches;
create policy recent_searches_own on public.recent_searches
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.recent_searches to authenticated;

create table if not exists public.photo_requests (
  requester_id uuid not null references public.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  requested_on date not null,
  created_at timestamptz not null default now(),
  primary key (requester_id, property_id, requested_on)
);

comment on table public.photo_requests is
  'One photo request per person, listing, and India-calendar day.';

alter table public.photo_requests enable row level security;

drop policy if exists photo_requests_select_own on public.photo_requests;
create policy photo_requests_select_own on public.photo_requests
  for select to authenticated
  using (requester_id = auth.uid());

revoke all on public.photo_requests from anon, authenticated;
grant select on public.photo_requests to authenticated;

alter table public.notifications drop constraint if exists notifications_type;
alter table public.notifications
  add constraint notifications_type check (
    type in (
      'match',
      'message',
      'visit_requested',
      'visit_accepted',
      'visit_declined',
      'visit_cancelled',
      'listing_interest',
      'photo_request'
    )
  );

create or replace function public.enqueue_notification(
  p_user_id uuid,
  p_type text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;
  if p_type not in (
    'match',
    'message',
    'visit_requested',
    'visit_accepted',
    'visit_declined',
    'visit_cancelled',
    'listing_interest',
    'photo_request'
  ) then
    return;
  end if;
  if p_type in ('listing_interest', 'photo_request') then
    if not (
      p_payload ? 'property_id'
      and (p_payload - 'property_id') = '{}'::jsonb
    ) then
      return;
    end if;
  elsif p_payload ? 'property_id' or not (p_payload ? 'match_id') then
    return;
  end if;
  if not public.notification_payload_ok(p_payload) then
    return;
  end if;
  insert into public.notifications (user_id, type, payload_minimal)
  values (p_user_id, p_type, p_payload);
end;
$$;

create or replace function public.request_listing_photos(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_requester uuid := auth.uid();
  v_host uuid;
  v_status public.listing_status;
  v_photos integer;
  v_day date := (timezone('Asia/Kolkata', now()))::date;
begin
  if v_requester is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select host_user_id, status into v_host, v_status
  from public.properties
  where id = p_property_id;
  if v_host is null or v_status is distinct from 'published' then
    return jsonb_build_object('ok', false, 'error', 'not_visible');
  end if;
  if v_host = v_requester then
    return jsonb_build_object('ok', false, 'error', 'self');
  end if;
  select count(*)::integer into v_photos
  from public.property_photos
  where property_id = p_property_id
    and moderation_status <> 'rejected';
  if coalesce(v_photos, 0) >= 3 then
    return jsonb_build_object('ok', false, 'error', 'enough_photos');
  end if;
  if exists (
    select 1
    from public.photo_requests
    where requester_id = v_requester
      and property_id = p_property_id
      and requested_on = v_day
  ) then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into public.photo_requests (requester_id, property_id, requested_on)
  values (v_requester, p_property_id, v_day);
  perform public.enqueue_notification(
    v_host,
    'photo_request',
    jsonb_build_object('property_id', p_property_id)
  );
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.request_listing_photos(uuid) from public, anon;
grant execute on function public.request_listing_photos(uuid) to authenticated;

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
        and p.property_type = 'studio'
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
            and (f.value)::integer >= 3
        )
      )
    );
  return coalesce(v_count, 0);
end;
$$;

revoke all on function public.saved_search_new_count(uuid) from public, anon;
grant execute on function public.saved_search_new_count(uuid) to authenticated;
