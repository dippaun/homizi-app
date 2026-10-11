-- In-app notifications for matches, messages, and visits.
-- Clients may read their own rows and set read_at. They cannot insert a
-- notification or change its type or payload. Payloads are ids only.

-- Ids only. A UUID can contain a long digit run, so the check is the UUID
-- shape rather than a phone-number scan of the whole value.
alter table public.notifications
  drop constraint if exists notifications_payload;
alter table public.notifications
  add constraint notifications_payload check (
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
      'visit_cancelled'
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
    if v_value !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      return false;
    end if;
  end loop;
  return p_payload ? 'match_id';
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
    'visit_cancelled'
  ) then
    return;
  end if;
  if not public.notification_payload_ok(p_payload) then
    return;
  end if;
  insert into public.notifications (user_id, type, payload_minimal)
  values (p_user_id, p_type, p_payload);
end;
$$;

create or replace function public.notify_on_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payload jsonb;
begin
  if new.status <> 'active' then
    return new;
  end if;
  v_payload := jsonb_build_object('match_id', new.id);
  perform public.enqueue_notification(new.participant_a, 'match', v_payload);
  perform public.enqueue_notification(new.participant_b, 'match', v_payload);
  return new;
end;
$$;

create or replace function public.notify_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_id uuid;
  v_a uuid;
  v_b uuid;
  v_recipient uuid;
begin
  if new.status <> 'sent' then
    return new;
  end if;
  select c.match_id, m.participant_a, m.participant_b
    into v_match_id, v_a, v_b
  from public.conversations c
  join public.matches m on m.id = c.match_id
  where c.id = new.conversation_id;
  if v_match_id is null then
    return new;
  end if;
  v_recipient := case
    when new.sender_id = v_a then v_b
    else v_a
  end;
  if v_recipient = new.sender_id then
    return new;
  end if;
  perform public.enqueue_notification(
    v_recipient,
    'message',
    jsonb_build_object(
      'match_id', v_match_id,
      'conversation_id', new.conversation_id
    )
  );
  return new;
end;
$$;

create or replace function public.notify_on_visit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_a uuid;
  v_b uuid;
  v_other uuid;
  v_type text;
  v_recipient uuid;
begin
  select participant_a, participant_b
    into v_a, v_b
  from public.matches
  where id = new.match_id;
  if v_a is null then
    return new;
  end if;
  v_other := case
    when new.requester_id = v_a then v_b
    else v_a
  end;

  if tg_op = 'INSERT' then
    perform public.enqueue_notification(
      v_other,
      'visit_requested',
      jsonb_build_object('match_id', new.match_id, 'visit_id', new.id)
    );
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;
  end if;
  v_type := case new.status
    when 'accepted' then 'visit_accepted'
    when 'declined' then 'visit_declined'
    when 'cancelled' then 'visit_cancelled'
    else null
  end;
  if v_type is null then
    return new;
  end if;
  v_recipient := case
    when new.status = 'cancelled' then v_other
    else new.requester_id
  end;
  perform public.enqueue_notification(
    v_recipient,
    v_type,
    jsonb_build_object('match_id', new.match_id, 'visit_id', new.id)
  );
  return new;
end;
$$;

drop trigger if exists notifications_on_match on public.matches;
create trigger notifications_on_match
  after insert on public.matches
  for each row
  execute function public.notify_on_match();

drop trigger if exists notifications_on_message on public.messages;
create trigger notifications_on_message
  after insert on public.messages
  for each row
  execute function public.notify_on_message();

drop trigger if exists notifications_on_visit on public.visit_requests;
create trigger notifications_on_visit
  after insert or update of status on public.visit_requests
  for each row
  execute function public.notify_on_visit();

insert into public.notifications (user_id, type, payload_minimal)
select m.participant_a, 'match', jsonb_build_object('match_id', m.id)
from public.matches m
where m.status = 'active'
  and not exists (
    select 1
    from public.notifications n
    where n.user_id = m.participant_a
      and n.type = 'match'
      and n.payload_minimal ->> 'match_id' = m.id::text
  )
union all
select m.participant_b, 'match', jsonb_build_object('match_id', m.id)
from public.matches m
where m.status = 'active'
  and not exists (
    select 1
    from public.notifications n
    where n.user_id = m.participant_b
      and n.type = 'match'
      and n.payload_minimal ->> 'match_id' = m.id::text
  );

revoke all on function public.notification_payload_ok(jsonb) from public, anon, authenticated;
revoke all on function public.enqueue_notification(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.notify_on_match() from public, anon, authenticated;
revoke all on function public.notify_on_message() from public, anon, authenticated;
revoke all on function public.notify_on_visit() from public, anon, authenticated;

grant execute on function public.notification_payload_ok(jsonb) to authenticated;
