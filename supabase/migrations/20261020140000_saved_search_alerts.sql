-- In-app notice when a newly published home matches a saved search.
-- The notification payload is the saved-search id only. No title, phone,
-- email, or address. The listings preference can turn the notice off.
-- This does not call Firebase or send-push. Unknown push types stay refused.
-- Recently viewed rows stay private. Clear deletes only the signed-in person.

alter table public.notifications
  drop constraint if exists notifications_payload;
alter table public.notifications
  add constraint notifications_payload check (
    (
      jsonb_typeof(payload_minimal) = 'object'
      and payload_minimal ? 'match_id'
      and (payload_minimal - 'match_id' - 'visit_id' - 'conversation_id')
        = '{}'::jsonb
      and (payload_minimal ->> 'match_id')
        ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      and (
        not (payload_minimal ? 'visit_id')
        or (payload_minimal ->> 'visit_id')
          ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      )
      and (
        not (payload_minimal ? 'conversation_id')
        or (payload_minimal ->> 'conversation_id')
          ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      )
    )
    or (
      jsonb_typeof(payload_minimal) = 'object'
      and (payload_minimal - 'property_id') = '{}'::jsonb
      and (payload_minimal ->> 'property_id')
        ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    )
    or (
      jsonb_typeof(payload_minimal) = 'object'
      and (payload_minimal - 'deposit_id') = '{}'::jsonb
      and (payload_minimal ->> 'deposit_id')
        ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    )
    or (
      jsonb_typeof(payload_minimal) = 'object'
      and (payload_minimal - 'saved_search_id') = '{}'::jsonb
      and (payload_minimal ->> 'saved_search_id')
        ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    )
  );

alter table public.notifications
  drop constraint if exists notifications_type;
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
      'photo_request',
      'deposit_reminder',
      'saved_search_match'
    )
  );

create or replace function public.notification_category(p_type text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_type = 'match' then 'matches'
    when p_type = 'message' then 'chat'
    when p_type in (
      'visit_requested',
      'visit_accepted',
      'visit_declined',
      'visit_cancelled'
    ) then 'visits'
    when p_type in (
      'listing_interest',
      'photo_request',
      'saved_search_match'
    ) then 'listings'
    else 'system'
  end;
$$;

create or replace function public.notification_payload_ok(p_payload jsonb)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_key text;
  v_value text;
  v_type text;
  v_uuid text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return false;
  end if;
  if (
    p_payload ? 'phone'
    or p_payload ? 'email'
    or p_payload ? 'aadhaar'
    or p_payload ? 'address_line'
    or p_payload ? 'landmark'
    or p_payload ? 'latitude'
    or p_payload ? 'longitude'
    or p_payload ? 'street_address'
    or p_payload ? 'title'
  ) then
    return false;
  end if;
  if p_payload ? 'saved_search_id' then
    if (p_payload - 'saved_search_id') <> '{}'::jsonb then
      return false;
    end if;
    return (p_payload ->> 'saved_search_id') ~ v_uuid;
  end if;
  if p_payload ? 'property_id' then
    if (p_payload - 'property_id') <> '{}'::jsonb then
      return false;
    end if;
    return (p_payload ->> 'property_id') ~ v_uuid;
  end if;
  if p_payload ? 'deposit_id' then
    if (p_payload - 'deposit_id') <> '{}'::jsonb then
      return false;
    end if;
    return (p_payload ->> 'deposit_id') ~ v_uuid;
  end if;
  if not (p_payload ? 'match_id') then
    return false;
  end if;
  for v_key in select jsonb_object_keys(p_payload)
  loop
    if v_key not in ('match_id', 'visit_id', 'conversation_id') then
      return false;
    end if;
    v_type := jsonb_typeof(p_payload -> v_key);
    if v_type <> 'string' then
      return false;
    end if;
    v_value := p_payload ->> v_key;
    if v_value !~ v_uuid then
      return false;
    end if;
  end loop;
  return true;
end;
$$;

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
    'photo_request',
    'deposit_reminder',
    'saved_search_match'
  ) then
    return;
  end if;
  if not public.notification_allowed(p_user_id, p_type) then
    return;
  end if;
  if p_type = 'saved_search_match' then
    if not (
      p_payload ? 'saved_search_id'
      and (p_payload - 'saved_search_id') = '{}'::jsonb
    ) then
      return;
    end if;
  elsif p_type in ('listing_interest', 'photo_request') then
    if not (
      p_payload ? 'property_id'
      and (p_payload - 'property_id') = '{}'::jsonb
    ) then
      return;
    end if;
  elsif p_type = 'deposit_reminder' then
    if not (
      p_payload ? 'deposit_id'
      and (p_payload - 'deposit_id') = '{}'::jsonb
    ) then
      return;
    end if;
  elsif p_payload ? 'property_id'
    or p_payload ? 'deposit_id'
    or p_payload ? 'saved_search_id'
    or not (p_payload ? 'match_id') then
    return;
  end if;
  if not public.notification_payload_ok(p_payload) then
    return;
  end if;
  insert into public.notifications (user_id, type, payload_minimal)
  values (p_user_id, p_type, p_payload);
end;
$$;

create table if not exists public.saved_search_alert_log (
  saved_search_id uuid not null references public.saved_searches (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (saved_search_id, property_id)
);

comment on table public.saved_search_alert_log is
  'One in-app notice per saved search and newly published home. Clients cannot read it. The notice payload is the saved-search id only.';

alter table public.saved_search_alert_log enable row level security;

revoke all on table public.saved_search_alert_log from public, anon, authenticated;

create or replace function public.property_matches_saved_search(
  p_property_id uuid,
  p_search_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row public.saved_searches;
  v_filters jsonb;
  v_city text;
  v_locality text;
  v_hit boolean;
begin
  select * into v_row
  from public.saved_searches
  where id = p_search_id;
  if not found then
    return false;
  end if;
  v_filters := coalesce(v_row.filters, '{}'::jsonb);
  v_city := nullif(btrim(coalesce(v_row.city, v_filters ->> 'city', '')), '');
  v_locality := nullif(
    btrim(coalesce(v_row.locality, v_filters ->> 'locality', '')),
    ''
  );
  select exists (
    select 1
    from public.properties p
    where p.id = p_property_id
      and p.status = 'published'
      and p.published_at is not null
      and p.published_at > v_row.last_checked_at
      and (v_city is null or p.city = v_city)
      and (v_locality is null or lower(p.locality) = lower(v_locality))
      and (
        v_filters ->> 'budget_min_inr' is null
        or (
          (v_filters ->> 'budget_min_inr') ~ '^[0-9]+$'
          and p.rent_inr >= (v_filters ->> 'budget_min_inr')::integer
        )
      )
      and (
        v_filters ->> 'budget_max_inr' is null
        or (
          (v_filters ->> 'budget_max_inr') ~ '^[0-9]+$'
          and p.rent_inr <= (v_filters ->> 'budget_max_inr')::integer
        )
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
          (v_filters ->> 'area_min_sqft') ~ '^[0-9]+$'
          and p.area_sqft is not null
          and p.area_sqft >= (v_filters ->> 'area_min_sqft')::integer
        )
      )
      and (
        v_filters ->> 'area_max_sqft' is null
        or (
          (v_filters ->> 'area_max_sqft') ~ '^[0-9]+$'
          and p.area_sqft is not null
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
          (v_filters ->> 'floor_min') ~ '^[0-9]+$'
          and p.floor_no is not null
          and p.floor_no >= (v_filters ->> 'floor_min')::integer
        )
      )
      and (
        v_filters ->> 'floor_max' is null
        or (
          (v_filters ->> 'floor_max') ~ '^[0-9]+$'
          and p.floor_no is not null
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
        or (v_filters ->> 'move_in_by') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
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
      )
  ) into v_hit;
  return coalesce(v_hit, false);
exception
  when others then
    return false;
end;
$$;

comment on function public.property_matches_saved_search(uuid, uuid) is
  'True when a published home is newer than the saved search check and matches its filters. Same rules as saved_search_new_count.';

create or replace function public.notify_saved_searches_on_publish()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_search public.saved_searches;
  v_payload jsonb;
  v_inserted integer;
begin
  if new.status is distinct from 'published'::public.listing_status then
    return new;
  end if;
  if new.published_at is null then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and old.status = 'published'::public.listing_status
     and old.published_at is not distinct from new.published_at then
    return new;
  end if;

  for v_search in
    select *
    from public.saved_searches
  loop
    if not public.property_matches_saved_search(new.id, v_search.id) then
      continue;
    end if;
    if not public.notification_allowed(v_search.user_id, 'saved_search_match') then
      continue;
    end if;
    v_payload := jsonb_build_object('saved_search_id', v_search.id);
    if not public.notification_payload_ok(v_payload) then
      continue;
    end if;
    insert into public.saved_search_alert_log (saved_search_id, property_id)
    values (v_search.id, new.id)
    on conflict (saved_search_id, property_id) do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted = 0 then
      continue;
    end if;
    perform public.enqueue_notification(
      v_search.user_id,
      'saved_search_match',
      v_payload
    );
  end loop;
  return new;
end;
$$;

comment on function public.notify_saved_searches_on_publish() is
  'Inserts one in-app saved_search_match notice per matching saved search. Payload is the saved-search id. Does not call push.';

drop trigger if exists properties_saved_search_alerts on public.properties;
create trigger properties_saved_search_alerts
  after insert or update of status, published_at
  on public.properties
  for each row
  execute function public.notify_saved_searches_on_publish();

create or replace function public.clear_recently_viewed()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Sign in before clearing viewed homes.';
  end if;
  delete from public.listing_views
  where viewer_id = v_uid;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.clear_recently_viewed() is
  'Deletes listing_views for auth.uid() only. Another person''s history stays.';

revoke all on function public.notification_category(text) from public;
revoke all on function public.notification_payload_ok(jsonb) from public;
revoke all on function public.enqueue_notification(uuid, text, jsonb) from public;
revoke all on function public.property_matches_saved_search(uuid, uuid) from public;
revoke all on function public.notify_saved_searches_on_publish() from public;
revoke all on function public.clear_recently_viewed() from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.notification_category(text) from anon;
    revoke all on function public.notification_payload_ok(jsonb) from anon;
    revoke all on function public.enqueue_notification(uuid, text, jsonb) from anon;
    revoke all on function public.property_matches_saved_search(uuid, uuid) from anon;
    revoke all on function public.notify_saved_searches_on_publish() from anon;
    revoke all on function public.clear_recently_viewed() from anon;
    revoke all on table public.saved_search_alert_log from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    revoke all on function public.notification_category(text) from authenticated;
    revoke all on function public.enqueue_notification(uuid, text, jsonb) from authenticated;
    revoke all on function public.property_matches_saved_search(uuid, uuid) from authenticated;
    revoke all on function public.notify_saved_searches_on_publish() from authenticated;
    revoke all on table public.saved_search_alert_log from authenticated;
  end if;
end $$;

grant execute on function public.notification_payload_ok(jsonb) to authenticated;
grant execute on function public.clear_recently_viewed() to authenticated;
