-- HOMIZI account, match, consent, and visit follow-up.
-- Paste this whole file into the dashboard SQL editor after
-- docs/staging_apply.sql and docs/staging_apply_next.sql.
-- Running it again is safe: the column add is guarded, functions are
-- replaced, and the migration version row is upserted.
-- No phone, email, or street address is inserted.
--
-- Applies supabase/migrations/20261017120000_visit_lifecycle_contact.sql.
--
-- The client calls, in order, for account deletion:
--   storage.from('listing-photos').list / remove
--   rpc('delete_own_account')
--   auth.signOut()
-- Visit address is rpc('get_visit_address') and only after acceptance.

-- Visit state machine, address after acceptance, and contact-key omission.
-- delete_own_account also reports whether listing-photos objects were removed.
--
-- The app calls:
--   propose_visit_time(visit_id, slots)
--   respond_visit(visit_id, accepted|declined|cancelled|completed)
--   get_visit_address(visit_id)  -- address_line only after accepted or completed
--   get_contact_visibility(match_id) -- phone/email keys omitted unless granted
--   delete_own_account() after storage remove, then auth.signOut()

alter table public.visit_requests
  add column if not exists property_id uuid references public.properties (id) on delete set null;

create or replace function public._link_visit_property(p_match public.matches)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_count integer;
begin
  select count(*) into v_count
  from public.properties p
  where p.status = 'published'
    and p.host_user_id in (p_match.participant_a, p_match.participant_b)
    and p.address_visibility in ('after_visit_accept', 'after_match');
  if v_count <> 1 then
    return null;
  end if;
  select p.id into v_id
  from public.properties p
  where p.status = 'published'
    and p.host_user_id in (p_match.participant_a, p_match.participant_b)
    and p.address_visibility in ('after_visit_accept', 'after_match');
  return v_id;
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
  v_property uuid;
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
  v_property := public._link_visit_property(v_match);
  insert into public.visit_requests (
    match_id, requester_id, proposed_slots, property_id
  )
  values (p_match_id, v_uid, p_slots, v_property)
  returning id into v_id;
  return jsonb_build_object(
    'ok', true,
    'visit_id', v_id,
    'status', 'requested'
  );
end;
$$;

create or replace function public.propose_visit_time(
  p_visit_id uuid,
  p_slots jsonb
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
  v_other uuid;
  v_next public.visit_status;
  v_updated integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public.visit_slots_ok(p_slots) then
    return jsonb_build_object('ok', false, 'error', 'slots');
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
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;
  if v_visit.status not in ('requested', 'rescheduled') then
    return jsonb_build_object('ok', false, 'error', 'closed');
  end if;
  v_next := case
    when v_uid = v_visit.requester_id then 'requested'::public.visit_status
    else 'rescheduled'::public.visit_status
  end;
  update public.visit_requests
  set proposed_slots = p_slots,
      status = v_next
  where id = p_visit_id
    and status in ('requested', 'rescheduled');
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    return jsonb_build_object('ok', false, 'error', 'closed');
  end if;
  return jsonb_build_object(
    'ok', true,
    'visit_id', p_visit_id,
    'status', v_next
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
  v_allowed boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_status not in ('accepted', 'declined', 'cancelled', 'completed') then
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
  if p_status = 'completed' then
    v_allowed := v_visit.status = 'accepted';
  elsif v_visit.status = 'requested' then
    v_allowed := (p_status = 'cancelled' and v_uid = v_visit.requester_id)
      or (p_status in ('accepted', 'declined') and v_uid <> v_visit.requester_id);
  elsif v_visit.status = 'rescheduled' then
    v_allowed := v_uid = v_visit.requester_id
      and p_status in ('accepted', 'declined', 'cancelled');
  end if;
  if not v_allowed then
    if v_visit.status in ('requested', 'rescheduled', 'accepted') then
      return jsonb_build_object('ok', false, 'error', 'not_allowed');
    end if;
    return jsonb_build_object('ok', false, 'error', 'closed');
  end if;
  v_next := p_status::public.visit_status;
  update public.visit_requests
  set status = v_next
  where id = p_visit_id
    and status = v_visit.status;
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

create or replace function public.get_visit_address(p_visit_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_visit public.visit_requests;
  v_match public.matches;
  v_other uuid;
  v_property_id uuid;
  v_visibility public.address_visibility;
  v_line text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'visible', false, 'reason', 'unauthenticated');
  end if;
  select * into v_visit from public.visit_requests where id = p_visit_id;
  if not found then
    return jsonb_build_object('ok', true, 'visible', false, 'reason', 'not_found');
  end if;
  select * into v_match from public.matches where id = v_visit.match_id;
  if not found
     or v_match.status <> 'active'
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('ok', true, 'visible', false, 'reason', 'not_found');
  end if;
  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;
  if public.is_blocked_with(v_other) then
    return jsonb_build_object('ok', true, 'visible', false, 'reason', 'blocked');
  end if;
  if v_visit.status not in ('accepted', 'completed') then
    return jsonb_build_object('ok', true, 'visible', false, 'reason', 'not_accepted');
  end if;
  v_property_id := coalesce(v_visit.property_id, public._link_visit_property(v_match));
  if v_property_id is null then
    return jsonb_build_object('ok', true, 'visible', false, 'reason', 'no_address');
  end if;
  select p.address_visibility into v_visibility
  from public.properties p
  where p.id = v_property_id
    and p.status = 'published';
  if v_visibility is null or v_visibility = 'locality_only' then
    return jsonb_build_object('ok', true, 'visible', false, 'reason', 'locality_only');
  end if;
  select d.address_line into v_line
  from public.property_private_details d
  where d.property_id = v_property_id;
  if v_line is null or btrim(v_line) = '' then
    return jsonb_build_object('ok', true, 'visible', false, 'reason', 'no_address');
  end if;
  return jsonb_build_object(
    'ok', true,
    'visible', true,
    'reason', 'accepted',
    'address_line', v_line
  );
end;
$$;

create or replace function public.get_contact_visibility(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_other uuid;
  v_consent public.contact_consents;
  v_contact public.private_contacts;
  v_phone text;
  v_email text;
begin
  if v_uid is null then
    return jsonb_build_object('visible', false, 'reason', 'unauthenticated');
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if not found
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object('visible', false, 'reason', 'not_found');
  end if;

  if v_match.status <> 'active' then
    return jsonb_build_object('visible', false, 'reason', 'match_inactive');
  end if;

  v_other := case
    when v_uid = v_match.participant_a then v_match.participant_b
    else v_match.participant_a
  end;

  if exists (
    select 1 from public.blocks
    where (blocker_id = v_uid and blocked_user_id = v_other)
       or (blocker_id = v_other and blocked_user_id = v_uid)
  ) then
    return jsonb_build_object('visible', false, 'reason', 'blocked');
  end if;

  select * into v_consent
  from public.contact_consents
  where match_id = p_match_id
    and granted_by = v_other
    and revoked_at is null;

  if not found then
    return jsonb_build_object('visible', false, 'reason', 'consent_required');
  end if;

  select * into v_contact from public.private_contacts where user_id = v_other;
  v_phone := case
    when v_consent.scope in ('phone', 'phone_and_email') then v_contact.phone
    else null
  end;
  v_email := case
    when v_consent.scope in ('email', 'phone_and_email') then v_contact.email
    else null
  end;

  return jsonb_strip_nulls(jsonb_build_object(
    'visible', true,
    'reason', 'granted',
    'phone', v_phone,
    'email', v_email
  ));
end;
$$;

comment on function public.get_contact_visibility(uuid) is
  'Returns phone or email only for an active match participant when the other person has unrevoked consent and neither side has blocked the other. Hidden results omit the phone and email keys.';

comment on function public.propose_visit_time(uuid, jsonb) is
  'Replaces the proposed times on an open visit. The other participant moves the visit to rescheduled. Does not return an address.';

comment on function public.respond_visit(uuid, text) is
  'Accept, decline, cancel, or mark completed. The requester cancels a request and accepts a counter-proposal. Either participant can complete an accepted visit. No address is returned.';

comment on function public.get_visit_address(uuid) is
  'Returns address_line only after the visit is accepted or completed, and only when the listing is not locality_only. Omits phone and email.';

comment on function public.request_visit(uuid, jsonb) is
  'Creates a match-gated visit. Links the single published home whose address is allowed after a visit. Does not return an address.';

create or replace function public.delete_own_account()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner text := current_user;
  v_storage_removed boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  if to_regclass('storage.objects') is not null then
    begin
      delete from storage.objects
      where bucket_id = 'listing-photos'
        and split_part(name, '/', 1) = v_uid::text;
      v_storage_removed := true;
    exception
      when insufficient_privilege then
        begin
          execute 'set local role supabase_storage_admin';
          delete from storage.objects
          where bucket_id = 'listing-photos'
            and split_part(name, '/', 1) = v_uid::text;
          v_storage_removed := true;
        exception
          when others then
            v_storage_removed := false;
        end;
        begin
          execute format('set local role %I', v_owner);
        exception
          when others then
            null;
        end;
      when others then
        v_storage_removed := false;
    end;
  end if;

  delete from public.reports
  where reporter_id = v_uid
     or target_id = v_uid
     or target_id in (
       select id from public.properties where host_user_id = v_uid
     )
     or target_id in (
       select id from public.listing_requirements where user_id = v_uid
     )
     or target_id in (
       select m.id
       from public.messages m
       join public.conversations c on c.id = m.conversation_id
       join public.matches mt on mt.id = c.match_id
       where mt.participant_a = v_uid or mt.participant_b = v_uid
     );

  delete from public.notifications
  where user_id <> v_uid
    and payload_minimal ->> 'match_id' in (
      select id::text
      from public.matches
      where participant_a = v_uid or participant_b = v_uid
    );

  delete from public.interests
  where (
    target_type = 'user' and target_id = v_uid
  ) or (
    target_type = 'property'
    and target_id in (select id from public.properties where host_user_id = v_uid)
  ) or (
    target_type = 'listing_requirement'
    and target_id in (
      select id from public.listing_requirements where user_id = v_uid
    )
  );

  delete from public.matches
  where participant_a = v_uid or participant_b = v_uid;

  delete from public.properties
  where host_user_id = v_uid;

  delete from auth.users
  where id = v_uid;

  return jsonb_build_object('ok', true, 'storage_removed', v_storage_removed);
end;
$$;

comment on function public.delete_own_account() is
  'The client lists and removes listing-photos under the user id, calls this function, then auth.signOut. This function deletes those storage objects, related rows, and auth.users. Cascades remove the profile, private contact, preferences, and messages. The body has no phone, email, or address_line.';

revoke all on function public._link_visit_property(public.matches) from public, anon, authenticated;
revoke all on function public.propose_visit_time(uuid, jsonb) from public, anon;
revoke all on function public.get_visit_address(uuid) from public, anon;
revoke all on function public.delete_own_account() from public, anon, authenticated;

grant execute on function public.propose_visit_time(uuid, jsonb) to authenticated;
grant execute on function public.get_visit_address(uuid) to authenticated;
grant execute on function public.delete_own_account() to authenticated;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261017120000',
  'visit_lifecycle_contact',
  array['docs/staging_apply_C_1017.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

do $homizi_c_1017_check$
begin
  if to_regprocedure('public.propose_visit_time(uuid, jsonb)') is null then
    raise exception 'propose_visit_time was not created';
  end if;
  if to_regprocedure('public.get_visit_address(uuid)') is null then
    raise exception 'get_visit_address was not created';
  end if;
  if to_regprocedure('public.delete_own_account()') is null then
    raise exception 'delete_own_account was not created';
  end if;
  if (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'visit_requests'
      and column_name = 'property_id'
  ) <> 1 then
    raise exception 'visit_requests.property_id was not added';
  end if;
  if (
    select count(*)
    from supabase_migrations.schema_migrations
    where version = '20261017120000'
  ) <> 1 then
    raise exception 'visit lifecycle migration was not recorded';
  end if;
end
$homizi_c_1017_check$;
