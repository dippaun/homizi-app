-- Realtime chat, a staff moderation queue, and first-party product analytics.
-- Demo mode does not use these tables. No phone, email, or street address is stored
-- in an analytics property or a queue payload. No staff user is seeded.

-- ---------------------------------------------------------------------------
-- Chat: publish message inserts. RLS still hides a blocked thread, and the
-- contact constraint still rejects a phone number or an email address.
-- ---------------------------------------------------------------------------

alter table public.messages replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    raise notice 'supabase_realtime publication missing; chat realtime skipped';
    return;
  end if;
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
exception
  when insufficient_privilege then
    raise notice 'realtime publication update skipped: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- Suspended accounts cannot write. Staff functions run as the caller, so an
-- active staff account can still hide a listing.
-- ---------------------------------------------------------------------------

create or replace function public.reject_if_actor_suspended()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and exists (
    select 1
    from public.users
    where id = auth.uid()
      and status <> 'active'
  ) then
    raise exception 'account is suspended'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists messages_reject_suspended on public.messages;
create trigger messages_reject_suspended
  before insert on public.messages
  for each row execute function public.reject_if_actor_suspended();

drop trigger if exists visits_reject_suspended on public.visit_requests;
create trigger visits_reject_suspended
  before insert on public.visit_requests
  for each row execute function public.reject_if_actor_suspended();

drop trigger if exists interests_reject_suspended on public.interests;
create trigger interests_reject_suspended
  before insert on public.interests
  for each row execute function public.reject_if_actor_suspended();

drop trigger if exists reports_reject_suspended on public.reports;
create trigger reports_reject_suspended
  before insert on public.reports
  for each row execute function public.reject_if_actor_suspended();

drop trigger if exists properties_reject_suspended on public.properties;
create trigger properties_reject_suspended
  before insert or update on public.properties
  for each row execute function public.reject_if_actor_suspended();

-- ---------------------------------------------------------------------------
-- Staff queue. Clients still cannot update report status, listing status,
-- or user status. These functions are the only path, and each one checks
-- staff_roles.
-- ---------------------------------------------------------------------------

create or replace function public.staff_list_reports()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public.is_staff() then
    return jsonb_build_object('ok', false, 'error', 'not_staff');
  end if;
  return jsonb_build_object(
    'ok', true,
    'reports', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'target_type', r.target_type,
          'target_id', r.target_id,
          'reason', r.reason,
          'status', r.status,
          'created_at', r.created_at
        )
        order by r.created_at
      )
      from public.reports r
      where r.status in ('open', 'reviewing')
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.staff_review_report(
  p_report_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_current public.report_status;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public.is_staff() then
    return jsonb_build_object('ok', false, 'error', 'not_staff');
  end if;
  if p_status not in ('reviewing', 'resolved', 'dismissed') then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  select status into v_current
  from public.reports
  where id = p_report_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'missing');
  end if;
  update public.reports
  set status = p_status::public.report_status
  where id = p_report_id;
  insert into public.audit_events (actor_id, action, target, metadata_minimal)
  values (
    v_uid,
    'review_report',
    p_report_id::text,
    jsonb_build_object('status', p_status)
  );
  return jsonb_build_object('ok', true, 'report_id', p_report_id, 'status', p_status);
end;
$$;

create or replace function public.staff_hide_listing(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status public.listing_status;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public.is_staff() then
    return jsonb_build_object('ok', false, 'error', 'not_staff');
  end if;
  select status into v_status
  from public.properties
  where id = p_property_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'missing');
  end if;
  if v_status = 'published' then
    update public.properties
    set status = 'paused'
    where id = p_property_id
      and status = 'published';
    insert into public.audit_events (actor_id, action, target, metadata_minimal)
    values (
      v_uid,
      'hide_listing',
      p_property_id::text,
      jsonb_build_object('status', 'paused')
    );
    v_status := 'paused';
  end if;
  return jsonb_build_object('ok', true, 'property_id', p_property_id, 'status', v_status);
end;
$$;

create or replace function public.staff_suspend_user(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status public.user_status;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not public.is_staff() then
    return jsonb_build_object('ok', false, 'error', 'not_staff');
  end if;
  if p_user_id = v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  select status into v_status from public.users where id = p_user_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'missing');
  end if;
  if v_status = 'active' then
    update public.users
    set status = 'suspended'
    where id = p_user_id
      and status = 'active';
    update public.properties
    set status = 'paused'
    where host_user_id = p_user_id
      and status = 'published';
    update public.listing_requirements
    set status = 'paused'
    where user_id = p_user_id
      and status = 'published';
    insert into public.audit_events (actor_id, action, target, metadata_minimal)
    values (
      v_uid,
      'suspend_user',
      p_user_id::text,
      jsonb_build_object('status', 'suspended')
    );
    v_status := 'suspended';
  end if;
  return jsonb_build_object('ok', true, 'user_id', p_user_id, 'status', v_status);
end;
$$;

comment on function public.staff_list_reports() is
  'Open and reviewing reports for a staff account. The payload has ids, a reason, and a status. It has no phone, email, or free-text details.';
comment on function public.staff_review_report(uuid, text) is
  'Staff sets a report to reviewing, resolved, or dismissed. Clients cannot update report status directly.';
comment on function public.staff_hide_listing(uuid) is
  'Staff pauses a published listing so it leaves the feed. The street address is not returned.';
comment on function public.staff_suspend_user(uuid) is
  'Staff suspends another account and pauses that account''s published listings. Contact fields are not returned.';

revoke all on function public.reject_if_actor_suspended() from public, anon, authenticated;
revoke all on function public.staff_list_reports() from public, anon;
revoke all on function public.staff_review_report(uuid, text) from public, anon;
revoke all on function public.staff_hide_listing(uuid) from public, anon;
revoke all on function public.staff_suspend_user(uuid) from public, anon;

grant execute on function public.staff_list_reports() to authenticated;
grant execute on function public.staff_review_report(uuid, text) to authenticated;
grant execute on function public.staff_hide_listing(uuid) to authenticated;
grant execute on function public.staff_suspend_user(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Product analytics. A person may insert their own event. Only staff can read.
-- Properties are listing_id and match_id UUIDs, or empty.
-- ---------------------------------------------------------------------------

create or replace function public.analytics_properties_ok(p_properties jsonb)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_key text;
  v_value text;
begin
  if p_properties is null or jsonb_typeof(p_properties) <> 'object' then
    return false;
  end if;
  for v_key in select jsonb_object_keys(p_properties)
  loop
    if v_key not in ('listing_id', 'match_id') then
      return false;
    end if;
    v_value := p_properties ->> v_key;
    if v_value is null
       or v_value !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      return false;
    end if;
  end loop;
  return true;
end;
$$;

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  name text not null,
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint analytics_events_name check (
    name in (
      'app_open',
      'listing_view',
      'interest_sent',
      'match_opened',
      'message_sent'
    )
  ),
  constraint analytics_events_properties check (
    public.analytics_properties_ok(properties)
  )
);

create index if not exists analytics_events_name_created_idx
  on public.analytics_events (name, created_at);

comment on table public.analytics_events is
  'First-party product counts. No phone, email, name, or message body. Opt-out is enforced by the client before insert.';

alter table public.analytics_events enable row level security;

drop policy if exists analytics_events_insert_own on public.analytics_events;
create policy analytics_events_insert_own on public.analytics_events
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists analytics_events_select_staff on public.analytics_events;
create policy analytics_events_select_staff on public.analytics_events
  for select to authenticated
  using (public.is_staff());

revoke all on public.analytics_events from public, anon, authenticated;
grant insert (user_id, name, properties) on public.analytics_events to authenticated;
grant select on public.analytics_events to authenticated;
grant all on public.analytics_events to service_role;

drop trigger if exists analytics_reject_suspended on public.analytics_events;
create trigger analytics_reject_suspended
  before insert on public.analytics_events
  for each row execute function public.reject_if_actor_suspended();

revoke all on function public.analytics_properties_ok(jsonb) from public, anon;
grant execute on function public.analytics_properties_ok(jsonb) to authenticated;

-- security_invoker keeps the staff-only select policy in force for readers.
create or replace view public.analytics_funnel
with (security_invoker = true) as
select
  count(distinct user_id) filter (where name = 'app_open') as app_open,
  count(distinct user_id) filter (where name = 'listing_view') as listing_view,
  count(distinct user_id) filter (where name = 'interest_sent') as interest_sent,
  count(distinct user_id) filter (where name = 'match_opened') as match_opened,
  count(distinct user_id) filter (where name = 'message_sent') as message_sent
from public.analytics_events;

create or replace view public.analytics_funnel_steps
with (security_invoker = true) as
select
  name,
  count(distinct user_id) as people,
  count(*) as events
from public.analytics_events
group by name;

create or replace view public.analytics_funnel_daily
with (security_invoker = true) as
select
  date_trunc('day', created_at) as day,
  name,
  count(distinct user_id) as people,
  count(*) as events
from public.analytics_events
group by 1, 2;

comment on view public.analytics_funnel is
  'Distinct people at each product step. Runs as the caller, so only staff see counts.';
comment on view public.analytics_funnel_steps is
  'One row per event name. Runs as the caller, so a member sees no rows.';
comment on view public.analytics_funnel_daily is
  'Daily distinct people per event name. Runs as the caller.';

revoke all on public.analytics_funnel from public, anon, authenticated;
revoke all on public.analytics_funnel_steps from public, anon, authenticated;
revoke all on public.analytics_funnel_daily from public, anon, authenticated;
grant select on public.analytics_funnel to authenticated, service_role;
grant select on public.analytics_funnel_steps to authenticated, service_role;
grant select on public.analytics_funnel_daily to authenticated, service_role;
