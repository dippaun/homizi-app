-- Device tokens for push. Own-row only. Delivery no-ops until the
-- operator sets app.settings.push_function_url and
-- app.settings.push_webhook_secret. notification_preferences is owned
-- by another slice and is read only when that table exists.

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  token text not null,
  platform text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint device_tokens_platform check (platform in ('android', 'ios', 'web')),
  constraint device_tokens_token check (
    char_length(token) between 8 and 512
    and position('@' in token) = 0
  ),
  unique (user_id, token)
);

comment on table public.device_tokens is
  'FCM registration token for the signed-in user. Not readable by staff.';

drop trigger if exists device_tokens_set_updated_at on public.device_tokens;
create trigger device_tokens_set_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_own on public.device_tokens;
create policy device_tokens_own on public.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.device_tokens to authenticated;
grant all on public.device_tokens to service_role;

create or replace function public.push_allowed(p_user_id uuid, p_type text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_category text;
  v_column text;
  v_allowed boolean;
  v_categories jsonb;
begin
  v_category := case p_type
    when 'match' then 'matches'
    when 'message' then 'chat'
    when 'visit_requested' then 'visits'
    when 'visit_accepted' then 'visits'
    when 'visit_declined' then 'visits'
    when 'visit_cancelled' then 'visits'
    else null
  end;
  if v_category is null then
    return false;
  end if;
  if to_regclass('public.notification_preferences') is null then
    return true;
  end if;

  select column_name into v_column
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'notification_preferences'
    and column_name in (
      v_category,
      v_category || '_enabled',
      v_category || '_push'
    )
  order by case column_name
    when v_category then 0
    when v_category || '_enabled' then 1
    else 2
  end
  limit 1;

  if v_column is not null then
    execute format(
      'select %I from public.notification_preferences where user_id = $1',
      v_column
    ) into v_allowed using p_user_id;
    return coalesce(v_allowed, true);
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notification_preferences'
      and column_name = 'categories'
      and udt_name = 'jsonb'
  ) then
    execute
      'select categories from public.notification_preferences where user_id = $1'
      into v_categories using p_user_id;
    if v_categories is null or not (v_categories ? v_category) then
      return true;
    end if;
    return coalesce((v_categories ->> v_category)::boolean, true);
  end if;

  return true;
exception
  when others then
    return true;
end;
$$;

comment on function public.push_allowed(uuid, text) is
  'Whether a notification type may be pushed. Unknown types are refused. Missing preferences allow the known categories.';

revoke all on function public.push_allowed(uuid, text) from public, anon, authenticated;
grant execute on function public.push_allowed(uuid, text) to service_role;

create or replace function public.notify_push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
begin
  v_url := nullif(current_setting('app.settings.push_function_url', true), '');
  v_secret := nullif(current_setting('app.settings.push_webhook_secret', true), '');
  if v_url is null or v_secret is null then
    return new;
  end if;
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'net' and p.proname = 'http_post'
  ) then
    return new;
  end if;
  if not public.push_allowed(new.user_id, new.type) then
    return new;
  end if;
  begin
    perform net.http_post(
      url := v_url,
      body := jsonb_build_object(
        'notification_id', new.id,
        'user_id', new.user_id,
        'type', new.type
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-homizi-push-secret', v_secret
      )
    );
  exception
    when others then
      return new;
  end;
  return new;
end;
$$;

comment on function public.notify_push_on_notification() is
  'Posts a new in-app notification id to send-push. No-ops until the push URL and secret are set. Never blocks the insert.';

revoke all on function public.notify_push_on_notification() from public, anon, authenticated;

drop trigger if exists notifications_send_push on public.notifications;
create trigger notifications_send_push
  after insert on public.notifications
  for each row execute function public.notify_push_on_notification();
