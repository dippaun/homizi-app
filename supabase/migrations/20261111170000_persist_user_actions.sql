-- Persist host and broker decisions on seeker requests, and let the
-- seeker read that decision after a reload. Likes already live on
-- public.interests. This file does not add a mail provider.
-- Do not apply to staging from an agent. Paste docs/staging_apply_PERSIST_1111.sql
-- only after the owner approves that file.

reset role;

do $$
begin
  if to_regclass('public.owner_leads') is null
     or to_regprocedure('public.owner_lead_json(uuid)') is null
     or to_regprocedure('public._try_mutual_match(uuid, uuid)') is null then
    raise exception 'Apply the earlier HOMIZI staging SQL before this file.';
  end if;
end $$;

alter table public.owner_leads
  add column if not exists decision text not null default 'pending';

do $owner_leads_decision$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'owner_leads_decision'
  ) then
    alter table public.owner_leads
      add constraint owner_leads_decision
      check (decision in ('pending', 'accepted', 'rejected'));
  end if;
end
$owner_leads_decision$;

comment on column public.owner_leads.decision is
  'Host or broker accept or reject. pending until they choose. No phone or email.';

create or replace function public.owner_lead_json(p_lead_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', l.id,
    'property_id', l.property_id,
    'kind', l.kind,
    'status', l.status,
    'decision', l.decision,
    'person_user_id', l.person_user_id,
    'display_name', coalesce(pr.display_name, ''),
    'created_at', l.created_at,
    'first_replied_at', l.first_replied_at,
    'response_minutes', case
      when l.first_replied_at is null then null::integer
      else greatest(
        0,
        floor(extract(epoch from (l.first_replied_at - l.created_at)) / 60)::integer
      )
    end,
    'match_id', (
      select m.id
      from public.matches m
      join public.properties hp on hp.id = l.property_id
      where m.status = 'active'
        and (
          (m.participant_a = hp.host_user_id and m.participant_b = l.person_user_id)
          or (m.participant_b = hp.host_user_id and m.participant_a = l.person_user_id)
        )
      limit 1
    ),
    'audit', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'actor_id', a.actor_id,
          'from_status', a.from_status,
          'to_status', a.to_status,
          'changed_at', a.changed_at
        )
        order by a.changed_at
      )
      from public.owner_lead_audit a
      where a.lead_id = l.id
    ), '[]'::jsonb)
  )
  from public.owner_leads l
  left join public.profiles pr on pr.user_id = l.person_user_id
  where l.id = p_lead_id;
$$;

comment on function public.owner_lead_json(uuid) is
  'Internal lead shape. Display name, decision, and match id. No phone, email, or street address.';

create or replace function public.decide_seeker_request(
  p_lead_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_lead public.owner_leads;
  v_host uuid;
  v_match jsonb := null;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_decision is null or p_decision not in ('accepted', 'rejected') then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;

  select * into v_lead
  from public.owner_leads
  where id = p_lead_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  select host_user_id into v_host
  from public.properties
  where id = v_lead.property_id;
  if v_host is null or v_host <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if v_lead.person_user_id = v_uid then
    return jsonb_build_object('ok', false, 'error', 'self');
  end if;

  update public.owner_leads
  set decision = p_decision
  where id = p_lead_id;

  if p_decision = 'accepted' then
    delete from public.interests
    where actor_user_id = v_uid
      and target_type = 'user'
      and target_id = v_lead.person_user_id
      and action in ('like', 'pass');
    insert into public.interests (actor_user_id, target_type, target_id, action)
    values (v_uid, 'user', v_lead.person_user_id, 'like');
    v_match := public._try_mutual_match(v_uid, v_lead.person_user_id);
  end if;

  return jsonb_build_object(
    'ok', true,
    'lead', public.owner_lead_json(p_lead_id),
    'match', v_match
  );
end;
$$;

comment on function public.decide_seeker_request(uuid, text) is
  'Host or broker accepts or rejects a seeker request on their own listing. Accept records a like and opens a match when the seeker already liked that home. No phone or email is returned.';

create or replace function public.list_my_request_outcomes()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_rows jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'lead_id', l.id,
        'property_id', l.property_id,
        'title', p.title,
        'locality', p.locality,
        'city', p.city,
        'kind', l.kind,
        'decision', l.decision,
        'status', l.status,
        'host_name', coalesce(pr.display_name, ''),
        'created_at', l.created_at
      )
      order by l.created_at desc
    ),
    '[]'::jsonb
  )
  into v_rows
  from public.owner_leads l
  join public.properties p on p.id = l.property_id
  left join public.profiles pr on pr.user_id = p.host_user_id
  where l.person_user_id = v_uid;

  return jsonb_build_object('ok', true, 'outcomes', v_rows);
end;
$$;

comment on function public.list_my_request_outcomes() is
  'Decisions on the signed-in seeker''s own requests. Title and host display name only. No phone, email, or street address.';

create or replace function public.list_incoming_likes()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_rows jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'actor_user_id', i.actor_user_id,
        'display_name', coalesce(pr.display_name, ''),
        'target_type', i.target_type,
        'target_id', i.target_id,
        'created_at', i.created_at
      )
      order by i.created_at desc
    ),
    '[]'::jsonb
  )
  into v_rows
  from public.interests i
  left join public.profiles pr on pr.user_id = i.actor_user_id
  where i.action = 'like'
    and (
      (i.target_type = 'user' and i.target_id = v_uid)
      or (
        i.target_type = 'listing_requirement'
        and exists (
          select 1
          from public.listing_requirements r
          where r.id = i.target_id
            and r.user_id = v_uid
        )
      )
      or (
        i.target_type = 'property'
        and exists (
          select 1
          from public.properties p
          where p.id = i.target_id
            and p.host_user_id = v_uid
        )
      )
    );

  return jsonb_build_object('ok', true, 'likes', v_rows);
end;
$$;

comment on function public.list_incoming_likes() is
  'People who liked the signed-in user, their requirement, or their listing. Display name only. No phone or email.';

revoke all on function public.decide_seeker_request(uuid, text) from public, anon;
revoke all on function public.list_my_request_outcomes() from public, anon;
revoke all on function public.list_incoming_likes() from public, anon;

grant execute on function public.decide_seeker_request(uuid, text) to authenticated;
grant execute on function public.list_my_request_outcomes() to authenticated;
grant execute on function public.list_incoming_likes() to authenticated;
