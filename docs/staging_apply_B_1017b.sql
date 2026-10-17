-- HOMIZI owner flows for a project that already ran docs/staging_apply.sql,
-- docs/staging_apply_next.sql, and docs/staging_apply_B_1017.sql.
-- Paste this whole file into the dashboard SQL editor. Running it again is safe.
-- Enum labels are committed before the functions that use them.
-- No phone, email, street address, or identity document is inserted.

-- Slice B. New listing lifecycle values.
-- This file only adds enum labels. The next migration uses them, which
-- PostgreSQL allows only after this transaction commits.
-- in_review: the owner submitted the draft and it is not live yet.
-- rented: the owner marked the home as let. It leaves the public feed.

alter type public.listing_status add value if not exists 'in_review';
alter type public.listing_status add value if not exists 'rented';

commit;

-- Slice B owner flows.
-- Drafts, review, live, paused, and rented listings; owner-only stats;
-- mock badges derived on the server; reply time from message timestamps.
-- No phone, email, street address, or identity document is returned.
-- listing_views is created only when missing, with the agreed columns.

alter table public.properties
  add column if not exists published_until timestamptz;

comment on column public.properties.published_until is
  'End of the live window. Renew extends it by 30 days. Null means no window yet.';

do $$
begin
  if to_regclass('public.listing_views') is null then
    create table public.listing_views (
      viewer_id uuid not null,
      property_id uuid not null,
      viewed_on date not null,
      unique (viewer_id, property_id, viewed_on)
    );
  end if;
end $$;

do $$
begin
  if to_regclass('public.listing_views') is null then
    return;
  end if;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'listing_views'
      and column_name = 'viewer_id'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'listing_views'
      and column_name = 'property_id'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'listing_views'
      and column_name = 'viewed_on'
  )
  and not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'listing_views'
      and indexdef ilike '%(viewer_id, property_id, viewed_on)%'
  ) then
    create unique index listing_views_once_per_day
      on public.listing_views (viewer_id, property_id, viewed_on);
  end if;
end $$;

alter table public.listing_views enable row level security;

revoke all on table public.listing_views from anon, public;

comment on table public.listing_views is
  'One row per viewer, listing, and calendar day. Owners read totals through get_my_listing_stats. The row does not store a name, phone, or email.';

-- Booleans only. The view owner can read private_contacts so a phone or
-- email on file becomes a badge without leaving the contact table.
-- security_invoker stays off for that reason. Clients cannot select the
-- contact columns through this view.
create or replace view public.user_badges
with (security_invoker = false) as
select
  u.id as user_id,
  (pc.phone is not null and btrim(pc.phone) <> '') as phone_verified,
  (pc.email is not null and btrim(pc.email) <> '') as email_verified,
  (
    char_length(btrim(coalesce(p.display_name, ''))) >= 2
    and nullif(btrim(coalesce(p.occupation, '')), '') is not null
    and char_length(btrim(coalesce(p.public_bio, ''))) >= 20
  ) as profile_complete,
  (p.verification_status = 'mock_verified') as id_verified_demo
from public.users u
left join public.profiles p on p.user_id = u.id
left join public.private_contacts pc on pc.user_id = u.id;

comment on view public.user_badges is
  'Mock badges only. id_verified_demo is a staging toggle. No Aadhaar, passport, or face data is stored.';

revoke all on table public.user_badges from anon, public;
grant select on table public.user_badges to authenticated;

create or replace function public.listing_visit_count(
  p_property_id uuid,
  p_host uuid
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.visit_requests v
  join public.matches m on m.id = v.match_id
  where v.property_id = p_property_id
     or (
       v.property_id is null
       and p_host in (m.participant_a, m.participant_b)
       and (
         select count(*)
         from public.properties other
         where other.host_user_id = p_host
           and other.id <> p_property_id
           and other.status in (
             'published',
             'paused',
             'rented',
             'in_review',
             'expired'
           )
       ) = 0
     );
$$;

revoke all on function public.listing_visit_count(uuid, uuid) from public, anon, authenticated;

create or replace function public.list_my_listings()
returns jsonb
language plpgsql
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

  update public.properties
  set status = 'expired'
  where host_user_id = v_uid
    and status = 'published'
    and published_until is not null
    and published_until < now();

  select coalesce(
    jsonb_agg(to_jsonb(item) order by item.updated_at desc),
    '[]'::jsonb
  )
  into v_rows
  from (
    select
      p.id,
      p.title,
      p.locality,
      p.city,
      p.rent_inr,
      p.status,
      case p.status
        when 'draft' then 'draft'
        when 'in_review' then 'in_review'
        when 'published' then 'live'
        when 'paused' then 'paused'
        when 'rented' then 'rented'
        when 'expired' then 'expired'
        else p.status::text
      end as chip,
      coalesce((
        select count(*)::integer
        from public.listing_views lv
        where lv.property_id = p.id
      ), 0) as views,
      coalesce((
        select count(*)::integer
        from public.interests i
        where i.target_type = 'property'
          and i.target_id = p.id
          and i.action = 'save'
      ), 0) as saves,
      coalesce((
        select count(*)::integer
        from public.interests i
        where i.target_type = 'property'
          and i.target_id = p.id
          and i.action = 'like'
      ), 0) as interests,
      public.listing_visit_count(p.id, p.host_user_id) as visit_requests,
      p.published_until,
      p.updated_at
    from public.properties p
    where p.host_user_id = v_uid
      and p.status <> 'removed'
  ) item;

  return jsonb_build_object('ok', true, 'listings', v_rows);
end;
$$;

create or replace function public.get_my_listing_stats(p_property_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_host uuid;
  v_days jsonb;
  v_saves integer;
  v_interests integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select host_user_id into v_host
  from public.properties
  where id = p_property_id;
  if v_host is null or v_host <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;

  select coalesce(jsonb_agg(ordered.day_row order by ordered.day), '[]'::jsonb)
  into v_days
  from (
    select jsonb_build_object(
      'day', series.day::date,
      'views', coalesce(counts.views, 0)
    ) as day_row,
    series.day::date as day
    from generate_series(
      (current_date - 29),
      current_date,
      interval '1 day'
    ) as series(day)
    left join (
      select viewed_on, count(*)::integer as views
      from public.listing_views
      where property_id = p_property_id
      group by viewed_on
    ) counts on counts.viewed_on = series.day::date
  ) ordered;

  select count(*)::integer into v_saves
  from public.interests
  where target_type = 'property'
    and target_id = p_property_id
    and action = 'save';

  select count(*)::integer into v_interests
  from public.interests
  where target_type = 'property'
    and target_id = p_property_id
    and action = 'like';

  return jsonb_build_object(
    'ok', true,
    'property_id', p_property_id,
    'days', v_days,
    'saves', coalesce(v_saves, 0),
    'interests', coalesce(v_interests, 0),
    'visit_requests', public.listing_visit_count(p_property_id, v_host)
  );
end;
$$;

create or replace function public.record_listing_view(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_host uuid;
  v_status public.listing_status;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select host_user_id, status
  into v_host, v_status
  from public.properties
  where id = p_property_id;
  if v_host is null or v_status is distinct from 'published' then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if public.is_blocked_with(v_host) then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_host = v_uid then
    return jsonb_build_object('ok', true, 'recorded', false);
  end if;
  insert into public.listing_views (viewer_id, property_id, viewed_on)
  values (v_uid, p_property_id, current_date)
  on conflict (viewer_id, property_id, viewed_on) do nothing;
  return jsonb_build_object('ok', true, 'recorded', true);
end;
$$;

create or replace function public.set_my_listing_status(
  p_property_id uuid,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_property public.properties;
  v_issue text;
  v_until timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_property
  from public.properties
  where id = p_property_id;
  if not found or v_property.host_user_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;

  if p_action = 'pause' then
    if v_property.status is distinct from 'published' then
      return jsonb_build_object('ok', false, 'error', 'invalid');
    end if;
    update public.properties
    set status = 'paused'
    where id = p_property_id
      and host_user_id = v_uid
      and status = 'published';
    return jsonb_build_object('ok', true, 'status', 'paused');
  end if;

  if p_action = 'resume' then
    if v_property.status not in ('paused', 'expired') then
      return jsonb_build_object('ok', false, 'error', 'invalid');
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
        published_at = coalesce(published_at, now()),
        published_until = case
          when published_until is null or published_until < now()
            then now() + interval '30 days'
          else published_until
        end
    where id = p_property_id
      and host_user_id = v_uid;
    return jsonb_build_object('ok', true, 'status', 'published');
  end if;

  if p_action = 'mark_rented' then
    if v_property.status not in ('published', 'paused') then
      return jsonb_build_object('ok', false, 'error', 'invalid');
    end if;
    update public.properties
    set status = 'rented'
    where id = p_property_id
      and host_user_id = v_uid;
    return jsonb_build_object('ok', true, 'status', 'rented');
  end if;

  if p_action = 'renew' then
    if v_property.status not in ('published', 'paused', 'expired') then
      return jsonb_build_object('ok', false, 'error', 'invalid');
    end if;
    v_until := greatest(now(), coalesce(v_property.published_until, now()))
      + interval '30 days';
    if v_property.status = 'expired' then
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
          published_at = coalesce(published_at, now()),
          published_until = v_until
      where id = p_property_id
        and host_user_id = v_uid;
      return jsonb_build_object('ok', true, 'status', 'published');
    end if;
    update public.properties
    set published_until = v_until
    where id = p_property_id
      and host_user_id = v_uid;
    return jsonb_build_object('ok', true, 'status', v_property.status);
  end if;

  if p_action = 'submit_review' then
    if v_property.status = 'in_review' then
      return jsonb_build_object('ok', true, 'status', 'in_review');
    end if;
    if v_property.status is distinct from 'draft' then
      return jsonb_build_object('ok', false, 'error', 'invalid');
    end if;
    if char_length(btrim(coalesce(v_property.title, ''))) < 3
       or char_length(btrim(coalesce(v_property.locality, ''))) < 1
       or char_length(btrim(coalesce(v_property.city, ''))) < 1
       or coalesce(v_property.rent_inr, 0) <= 0 then
      return jsonb_build_object('ok', false, 'error', 'incomplete');
    end if;
    update public.properties
    set status = 'in_review'
    where id = p_property_id
      and host_user_id = v_uid
      and status = 'draft';
    return jsonb_build_object('ok', true, 'status', 'in_review');
  end if;

  if p_action = 'delete_draft' then
    if v_property.status is distinct from 'draft' then
      return jsonb_build_object('ok', false, 'error', 'not_draft');
    end if;
    delete from public.listing_views where property_id = p_property_id;
    delete from public.properties
    where id = p_property_id
      and host_user_id = v_uid
      and status = 'draft';
    return jsonb_build_object('ok', true, 'deleted', true);
  end if;

  return jsonb_build_object('ok', false, 'error', 'invalid');
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
      published_at = coalesce(published_at, now()),
      published_until = coalesce(
        published_until,
        now() + interval '30 days'
      )
  where id = p_property_id;
  return jsonb_build_object('ok', true, 'property_id', p_property_id);
end;
$$;

-- Median is unnecessary here: the mean reply gap, rounded, is the badge.
-- Null when the owner has not replied to anyone. Message text is not returned.
create or replace function public.owner_reply_hours(p_host_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  with inbound as (
    select m.created_at as asked_at,
      (
        select min(reply.created_at)
        from public.messages reply
        where reply.conversation_id = m.conversation_id
          and reply.sender_id = p_host_user_id
          and reply.created_at > m.created_at
          and reply.status = 'sent'
      ) as replied_at
    from public.messages m
    join public.conversations c on c.id = m.conversation_id
    join public.matches mt on mt.id = c.match_id
    where m.sender_id <> p_host_user_id
      and m.status = 'sent'
      and p_host_user_id in (mt.participant_a, mt.participant_b)
  ),
  gaps as (
    select extract(epoch from (replied_at - asked_at)) / 3600.0 as hours
    from inbound
    where replied_at is not null
  )
  select case
    when count(*) = 0 then null
    else greatest(1, round(avg(hours)))::integer
  end
  from gaps;
$$;

-- Staging and demo builds call this. It flips mock_verified only.
-- It never reads or writes a document number.
create or replace function public.set_demo_id_badge(p_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status public.verification_status;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if coalesce(current_setting('app.environment', true), '') = 'prod' then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;
  v_status := case
    when coalesce(p_enabled, false) then 'mock_verified'::public.verification_status
    else 'not_started'::public.verification_status
  end;
  update public.profiles
  set verification_status = v_status
  where user_id = v_uid;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object(
    'ok', true,
    'id_verified_demo', v_status = 'mock_verified'
  );
end;
$$;

comment on function public.set_demo_id_badge(boolean) is
  'Demo badge only. Sets mock_verified or not_started. Does not collect an identity document.';

comment on function public.get_my_listing_stats(uuid) is
  'Owner-only totals for one listing. Other accounts receive not_owner.';

revoke all on function public.list_my_listings() from public, anon;
revoke all on function public.get_my_listing_stats(uuid) from public, anon;
revoke all on function public.record_listing_view(uuid) from public, anon;
revoke all on function public.set_my_listing_status(uuid, text) from public, anon;
revoke all on function public.owner_reply_hours(uuid) from public, anon;
revoke all on function public.set_demo_id_badge(boolean) from public, anon;
revoke all on function public.publish_listing(uuid) from public, anon;

grant execute on function public.list_my_listings() to authenticated;
grant execute on function public.get_my_listing_stats(uuid) to authenticated;
grant execute on function public.record_listing_view(uuid) to authenticated;
grant execute on function public.set_my_listing_status(uuid, text) to authenticated;
grant execute on function public.owner_reply_hours(uuid) to authenticated;
grant execute on function public.set_demo_id_badge(boolean) to authenticated;
grant execute on function public.publish_listing(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name, statements)
values
  (
    '20261017160000',
    'owner_listing_status',
    array['docs/staging_apply_B_1017b.sql']
  ),
  (
    '20261017160100',
    'owner_flows',
    array['docs/staging_apply_B_1017b.sql']
  )
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

do $homizi_b_owner$
begin
  if to_regprocedure('public.get_my_listing_stats(uuid)') is null then
    raise exception 'get_my_listing_stats was not created';
  end if;
  if to_regprocedure('public.owner_reply_hours(uuid)') is null then
    raise exception 'owner_reply_hours was not created';
  end if;
  if to_regclass('public.user_badges') is null then
    raise exception 'user_badges was not created';
  end if;
  if to_regclass('public.listing_views') is null then
    raise exception 'listing_views was not created';
  end if;
end
$homizi_b_owner$;
