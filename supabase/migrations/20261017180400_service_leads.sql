-- Home-service requests. The user inserts their own row. Staff can read
-- and update status. No phone column. Email delivery no-ops until the
-- operator sets the lead function URL and secret.

create table if not exists public.service_leads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  service_kind text not null,
  from_locality text not null,
  to_locality text,
  city text not null,
  requested_on date not null,
  home_size text,
  notes text,
  contact_consent boolean not null default false,
  status text not null default 'requested',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_leads_kind check (
    service_kind in (
      'packers_movers',
      'cleaning',
      'painting',
      'ac_repair',
      'plumbing',
      'electrician',
      'carpentry'
    )
  ),
  constraint service_leads_status check (
    status in ('requested', 'contacted', 'closed')
  ),
  constraint service_leads_consent check (contact_consent is true),
  constraint service_leads_from check (
    char_length(btrim(from_locality)) between 2 and 80
    and position('@' in from_locality) = 0
  ),
  constraint service_leads_to check (
    to_locality is null
    or (
      char_length(btrim(to_locality)) between 2 and 80
      and position('@' in to_locality) = 0
    )
  ),
  constraint service_leads_city check (char_length(btrim(city)) between 2 and 40),
  constraint service_leads_notes check (
    notes is null
    or (
      char_length(notes) <= 1000
      and position('@' in notes) = 0
      and notes !~ '[0-9]{10}'
    )
  )
);

comment on table public.service_leads is
  'A request for a HOMIZI partner to call. No partner contract is stored. No phone number is stored on the row.';

drop trigger if exists service_leads_set_updated_at on public.service_leads;
create trigger service_leads_set_updated_at
  before update on public.service_leads
  for each row execute function public.set_updated_at();

alter table public.service_leads enable row level security;

drop policy if exists service_leads_select on public.service_leads;
create policy service_leads_select on public.service_leads
  for select to authenticated
  using (user_id = auth.uid() or public.is_staff());

drop policy if exists service_leads_insert_own on public.service_leads;
create policy service_leads_insert_own on public.service_leads
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and status = 'requested'
    and contact_consent is true
  );

drop policy if exists service_leads_update_staff on public.service_leads;
create policy service_leads_update_staff on public.service_leads
  for update to authenticated
  using (public.is_staff())
  with check (public.is_staff());

grant select, insert on public.service_leads to authenticated;
grant update (status) on public.service_leads to authenticated;
grant all on public.service_leads to service_role;

create or replace function public.notify_service_lead()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
begin
  v_url := nullif(current_setting('app.settings.lead_function_url', true), '');
  v_secret := nullif(current_setting('app.settings.lead_webhook_secret', true), '');
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
  begin
    perform net.http_post(
      url := v_url,
      body := jsonb_build_object('lead_id', new.id),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-homizi-lead-secret', v_secret
      )
    );
  exception
    when others then
      return new;
  end;
  return new;
end;
$$;

comment on function public.notify_service_lead() is
  'Posts a new lead id to notify-service-lead. No-ops until the URL and secret are set. Never blocks the insert.';

revoke all on function public.notify_service_lead() from public, anon, authenticated;

drop trigger if exists service_leads_notify on public.service_leads;
create trigger service_leads_notify
  after insert on public.service_leads
  for each row execute function public.notify_service_lead();
