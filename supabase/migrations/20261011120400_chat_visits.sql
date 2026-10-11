-- Chat and visit requests on the existing tables.
-- Clients can read a thread they belong to. They cannot put a phone number or
-- an email in a message, and they cannot set message or visit status themselves.

create or replace function public.contains_contact_text(p_body text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_lower text := lower(coalesce(p_body, ''));
  v_compact text;
begin
  if v_lower ~ '[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}' then
    return true;
  end if;
  v_compact := regexp_replace(v_lower, '[[:space:]\-().]', '', 'g');
  return v_compact ~ '(^|[^0-9])[0-9]{10,}([^0-9]|$)';
end;
$$;

alter table public.messages
  drop constraint if exists messages_no_contact;
alter table public.messages
  add constraint messages_no_contact
  check (not public.contains_contact_text(body));

create or replace function public.visit_slots_ok(p_slots jsonb)
returns boolean
language plpgsql
stable
set search_path = public
as $$
declare
  v_item jsonb;
  v_key text;
  v_count integer;
begin
  if p_slots is null or jsonb_typeof(p_slots) <> 'array' then
    return false;
  end if;
  v_count := jsonb_array_length(p_slots);
  if v_count < 1 or v_count > 3 then
    return false;
  end if;
  for v_item in select value from jsonb_array_elements(p_slots)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      return false;
    end if;
    if (select count(*) from jsonb_object_keys(v_item)) <> 1 then
      return false;
    end if;
    if not (v_item ? 'starts_at') then
      return false;
    end if;
    for v_key in select jsonb_object_keys(v_item)
    loop
      if v_key <> 'starts_at' then
        return false;
      end if;
    end loop;
    if public.contains_contact_text(v_item ->> 'starts_at') then
      return false;
    end if;
    begin
      perform (v_item ->> 'starts_at')::timestamptz;
    exception
      when others then
        return false;
    end;
  end loop;
  return true;
end;
$$;

create or replace function public.visit_requests_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.status := 'requested';
  end if;
  if not public.visit_slots_ok(new.proposed_slots) then
    raise exception 'visit slots cannot include contact details'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists visit_requests_guard on public.visit_requests;
create trigger visit_requests_guard
  before insert or update on public.visit_requests
  for each row
  execute function public.visit_requests_guard();

create or replace function public.open_conversation_for_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.conversations (match_id)
  values (new.id)
  on conflict (match_id) do nothing;
  return new;
end;
$$;

drop trigger if exists matches_open_conversation on public.matches;
create trigger matches_open_conversation
  after insert on public.matches
  for each row
  execute function public.open_conversation_for_match();

insert into public.conversations (match_id)
select m.id
from public.matches m
where not exists (
  select 1 from public.conversations c where c.match_id = m.id
);

create or replace function public.open_conversation(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_match from public.matches where id = p_match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;
  insert into public.conversations (match_id)
  values (p_match_id)
  on conflict (match_id) do nothing;
  select id into v_id from public.conversations where match_id = p_match_id;
  return jsonb_build_object('ok', true, 'conversation_id', v_id);
end;
$$;

create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_body text := trim(coalesce(p_body, ''));
  v_conversation public.conversations;
  v_match public.matches;
  v_other uuid;
  v_id uuid;
  v_created timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 4000 then
    return jsonb_build_object('ok', false, 'error', 'body');
  end if;
  if public.contains_contact_text(v_body) then
    return jsonb_build_object('ok', false, 'error', 'contact');
  end if;
  select * into v_conversation
  from public.conversations
  where id = p_conversation_id;
  if not found or v_conversation.status <> 'open' then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  select * into v_match from public.matches where id = v_conversation.match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;
  insert into public.messages (conversation_id, sender_id, body)
  values (p_conversation_id, v_uid, v_body)
  returning id, created_at into v_id, v_created;
  return jsonb_build_object(
    'ok', true,
    'message_id', v_id,
    'created_at', v_created
  );
end;
$$;

create or replace function public.request_visit(
  p_match_id uuid,
  p_slots jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public.visit_slots_ok(p_slots) then
    return jsonb_build_object('ok', false, 'error', 'slots');
  end if;
  select * into v_match from public.matches where id = p_match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;
  insert into public.visit_requests (match_id, requester_id, proposed_slots)
  values (p_match_id, v_uid, p_slots)
  returning id into v_id;
  return jsonb_build_object(
    'ok', true,
    'visit_id', v_id,
    'status', 'requested'
  );
end;
$$;

create or replace function public.respond_visit(
  p_visit_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_visit public.visit_requests;
  v_match public.matches;
  v_next public.visit_status;
  v_updated integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_status not in ('accepted', 'declined', 'cancelled') then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  select * into v_visit from public.visit_requests where id = p_visit_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  select * into v_match from public.matches where id = v_visit.match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  if v_visit.status <> 'requested' then
    return jsonb_build_object('ok', false, 'error', 'closed');
  end if;
  if p_status = 'cancelled' and v_uid <> v_visit.requester_id then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  if p_status in ('accepted', 'declined') and v_uid = v_visit.requester_id then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  v_next := p_status::public.visit_status;
  update public.visit_requests
  set status = v_next
  where id = p_visit_id
    and status = 'requested';
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    return jsonb_build_object('ok', false, 'error', 'closed');
  end if;
  return jsonb_build_object(
    'ok', true,
    'visit_id', p_visit_id,
    'status', p_status
  );
end;
$$;

comment on function public.send_message(uuid, text) is
  'Stores a chat message for an active match. Refuses phone numbers and email addresses. Does not return contact fields.';
comment on function public.request_visit(uuid, jsonb) is
  'Creates a visit request with one to three start times. Slots cannot carry contact fields or a street address.';
comment on function public.respond_visit(uuid, text) is
  'The other participant accepts or declines. The requester can cancel. No address is returned.';

revoke insert on public.messages from authenticated;
grant insert (conversation_id, sender_id, body)
  on public.messages to authenticated;

revoke insert, update on public.visit_requests from authenticated;

revoke all on function public.contains_contact_text(text) from public, anon;
revoke all on function public.visit_slots_ok(jsonb) from public, anon;
revoke all on function public.open_conversation(uuid) from public, anon;
revoke all on function public.send_message(uuid, text) from public, anon;
revoke all on function public.request_visit(uuid, jsonb) from public, anon;
revoke all on function public.respond_visit(uuid, text) from public, anon;

grant execute on function public.contains_contact_text(text) to authenticated;
grant execute on function public.visit_slots_ok(jsonb) to authenticated;
grant execute on function public.open_conversation(uuid) to authenticated;
grant execute on function public.send_message(uuid, text) to authenticated;
grant execute on function public.request_visit(uuid, jsonb) to authenticated;
grant execute on function public.respond_visit(uuid, text) to authenticated;

drop policy if exists messages_select_member on public.messages;
create policy messages_select_member on public.messages
  for select to authenticated
  using (
    status = 'sent'
    and exists (
      select 1
      from public.conversations c
      join public.matches m on m.id = c.match_id
      where c.id = conversation_id
        and c.status = 'open'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
        and not public.is_blocked_with(
          case
            when m.participant_a = auth.uid() then m.participant_b
            else m.participant_a
          end
        )
    )
  );
