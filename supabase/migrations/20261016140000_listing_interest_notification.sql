-- A like on a published listing notifies the host. The payload is the
-- property id only. Phone, email, and street address stay out.

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
      'listing_interest'
    )
  );

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
  ) then
    return false;
  end if;
  if p_payload ? 'property_id' then
    if (p_payload - 'property_id') <> '{}'::jsonb then
      return false;
    end if;
    return (p_payload ->> 'property_id') ~ v_uuid;
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
    'listing_interest'
  ) then
    return;
  end if;
  if p_type = 'listing_interest' then
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

create or replace function public.notify_on_interest()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_host uuid;
begin
  if new.action is distinct from 'like'
     or new.target_type is distinct from 'property' then
    return new;
  end if;
  select host_user_id
    into v_host
  from public.properties
  where id = new.target_id
    and status = 'published';
  if v_host is null or v_host = new.actor_user_id then
    return new;
  end if;
  perform public.enqueue_notification(
    v_host,
    'listing_interest',
    jsonb_build_object('property_id', new.target_id)
  );
  return new;
end;
$$;

drop trigger if exists notifications_on_interest on public.interests;
create trigger notifications_on_interest
  after insert on public.interests
  for each row
  execute function public.notify_on_interest();

revoke all on function public.enqueue_notification(uuid, text, jsonb) from public;
revoke all on function public.notify_on_interest() from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.enqueue_notification(uuid, text, jsonb) from anon;
    revoke all on function public.notify_on_interest() from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    revoke all on function public.enqueue_notification(uuid, text, jsonb) from authenticated;
    revoke all on function public.notify_on_interest() from authenticated;
  end if;
end $$;
