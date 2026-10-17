-- Public map points are locality-level. Exact coordinates stay on
-- property_private_details and leave get_precise_address only for the host
-- or after an accepted visit.

alter table public.properties
  add column if not exists approx_latitude numeric(6, 3),
  add column if not exists approx_longitude numeric(6, 3);

alter table public.properties
  drop constraint if exists properties_approx_pair;
alter table public.properties
  add constraint properties_approx_pair check (
    (approx_latitude is null and approx_longitude is null)
    or (
      approx_latitude is not null
      and approx_longitude is not null
      and approx_latitude between 6 and 37
      and approx_longitude between 68 and 98
    )
  );

comment on column public.properties.approx_latitude is
  'Public locality centre, snapped to 3 decimals. Not a building point.';
comment on column public.properties.approx_longitude is
  'Public locality centre, snapped to 3 decimals. Not a building point.';

create or replace function public.properties_snap_approx()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.approx_latitude is not null then
    new.approx_latitude := round(new.approx_latitude, 3);
  end if;
  if new.approx_longitude is not null then
    new.approx_longitude := round(new.approx_longitude, 3);
  end if;
  return new;
end;
$$;

drop trigger if exists properties_snap_approx on public.properties;
create trigger properties_snap_approx
  before insert or update of approx_latitude, approx_longitude
  on public.properties
  for each row execute function public.properties_snap_approx();

revoke all on function public.properties_snap_approx() from public, anon, authenticated;

grant insert (approx_latitude, approx_longitude)
  on public.properties to authenticated;
grant update (approx_latitude, approx_longitude)
  on public.properties to authenticated;

-- Backfill rows that already exist on a database seeded before this migration.
update public.properties
set approx_latitude = 12.935, approx_longitude = 77.624
where id = '22222222-2222-4222-8222-222222222201'
  and approx_latitude is null;

update public.properties
set approx_latitude = 18.559, approx_longitude = 73.787
where id = '22222222-2222-4222-8222-222222222202'
  and approx_latitude is null;

update public.property_private_details
set latitude = 12.935812, longitude = 77.625104
where property_id = '22222222-2222-4222-8222-222222222201'
  and latitude is null;

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
  v_payload jsonb;
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

  v_payload := jsonb_build_object(
    'ok', true,
    'revealed', true,
    'address_line', v_private.address_line,
    'landmark', v_private.landmark
  );
  if v_private.latitude is not null then
    v_payload := v_payload || jsonb_build_object('latitude', v_private.latitude);
  end if;
  if v_private.longitude is not null then
    v_payload := v_payload || jsonb_build_object('longitude', v_private.longitude);
  end if;
  return v_payload;
end;
$$;

comment on function public.get_precise_address(uuid) is
  'Street line and exact coordinates for the host, or after an accepted visit. Hidden payloads omit latitude and longitude. Never returns phone or email.';

revoke all on function public.get_precise_address(uuid) from public, anon;
grant execute on function public.get_precise_address(uuid) to authenticated;
