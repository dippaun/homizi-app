-- Server-authoritative publish guard for listings.
-- An incomplete listing cannot move to published through the Data API,
-- including a direct status update. Seed scripts have no JWT role claim,
-- so they can still insert the staging catalog.
-- get_precise_address returns a street line only to the host or after an
-- accepted visit. It never returns a phone or an email.

create or replace function public.listing_publish_issue(
  p_title text,
  p_locality text,
  p_city text,
  p_rent_inr integer,
  p_property_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_usable integer;
  v_primary public.photo_type;
  v_out_of_order integer;
begin
  if char_length(btrim(coalesce(p_title, ''))) < 3
     or char_length(btrim(coalesce(p_locality, ''))) < 1
     or char_length(btrim(coalesce(p_city, ''))) < 1
     or coalesce(p_rent_inr, 0) <= 0 then
    return 'incomplete';
  end if;

  select count(*)::integer into v_usable
  from public.property_photos
  where property_id = p_property_id
    and moderation_status <> 'rejected';
  if coalesce(v_usable, 0) < 3 then
    return 'photos';
  end if;

  select photo_type into v_primary
  from public.property_photos
  where property_id = p_property_id
    and sort_order = 0
    and moderation_status <> 'rejected';
  if v_primary is null
     or v_primary not in ('living', 'bedroom', 'kitchen', 'bathroom') then
    return 'photo_order';
  end if;

  select count(*)::integer into v_out_of_order
  from public.property_photos earlier
  join public.property_photos later
    on later.property_id = earlier.property_id
   and later.sort_order > earlier.sort_order
  where earlier.property_id = p_property_id
    and earlier.moderation_status <> 'rejected'
    and later.moderation_status <> 'rejected'
    and earlier.photo_type in ('exterior', 'other')
    and later.photo_type in ('living', 'bedroom', 'kitchen', 'bathroom');
  if coalesce(v_out_of_order, 0) > 0 then
    return 'photo_order';
  end if;

  return null;
end;
$$;

create or replace function public.properties_guard_publish()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
  v_issue text;
begin
  if v_role not in ('anon', 'authenticated', 'service_role') then
    return new;
  end if;
  if new.status is distinct from 'published'::public.listing_status then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status = 'published'::public.listing_status then
    return new;
  end if;
  v_issue := public.listing_publish_issue(
    new.title,
    new.locality,
    new.city,
    new.rent_inr,
    new.id
  );
  if v_issue is not null then
    raise exception 'listing_incomplete'
      using errcode = '23514';
  end if;
  if new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists properties_guard_publish on public.properties;
create trigger properties_guard_publish
  before insert or update of status on public.properties
  for each row
  execute function public.properties_guard_publish();

create or replace function public.publish_listing(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_property public.properties;
  v_issue text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_property from public.properties where id = p_property_id;
  if not found or v_property.host_user_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  v_issue := public.listing_publish_issue(
    v_property.title,
    v_property.locality,
    v_property.city,
    v_property.rent_inr,
    p_property_id
  );
  if v_issue is not null then
    return jsonb_build_object('ok', false, 'error', v_issue);
  end if;
  update public.properties
  set status = 'published',
      published_at = coalesce(published_at, now())
  where id = p_property_id;
  return jsonb_build_object('ok', true, 'property_id', p_property_id);
end;
$$;

create or replace function public.publish_requirement(p_requirement_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.listing_requirements;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_row from public.listing_requirements where id = p_requirement_id;
  if not found or v_row.user_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if v_row.budget_min_inr > v_row.budget_max_inr
     or char_length(btrim(v_row.city)) < 1
     or coalesce(cardinality(v_row.localities), 0) < 1
     or exists (
       select 1
       from unnest(v_row.localities) as loc
       where char_length(btrim(loc)) < 1
     ) then
    return jsonb_build_object('ok', false, 'error', 'incomplete');
  end if;
  update public.listing_requirements
  set status = 'published'
  where id = p_requirement_id;
  return jsonb_build_object('ok', true, 'requirement_id', p_requirement_id);
end;
$$;

create or replace function public.get_precise_address(p_property_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_property public.properties;
  v_private public.property_private_details;
  v_agreed boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated', 'revealed', false);
  end if;
  select * into v_property from public.properties where id = p_property_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found', 'revealed', false);
  end if;
  if v_property.host_user_id <> v_uid
     and (
       v_property.status <> 'published'
       or public.is_blocked_with(v_property.host_user_id)
     ) then
    return jsonb_build_object('ok', false, 'error', 'not_found', 'revealed', false);
  end if;

  if v_property.host_user_id = v_uid then
    v_agreed := true;
  else
    select exists (
      select 1
      from public.visit_requests v
      join public.matches m on m.id = v.match_id
      where v.status in ('accepted', 'completed')
        and m.status = 'active'
        and (
          (m.participant_a = v_uid and m.participant_b = v_property.host_user_id)
          or (m.participant_b = v_uid and m.participant_a = v_property.host_user_id)
        )
    ) into v_agreed;
  end if;

  if not v_agreed then
    return jsonb_build_object('ok', true, 'revealed', false);
  end if;

  select * into v_private
  from public.property_private_details
  where property_id = p_property_id;
  if not found
     or v_private.address_line is null
     or char_length(btrim(v_private.address_line)) < 1 then
    return jsonb_build_object('ok', true, 'revealed', false);
  end if;

  return jsonb_build_object(
    'ok', true,
    'revealed', true,
    'address_line', v_private.address_line,
    'landmark', v_private.landmark
  );
end;
$$;

comment on function public.listing_publish_issue(text, text, text, integer, uuid) is
  'Why a listing cannot be published. Null means the row is complete. No contact fields.';

comment on function public.properties_guard_publish() is
  'Blocks Data API inserts and status updates that would publish an incomplete listing.';

comment on function public.get_precise_address(uuid) is
  'Street line for the host, or after an accepted visit. Never returns phone or email.';

revoke all on function public.listing_publish_issue(text, text, text, integer, uuid)
  from public, anon, authenticated;
revoke all on function public.properties_guard_publish()
  from public, anon, authenticated;
revoke all on function public.publish_listing(uuid) from public, anon;
revoke all on function public.publish_requirement(uuid) from public, anon;
revoke all on function public.get_precise_address(uuid) from public, anon;
grant execute on function public.publish_listing(uuid) to authenticated;
grant execute on function public.publish_requirement(uuid) to authenticated;
grant execute on function public.get_precise_address(uuid) to authenticated;
