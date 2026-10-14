-- Access rules and server functions.
-- create_interest, create_mutual_match, and get_contact_visibility are authoritative.
-- A like becomes a match only when each person has an active like toward the other
-- (their user id, a published property they host, or a published requirement they own).
-- Passing after a match does not dissolve it. That behavior is an owner decision.

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff_roles where user_id = auth.uid()
  );
$$;

create or replace function public.is_blocked_with(other_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.blocks
    where (blocker_id = auth.uid() and blocked_user_id = other_user)
       or (blocker_id = other_user and blocked_user_id = auth.uid())
  );
$$;

create or replace function public._has_like_toward_user(p_actor uuid, p_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.interests i
    where i.actor_user_id = p_actor
      and i.action = 'like'
      and (
        (i.target_type = 'user' and i.target_id = p_owner)
        or (
          i.target_type = 'property'
          and exists (
            select 1
            from public.properties p
            where p.id = i.target_id
              and p.host_user_id = p_owner
              and p.status = 'published'
          )
        )
        or (
          i.target_type = 'listing_requirement'
          and exists (
            select 1
            from public.listing_requirements r
            where r.id = i.target_id
              and r.user_id = p_owner
              and r.status = 'published'
          )
        )
      )
  );
$$;

create or replace function public._try_mutual_match(p_left uuid, p_right uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_low uuid;
  v_high uuid;
  v_match public.matches;
begin
  if p_left is null or p_right is null or p_left = p_right then
    return jsonb_build_object('ok', false, 'error', 'invalid_pair');
  end if;

  if p_left < p_right then
    v_low := p_left;
    v_high := p_right;
  else
    v_low := p_right;
    v_high := p_left;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_low::text || ':' || v_high::text, 0));

  select * into v_match
  from public.matches
  where participant_a = v_low and participant_b = v_high;

  if found then
    return jsonb_build_object(
      'ok', true,
      'match_id', v_match.id,
      'status', v_match.status,
      'idempotent', true
    );
  end if;

  if exists (
    select 1 from public.users
    where id in (p_left, p_right) and status <> 'active'
  ) then
    return jsonb_build_object('ok', false, 'error', 'inactive_user');
  end if;

  if exists (
    select 1 from public.blocks
    where (blocker_id = p_left and blocked_user_id = p_right)
       or (blocker_id = p_right and blocked_user_id = p_left)
  ) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;

  if not public._has_like_toward_user(p_left, p_right)
     or not public._has_like_toward_user(p_right, p_left) then
    return jsonb_build_object('ok', false, 'error', 'no_reciprocal');
  end if;

  insert into public.matches (participant_a, participant_b)
  values (v_low, v_high)
  on conflict (participant_a, participant_b) do nothing
  returning * into v_match;

  if v_match.id is null then
    select * into v_match
    from public.matches
    where participant_a = v_low and participant_b = v_high;
  end if;

  return jsonb_build_object(
    'ok', true,
    'match_id', v_match.id,
    'status', v_match.status,
    'idempotent', false
  );
end;
$$;

create or replace function public.create_interest(
  p_target_type public.interest_target_type,
  p_target_id uuid,
  p_action public.interest_action
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_visible boolean := false;
  v_found boolean := false;
  v_existing uuid;
  v_id uuid;
  v_match jsonb := null;
  v_recent bigint;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  if p_target_type = 'property' then
    select host_user_id, status = 'published', true
      into v_owner, v_visible, v_found
    from public.properties
    where id = p_target_id;
  elsif p_target_type = 'listing_requirement' then
    select user_id, status = 'published', true
      into v_owner, v_visible, v_found
    from public.listing_requirements
    where id = p_target_id;
  elsif p_target_type = 'user' then
    select p_target_id, exists (
      select 1 from public.properties p
      where p.host_user_id = p_target_id and p.status = 'published'
      union all
      select 1 from public.listing_requirements r
      where r.user_id = p_target_id and r.status = 'published'
    ), exists (select 1 from public.users u where u.id = p_target_id)
      into v_owner, v_visible, v_found;
  end if;

  if not coalesce(v_found, false) then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_owner = v_uid then
    return jsonb_build_object('ok', false, 'error', 'self');
  end if;
  if not v_visible then
    return jsonb_build_object('ok', false, 'error', 'not_visible');
  end if;
  if exists (
    select 1 from public.blocks
    where (blocker_id = v_uid and blocked_user_id = v_owner)
       or (blocker_id = v_owner and blocked_user_id = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;

  select count(*) into v_recent
  from public.interests
  where actor_user_id = v_uid
    and created_at > now() - interval '1 hour';
  if v_recent >= 200 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  select id into v_existing
  from public.interests
  where actor_user_id = v_uid
    and target_type = p_target_type
    and target_id = p_target_id
    and action = p_action;

  if v_existing is not null then
    update public.interests set updated_at = now() where id = v_existing;
    if p_action = 'like' then
      v_match := public._try_mutual_match(v_uid, v_owner);
    end if;
    return jsonb_build_object(
      'ok', true,
      'interest_id', v_existing,
      'idempotent', true,
      'match', v_match
    );
  end if;

  if p_action in ('like', 'pass') then
    delete from public.interests
    where actor_user_id = v_uid
      and target_type = p_target_type
      and target_id = p_target_id
      and action in ('like', 'pass');
  end if;

  insert into public.interests (actor_user_id, target_type, target_id, action)
  values (v_uid, p_target_type, p_target_id, p_action)
  returning id into v_id;

  if p_action = 'like' then
    v_match := public._try_mutual_match(v_uid, v_owner);
  end if;

  return jsonb_build_object(
    'ok', true,
    'interest_id', v_id,
    'idempotent', false,
    'match', v_match
  );
end;
$$;

create or replace function public.create_mutual_match(p_other_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  return public._try_mutual_match(v_uid, p_other_user_id);
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
begin
  if v_uid is null then
    return jsonb_build_object(
      'visible', false,
      'reason', 'unauthenticated',
      'phone', null,
      'email', null
    );
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if not found
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b) then
    return jsonb_build_object(
      'visible', false,
      'reason', 'not_found',
      'phone', null,
      'email', null
    );
  end if;

  if v_match.status <> 'active' then
    return jsonb_build_object(
      'visible', false,
      'reason', 'match_inactive',
      'phone', null,
      'email', null
    );
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
    return jsonb_build_object(
      'visible', false,
      'reason', 'blocked',
      'phone', null,
      'email', null
    );
  end if;

  select * into v_consent
  from public.contact_consents
  where match_id = p_match_id
    and granted_by = v_other
    and revoked_at is null;

  if not found then
    return jsonb_build_object(
      'visible', false,
      'reason', 'consent_required',
      'phone', null,
      'email', null
    );
  end if;

  select * into v_contact from public.private_contacts where user_id = v_other;

  return jsonb_build_object(
    'visible', true,
    'reason', 'granted',
    'phone', case
      when v_consent.scope in ('phone', 'phone_and_email') then v_contact.phone
      else null
    end,
    'email', case
      when v_consent.scope in ('email', 'phone_and_email') then v_contact.email
      else null
    end
  );
end;
$$;

comment on function public.get_contact_visibility(uuid) is
  'Returns phone or email only for an active match participant when the other person has unrevoked consent and neither side has blocked the other.';

create or replace function public.grant_contact_consent(
  p_match_id uuid,
  p_scope public.contact_scope
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
  select * into v_match from public.matches where id = p_match_id;
  if not found
     or (v_uid <> v_match.participant_a and v_uid <> v_match.participant_b)
     or v_match.status <> 'active' then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
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
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;

  insert into public.contact_consents (match_id, granted_by, scope)
  values (p_match_id, v_uid, p_scope)
  on conflict (match_id, granted_by) do update
    set scope = excluded.scope,
        revoked_at = null,
        granted_at = now()
  returning id into v_id;

  return jsonb_build_object('ok', true, 'consent_id', v_id);
end;
$$;

create or replace function public.revoke_contact_consent(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  update public.contact_consents
  set revoked_at = now()
  where match_id = p_match_id
    and granted_by = v_uid
    and revoked_at is null;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.publish_listing(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_property public.properties;
  v_photos integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_property from public.properties where id = p_property_id;
  if not found or v_property.host_user_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if char_length(v_property.title) < 3
     or char_length(v_property.locality) < 1
     or v_property.rent_inr <= 0 then
    return jsonb_build_object('ok', false, 'error', 'incomplete');
  end if;
  select count(*) into v_photos
  from public.property_photos
  where property_id = p_property_id;
  if v_photos < 3 then
    return jsonb_build_object('ok', false, 'error', 'photos');
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
  if v_row.budget_min_inr > v_row.budget_max_inr or char_length(v_row.city) < 1 then
    return jsonb_build_object('ok', false, 'error', 'incomplete');
  end if;
  update public.listing_requirements
  set status = 'published'
  where id = p_requirement_id;
  return jsonb_build_object('ok', true, 'requirement_id', p_requirement_id);
end;
$$;

create or replace function public.request_mock_verification()
returns public.verification_status
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'unauthenticated';
  end if;
  update public.profiles
  set verification_status = 'mock_pending'
  where user_id = v_uid;
  return 'mock_pending';
end;
$$;

comment on function public.request_mock_verification() is
  'Sets mock_pending only. Never collects a document. mock_verified is not settable by the client.';

-- ---------------------------------------------------------------------------
-- Grants. auto_expose is off; everything below is explicit.
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from public, anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to service_role;
grant all on all functions in schema public to service_role;
-- Hosted projects may not let the migration role grant on auth.uid().
-- Local and hosted already allow anon and authenticated to execute it.
do $$
begin
  grant execute on function auth.uid() to anon, authenticated;
exception
  when insufficient_privilege then
    raise notice 'auth.uid grant skipped: %', sqlerrm;
end $$;

grant select on public.users to authenticated;
grant update (primary_role) on public.users to authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, occupation, public_bio, avatar_path)
  on public.profiles to authenticated;

grant select, update (email, phone, date_of_birth)
  on public.private_contacts to authenticated;

grant select, insert, update, delete on public.host_profiles to authenticated;
grant select, insert, update, delete on public.tenant_preferences to authenticated;

grant select on public.properties to authenticated;
grant insert (
  id, host_user_id, title, locality, city, address_visibility, property_type,
  furnishing, rent_inr, deposit_inr, brokerage_inr, maintenance_inr,
  occupancy_max, available_from
) on public.properties to authenticated;
grant update (
  title, locality, city, address_visibility, property_type, furnishing,
  rent_inr, deposit_inr, brokerage_inr, maintenance_inr, occupancy_max,
  available_from
) on public.properties to authenticated;

grant select, insert, update, delete on public.property_private_details to authenticated;
grant select, insert, update, delete on public.property_features to authenticated;
grant select on public.property_photos to authenticated;
grant insert (property_id, storage_path, sort_order, photo_type)
  on public.property_photos to authenticated;
grant update (storage_path, sort_order, photo_type)
  on public.property_photos to authenticated;
grant delete on public.property_photos to authenticated;

grant select on public.listing_requirements to authenticated;
grant insert (
  id, user_id, city, localities, budget_min_inr, budget_max_inr, move_in_date,
  occupancy, property_types, furnishing, lifestyle
) on public.listing_requirements to authenticated;
grant update (
  city, localities, budget_min_inr, budget_max_inr, move_in_date, occupancy,
  property_types, furnishing, lifestyle
) on public.listing_requirements to authenticated;

grant select on public.interests to authenticated;
grant select on public.matches to authenticated;
grant select on public.contact_consents to authenticated;
grant select on public.conversations to authenticated;
grant select, insert on public.messages to authenticated;
grant select, insert, update on public.visit_requests to authenticated;
grant select, update (read_at) on public.notifications to authenticated;
grant select, insert on public.reports to authenticated;
grant select, insert, delete on public.blocks to authenticated;
grant select on public.staff_roles to authenticated;
grant select on public.subscriptions to authenticated;
grant select on public.payments to authenticated;
grant select, insert, update (revoked_at) on public.consent_records to authenticated;

grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_blocked_with(uuid) to authenticated;
grant execute on function public.create_interest(public.interest_target_type, uuid, public.interest_action) to authenticated;
grant execute on function public.create_mutual_match(uuid) to authenticated;
grant execute on function public.get_contact_visibility(uuid) to authenticated;
grant execute on function public.grant_contact_consent(uuid, public.contact_scope) to authenticated;
grant execute on function public.revoke_contact_consent(uuid) to authenticated;
grant execute on function public.publish_listing(uuid) to authenticated;
grant execute on function public.publish_requirement(uuid) to authenticated;
grant execute on function public.request_mock_verification() to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.users enable row level security;
alter table public.profiles enable row level security;
alter table public.private_contacts enable row level security;
alter table public.host_profiles enable row level security;
alter table public.tenant_preferences enable row level security;
alter table public.properties enable row level security;
alter table public.property_private_details enable row level security;
alter table public.property_features enable row level security;
alter table public.property_photos enable row level security;
alter table public.listing_requirements enable row level security;
alter table public.interests enable row level security;
alter table public.matches enable row level security;
alter table public.contact_consents enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.visit_requests enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
alter table public.staff_roles enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payments enable row level security;
alter table public.audit_events enable row level security;
alter table public.consent_records enable row level security;

create policy users_select_self on public.users
  for select to authenticated
  using (id = auth.uid() or public.is_staff());
create policy users_update_self on public.users
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_select on public.profiles
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_staff()
    or exists (
      select 1 from public.properties p
      where p.host_user_id = profiles.user_id and p.status = 'published'
    )
    or exists (
      select 1 from public.listing_requirements r
      where r.user_id = profiles.user_id and r.status = 'published'
    )
    or exists (
      select 1 from public.matches m
      where m.status = 'active'
        and (
          (m.participant_a = auth.uid() and m.participant_b = profiles.user_id)
          or (m.participant_b = auth.uid() and m.participant_a = profiles.user_id)
        )
    )
  );
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy private_contacts_self on public.private_contacts
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy host_profiles_self on public.host_profiles
  for all to authenticated
  using (user_id = auth.uid() or public.is_staff())
  with check (user_id = auth.uid());

create policy tenant_preferences_self on public.tenant_preferences
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy properties_select on public.properties
  for select to authenticated
  using (
    host_user_id = auth.uid()
    or (
      status = 'published'
      and not public.is_blocked_with(host_user_id)
    )
  );
create policy properties_insert on public.properties
  for insert to authenticated
  with check (host_user_id = auth.uid());
create policy properties_update on public.properties
  for update to authenticated
  using (host_user_id = auth.uid())
  with check (host_user_id = auth.uid());

create policy property_private_owner on public.property_private_details
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );

create policy property_features_select on public.property_features
  for select to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id
        and (
          p.host_user_id = auth.uid()
          or (p.status = 'published' and not public.is_blocked_with(p.host_user_id))
        )
    )
  );
create policy property_features_write on public.property_features
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );

create policy property_photos_select on public.property_photos
  for select to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id
        and (
          p.host_user_id = auth.uid()
          or (p.status = 'published' and not public.is_blocked_with(p.host_user_id))
        )
    )
  );
create policy property_photos_write on public.property_photos
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );

create policy requirements_select on public.listing_requirements
  for select to authenticated
  using (
    user_id = auth.uid()
    or (
      status = 'published'
      and not public.is_blocked_with(user_id)
    )
  );
create policy requirements_insert on public.listing_requirements
  for insert to authenticated
  with check (user_id = auth.uid());
create policy requirements_update on public.listing_requirements
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy interests_select_own on public.interests
  for select to authenticated
  using (actor_user_id = auth.uid());

create policy matches_select_participant on public.matches
  for select to authenticated
  using (participant_a = auth.uid() or participant_b = auth.uid());

create policy consents_select_participant on public.contact_consents
  for select to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );

create policy conversations_select_member on public.conversations
  for select to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.status = 'active'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );

create policy messages_select_member on public.messages
  for select to authenticated
  using (
    exists (
      select 1
      from public.conversations c
      join public.matches m on m.id = c.match_id
      where c.id = conversation_id
        and c.status = 'open'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
        and not public.is_blocked_with(
          case when m.participant_a = auth.uid() then m.participant_b else m.participant_a end
        )
    )
  );
create policy messages_insert_member on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.conversations c
      join public.matches m on m.id = c.match_id
      where c.id = conversation_id
        and c.status = 'open'
        and m.status = 'active'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
        and not public.is_blocked_with(
          case when m.participant_a = auth.uid() then m.participant_b else m.participant_a end
        )
    )
  );

create policy visits_participant on public.visit_requests
  for all to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  )
  with check (
    requester_id = auth.uid()
    and exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.status = 'active'
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );

create policy notifications_recipient on public.notifications
  for select to authenticated
  using (user_id = auth.uid());
create policy notifications_mark_read on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy reports_insert_own on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open');
create policy reports_select_own on public.reports
  for select to authenticated
  using (reporter_id = auth.uid() or public.is_staff());

create policy blocks_own on public.blocks
  for all to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

create policy staff_roles_select_self on public.staff_roles
  for select to authenticated
  using (user_id = auth.uid());

create policy subscriptions_select_own on public.subscriptions
  for select to authenticated
  using (user_id = auth.uid());
create policy payments_select_own on public.payments
  for select to authenticated
  using (user_id = auth.uid());

create policy consent_records_own on public.consent_records
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- audit_events: RLS on, no policies. service_role bypasses RLS.

-- Listing photo bucket, when the storage schema is present in this database.
do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; listing-photos bucket skipped';
    return;
  end if;
  insert into storage.buckets (id, name, public)
  values ('listing-photos', 'listing-photos', false)
  on conflict (id) do nothing;
  execute 'drop policy if exists listing_photos_insert on storage.objects';
  execute 'drop policy if exists listing_photos_select on storage.objects';
  execute 'drop policy if exists listing_photos_update on storage.objects';
  execute 'drop policy if exists listing_photos_delete on storage.objects';
  execute $policy$
    create policy listing_photos_insert on storage.objects
    for insert to authenticated
    with check (
      bucket_id = 'listing-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
  execute $policy$
    create policy listing_photos_select on storage.objects
    for select to authenticated
    using (
      bucket_id = 'listing-photos'
      and (
        (storage.foldername(name))[1] = auth.uid()::text
        or exists (
          select 1
          from public.property_photos ph
          join public.properties p on p.id = ph.property_id
          where ph.storage_path = name
            and p.status = 'published'
        )
      )
    )
  $policy$;
  execute $policy$
    create policy listing_photos_update on storage.objects
    for update to authenticated
    using (
      bucket_id = 'listing-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
  execute $policy$
    create policy listing_photos_delete on storage.objects
    for delete to authenticated
    using (
      bucket_id = 'listing-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
exception
  when others then
    raise notice 'listing-photos storage policies skipped: %', sqlerrm;
end $$;
