-- HOMIZI follow-up for a project that already ran docs/staging_apply.sql.
-- Paste this whole file into the dashboard SQL editor.
-- Running it again is safe: functions are replaced, policies and triggers
-- are dropped and recreated, constraints are replaced, and version rows
-- are upserted.
--
-- It applies every migration added after docs/staging_apply.sql, in
-- filename order:
--   20261016130000_listing_photo_policy_retry.sql
--   20261016140000_listing_interest_notification.sql
--   20261016183000_realtime_moderation_analytics.sql
-- ensure_own_account is already inside staging_apply.sql.
-- No staff user is inserted. No phone, email, or street address is added.

-- -------------------------------------------------------------------------
-- 20261016130000_listing_photo_policy_retry.sql
-- -------------------------------------------------------------------------

-- The first schema apply can skip listing-photos policies when the SQL role
-- does not own storage.objects. Retry as supabase_storage_admin when this
-- session may assume that role. Safe to run again.

do $homizi_photos$
declare
  v_stmt text;
  v_error text := '';
  v_done boolean := false;
  v_stmts text[] := array[
    $homizi_photo_stmt$
      insert into storage.buckets (id, name, public)
      values ('listing-photos', 'listing-photos', false)
      on conflict (id) do nothing
    $homizi_photo_stmt$,
    $homizi_photo_stmt$
      update storage.buckets
      set
        public = false,
        file_size_limit = 5242880,
        allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
      where id = 'listing-photos'
    $homizi_photo_stmt$,
    $homizi_photo_stmt$drop policy if exists listing_photos_insert on storage.objects$homizi_photo_stmt$,
    $homizi_photo_stmt$drop policy if exists listing_photos_select on storage.objects$homizi_photo_stmt$,
    $homizi_photo_stmt$drop policy if exists listing_photos_update on storage.objects$homizi_photo_stmt$,
    $homizi_photo_stmt$drop policy if exists listing_photos_delete on storage.objects$homizi_photo_stmt$,
    $homizi_photo_stmt$
      create policy listing_photos_insert on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $homizi_photo_stmt$,
    $homizi_photo_stmt$
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
    $homizi_photo_stmt$,
    $homizi_photo_stmt$
      create policy listing_photos_update on storage.objects
      for update to authenticated
      using (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $homizi_photo_stmt$,
    $homizi_photo_stmt$
      create policy listing_photos_delete on storage.objects
      for delete to authenticated
      using (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $homizi_photo_stmt$
  ];
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; listing-photos policies skipped';
    return;
  end if;

  begin
    foreach v_stmt in array v_stmts loop
      execute v_stmt;
    end loop;
    v_done := true;
  exception
    when insufficient_privilege then
      v_error := sqlerrm;
  end;

  if v_done then
    return;
  end if;

  if current_user is distinct from 'supabase_storage_admin'
     and exists (select 1 from pg_roles where rolname = 'supabase_storage_admin')
     and pg_has_role(session_user, 'supabase_storage_admin', 'member') then
    begin
      execute 'set local role supabase_storage_admin';
      foreach v_stmt in array v_stmts loop
        execute v_stmt;
      end loop;
    exception
      when insufficient_privilege then
        raise notice 'listing-photos policies skipped: %', sqlerrm;
    end;
  else
    raise notice 'listing-photos policies skipped: %', v_error;
  end if;
end
$homizi_photos$;

-- The photo retry may assume supabase_storage_admin for this transaction.
-- Later statements in this file must run as the original SQL editor role.
reset role;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261016130000',
  'listing_photo_policy_retry',
  array['docs/staging_apply_next.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

-- -------------------------------------------------------------------------
-- 20261016140000_listing_interest_notification.sql
-- -------------------------------------------------------------------------

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

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261016140000',
  'listing_interest_notification',
  array['docs/staging_apply_next.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

-- -------------------------------------------------------------------------
-- 20261016183000_realtime_moderation_analytics.sql
-- -------------------------------------------------------------------------

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

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261016183000',
  'realtime_moderation_analytics',
  array['docs/staging_apply_next.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

do $homizi_next_check$
begin
  if to_regprocedure('public.notify_on_interest()') is null then
    raise exception 'notify_on_interest was not created';
  end if;
  if to_regprocedure('public.staff_list_reports()') is null then
    raise exception 'staff_list_reports was not created';
  end if;
  if to_regclass('public.analytics_events') is null then
    raise exception 'analytics_events was not created';
  end if;
  if to_regclass('public.analytics_funnel') is null then
    raise exception 'analytics_funnel was not created';
  end if;
  if (
    select count(*)
    from supabase_migrations.schema_migrations
    where version in (
      '20261016130000',
      '20261016140000',
      '20261016183000'
    )
  ) <> 3 then
    raise exception 'follow-up migrations were not recorded';
  end if;
end
$homizi_next_check$;
