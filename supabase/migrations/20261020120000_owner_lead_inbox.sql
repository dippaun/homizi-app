-- Owner lead inbox.
-- A like on the owner's listing, and a visit request tied to that listing,
-- is a lead. The owner sets new, replied, or closed. The audit records who
-- changed it and when. Response time is the gap from the lead to the first
-- replied status. Phone, email, and street address are not stored or returned.

do $owner_lead_types$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'owner_lead_kind'
  ) then
    create type public.owner_lead_kind as enum ('interest', 'visit');
  end if;
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'owner_lead_status'
  ) then
    create type public.owner_lead_status as enum ('new', 'replied', 'closed');
  end if;
end
$owner_lead_types$;

create table if not exists public.owner_leads (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  kind public.owner_lead_kind not null,
  source_id uuid not null,
  person_user_id uuid not null references public.users (id) on delete cascade,
  status public.owner_lead_status not null default 'new',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  first_replied_at timestamptz,
  constraint owner_leads_kind_source unique (kind, source_id)
);

create table if not exists public.owner_lead_audit (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.owner_leads (id) on delete cascade,
  actor_id uuid not null references public.users (id) on delete cascade,
  from_status public.owner_lead_status,
  to_status public.owner_lead_status not null,
  changed_at timestamptz not null default now()
);

comment on table public.owner_leads is
  'Host inbox for a like or a visit on their own listing. No phone, email, or street address.';

comment on table public.owner_lead_audit is
  'Who set an owner lead status, and when. No contact fields.';

do $owner_lead_constraints$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'owner_leads_kind_source'
  ) then
    alter table public.owner_leads
      add constraint owner_leads_kind_source unique (kind, source_id);
  end if;
end
$owner_lead_constraints$;

create index if not exists owner_leads_property_idx
  on public.owner_leads (property_id, created_at desc);

create index if not exists owner_lead_audit_lead_idx
  on public.owner_lead_audit (lead_id, changed_at);

drop trigger if exists owner_leads_set_updated_at on public.owner_leads;
create trigger owner_leads_set_updated_at
  before update on public.owner_leads
  for each row execute function public.set_updated_at();

create or replace function public.sync_owner_lead_interest()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.owner_leads
    where kind = 'interest'
      and source_id = old.id;
    return old;
  end if;

  if new.target_type is distinct from 'property'::public.interest_target_type
     or new.action is distinct from 'like'::public.interest_action then
    delete from public.owner_leads
    where kind = 'interest'
      and source_id = new.id;
    return new;
  end if;

  begin
    insert into public.owner_leads (
      property_id, kind, source_id, person_user_id, created_at
    )
    select
      new.target_id,
      'interest'::public.owner_lead_kind,
      new.id,
      new.actor_user_id,
      new.created_at
    where exists (
      select 1 from public.properties p where p.id = new.target_id
    )
    on conflict on constraint owner_leads_kind_source do nothing;
  exception
    when foreign_key_violation then
      null;
  end;
  return new;
end;
$$;

create or replace function public.sync_owner_lead_visit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.owner_leads
    where kind = 'visit'
      and source_id = old.id;
    return old;
  end if;

  if new.property_id is null then
    delete from public.owner_leads
    where kind = 'visit'
      and source_id = new.id;
    return new;
  end if;

  begin
    insert into public.owner_leads (
      property_id, kind, source_id, person_user_id, created_at
    )
    values (
      new.property_id,
      'visit'::public.owner_lead_kind,
      new.id,
      new.requester_id,
      new.created_at
    )
    on conflict on constraint owner_leads_kind_source do update
      set property_id = excluded.property_id
      where public.owner_leads.property_id is distinct from excluded.property_id;
  exception
    when foreign_key_violation then
      null;
  end;
  return new;
end;
$$;

drop trigger if exists owner_leads_on_interest on public.interests;
create trigger owner_leads_on_interest
  after insert or update of target_type, target_id, action or delete
  on public.interests
  for each row execute function public.sync_owner_lead_interest();

drop trigger if exists owner_leads_on_visit on public.visit_requests;
create trigger owner_leads_on_visit
  after insert or update of property_id, requester_id or delete
  on public.visit_requests
  for each row execute function public.sync_owner_lead_visit();

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
  'Internal lead shape. Display name only. No phone, email, or street address.';

create or replace function public.list_owner_leads(p_property_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_host uuid;
  v_rows jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select host_user_id into v_host
  from public.properties
  where id = p_property_id;
  if v_host is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_host <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;

  select coalesce(
    jsonb_agg(public.owner_lead_json(l.id) order by l.created_at desc),
    '[]'::jsonb
  )
  into v_rows
  from public.owner_leads l
  where l.property_id = p_property_id;

  return jsonb_build_object('ok', true, 'leads', v_rows);
end;
$$;

comment on function public.list_owner_leads(uuid) is
  'Host-only inbox. Each like and each visit on that listing. No phone, email, or street address.';

create or replace function public.set_owner_lead_status(
  p_lead_id uuid,
  p_status text
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
  v_next public.owner_lead_status;
  v_at timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_status is null or p_status not in ('new', 'replied', 'closed') then
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

  v_next := p_status::public.owner_lead_status;
  if v_lead.status = v_next then
    return jsonb_build_object(
      'ok', true,
      'unchanged', true,
      'lead', public.owner_lead_json(p_lead_id)
    );
  end if;

  v_at := clock_timestamp();
  update public.owner_leads
  set status = v_next,
      first_replied_at = case
        when v_next = 'replied'::public.owner_lead_status
             and first_replied_at is null
          then v_at
        else first_replied_at
      end
  where id = p_lead_id;

  insert into public.owner_lead_audit (
    lead_id, actor_id, from_status, to_status, changed_at
  )
  values (p_lead_id, v_uid, v_lead.status, v_next, v_at);

  return jsonb_build_object(
    'ok', true,
    'unchanged', false,
    'lead', public.owner_lead_json(p_lead_id)
  );
end;
$$;

comment on function public.set_owner_lead_status(uuid, text) is
  'Host-only status change. Writes an audit row. Keeps the first replied time.';

revoke all on function public.sync_owner_lead_interest() from public, anon, authenticated;
revoke all on function public.sync_owner_lead_visit() from public, anon, authenticated;
revoke all on function public.owner_lead_json(uuid) from public, anon, authenticated;
revoke all on function public.list_owner_leads(uuid) from public, anon;
revoke all on function public.set_owner_lead_status(uuid, text) from public, anon;

grant execute on function public.list_owner_leads(uuid) to authenticated, service_role;
grant execute on function public.set_owner_lead_status(uuid, text) to authenticated, service_role;

alter table public.owner_leads enable row level security;
alter table public.owner_lead_audit enable row level security;

drop policy if exists owner_leads_select_host on public.owner_leads;
create policy owner_leads_select_host on public.owner_leads
  for select to authenticated
  using (
    exists (
      select 1
      from public.properties p
      where p.id = property_id
        and p.host_user_id = auth.uid()
    )
  );

drop policy if exists owner_lead_audit_select_host on public.owner_lead_audit;
create policy owner_lead_audit_select_host on public.owner_lead_audit
  for select to authenticated
  using (
    exists (
      select 1
      from public.owner_leads l
      join public.properties p on p.id = l.property_id
      where l.id = lead_id
        and p.host_user_id = auth.uid()
    )
  );

revoke all on table public.owner_leads from public, anon, authenticated;
revoke all on table public.owner_lead_audit from public, anon, authenticated;
grant select on table public.owner_leads to authenticated;
grant select on table public.owner_lead_audit to authenticated;
grant all on table public.owner_leads to service_role;
grant all on table public.owner_lead_audit to service_role;

insert into public.owner_leads (
  property_id, kind, source_id, person_user_id, created_at
)
select
  i.target_id,
  'interest'::public.owner_lead_kind,
  i.id,
  i.actor_user_id,
  i.created_at
from public.interests i
join public.properties p on p.id = i.target_id
where i.target_type = 'property'
  and i.action = 'like'
on conflict on constraint owner_leads_kind_source do nothing;

insert into public.owner_leads (
  property_id, kind, source_id, person_user_id, created_at
)
select
  v.property_id,
  'visit'::public.owner_lead_kind,
  v.id,
  v.requester_id,
  v.created_at
from public.visit_requests v
where v.property_id is not null
on conflict on constraint owner_leads_kind_source do nothing;
