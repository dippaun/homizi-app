-- Profile activity, notification categories, rent tools, and support tickets.
-- Own-row RLS. Staff can read support tickets through staff_roles.
-- Notification payloads stay ids only. No phone, email, or map provider.

alter table public.notifications
  add column if not exists dismissed_at timestamptz;

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
    or (
      jsonb_typeof(payload_minimal) = 'object'
      and (payload_minimal - 'deposit_id') = '{}'::jsonb
      and (payload_minimal ->> 'deposit_id')
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
      'listing_interest',
      'photo_request',
      'deposit_reminder'
    )
  );

grant update (dismissed_at) on public.notifications to authenticated;

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.users (id) on delete cascade,
  matches boolean not null default true,
  visits boolean not null default true,
  chat boolean not null default true,
  listings boolean not null default true,
  system boolean not null default true,
  updated_at timestamptz not null default now()
);

comment on table public.notification_preferences is
  'Per-person in-app notification categories. Missing row means every category stays on.';

create table if not exists public.rent_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  tenant_name text not null,
  owner_name text not null,
  property_address text not null,
  monthly_rent_inr integer not null,
  period_start date not null,
  period_end date not null,
  owner_pan text,
  payment_mode text not null,
  created_at timestamptz not null default now(),
  constraint rent_receipts_names check (
    char_length(btrim(tenant_name)) between 2 and 80
    and char_length(btrim(owner_name)) between 2 and 80
  ),
  constraint rent_receipts_address check (
    char_length(btrim(property_address)) between 8 and 240
  ),
  constraint rent_receipts_rent check (
    monthly_rent_inr between 1 and 10000000
  ),
  constraint rent_receipts_period check (period_end >= period_start),
  constraint rent_receipts_pan check (
    owner_pan is null or owner_pan ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
  ),
  constraint rent_receipts_mode check (
    payment_mode in ('upi', 'bank_transfer', 'cash', 'cheque')
  )
);

comment on table public.rent_receipts is
  'Receipts the person typed for a payment made outside HOMIZI. Own row only. HOMIZI does not collect the rent.';

create table if not exists public.rent_agreement_drafts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  licensor_name text not null,
  licensee_name text not null,
  property_address text not null,
  city text not null,
  monthly_rent_inr integer not null,
  deposit_inr integer not null default 0,
  maintenance_inr integer not null default 0,
  start_date date not null,
  term_months integer not null default 11,
  created_at timestamptz not null default now(),
  constraint rent_agreement_names check (
    char_length(btrim(licensor_name)) between 2 and 80
    and char_length(btrim(licensee_name)) between 2 and 80
  ),
  constraint rent_agreement_address check (
    char_length(btrim(property_address)) between 8 and 240
    and char_length(btrim(city)) between 2 and 40
  ),
  constraint rent_agreement_money check (
    monthly_rent_inr between 1 and 10000000
    and deposit_inr between 0 and 100000000
    and maintenance_inr between 0 and 10000000
  ),
  constraint rent_agreement_term check (term_months = 11)
);

comment on table public.rent_agreement_drafts is
  '11-month leave-and-licence draft. Not stamped and not registered.';

create table if not exists public.move_in_checklists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  match_id uuid references public.matches (id) on delete set null,
  title text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint move_in_title check (char_length(btrim(title)) between 3 and 80)
);

create table if not exists public.move_in_items (
  id uuid primary key default gen_random_uuid(),
  checklist_id uuid not null references public.move_in_checklists (id) on delete cascade,
  room text not null,
  item_name text not null,
  condition text not null,
  notes text,
  photo_path text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint move_in_item_room check (char_length(btrim(room)) between 2 and 40),
  constraint move_in_item_name check (char_length(btrim(item_name)) between 1 and 80),
  constraint move_in_item_condition check (
    condition in ('good', 'fair', 'worn', 'damaged')
  ),
  constraint move_in_item_notes check (
    notes is null or char_length(notes) <= 400
  ),
  constraint move_in_item_photo check (
    photo_path is null
    or (
      char_length(photo_path) between 3 and 240
      and photo_path !~ '\.\.'
      and photo_path !~ '@'
    )
  ),
  constraint move_in_item_sort check (sort_order >= 0)
);

comment on table public.move_in_checklists is
  'Room-by-room move-in notes. The owner writes. The other person on the linked match can read.';

create table if not exists public.deposit_trackers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  property_label text not null,
  deposit_paid_inr integer not null,
  refund_due_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint deposit_label check (char_length(btrim(property_label)) between 3 and 80),
  constraint deposit_paid check (deposit_paid_inr between 0 and 100000000)
);

create table if not exists public.deposit_deductions (
  id uuid primary key default gen_random_uuid(),
  tracker_id uuid not null references public.deposit_trackers (id) on delete cascade,
  label text not null,
  amount_inr integer not null,
  created_at timestamptz not null default now(),
  constraint deposit_deduction_label check (char_length(btrim(label)) between 2 and 80),
  constraint deposit_deduction_amount check (amount_inr between 0 and 100000000)
);

comment on table public.deposit_trackers is
  'Deposit the person already paid outside HOMIZI. A reminder is an in-app notification only.';

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  topic text not null,
  message text not null,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  constraint support_tickets_topic check (
    topic in ('renting', 'flatmates', 'safety', 'payments', 'other')
  ),
  constraint support_tickets_message check (
    char_length(btrim(message)) between 10 and 1000
    and message !~ '@'
    and message !~ '[0-9]{10}'
  ),
  constraint support_tickets_status check (status = 'open')
);

comment on table public.support_tickets is
  'In-app support note. No phone or email column. Staff read it through staff_roles.';

create index if not exists rent_receipts_user_idx
  on public.rent_receipts (user_id, created_at desc);
create index if not exists rent_agreement_user_idx
  on public.rent_agreement_drafts (user_id, created_at desc);
create index if not exists move_in_checklists_user_idx
  on public.move_in_checklists (user_id, updated_at desc);
create index if not exists move_in_items_checklist_idx
  on public.move_in_items (checklist_id, sort_order);
create index if not exists deposit_trackers_user_idx
  on public.deposit_trackers (user_id, updated_at desc);
create index if not exists support_tickets_user_idx
  on public.support_tickets (user_id, created_at desc);

drop trigger if exists notification_preferences_set_updated_at
  on public.notification_preferences;
create trigger notification_preferences_set_updated_at
  before update on public.notification_preferences
  for each row execute function public.set_updated_at();

drop trigger if exists move_in_checklists_set_updated_at
  on public.move_in_checklists;
create trigger move_in_checklists_set_updated_at
  before update on public.move_in_checklists
  for each row execute function public.set_updated_at();

drop trigger if exists deposit_trackers_set_updated_at
  on public.deposit_trackers;
create trigger deposit_trackers_set_updated_at
  before update on public.deposit_trackers
  for each row execute function public.set_updated_at();

alter table public.notification_preferences enable row level security;
alter table public.rent_receipts enable row level security;
alter table public.rent_agreement_drafts enable row level security;
alter table public.move_in_checklists enable row level security;
alter table public.move_in_items enable row level security;
alter table public.deposit_trackers enable row level security;
alter table public.deposit_deductions enable row level security;
alter table public.support_tickets enable row level security;

drop policy if exists notification_preferences_own on public.notification_preferences;
create policy notification_preferences_own on public.notification_preferences
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists rent_receipts_own on public.rent_receipts;
create policy rent_receipts_own on public.rent_receipts
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists rent_agreement_drafts_own on public.rent_agreement_drafts;
create policy rent_agreement_drafts_own on public.rent_agreement_drafts
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists move_in_checklists_owner on public.move_in_checklists;
create policy move_in_checklists_owner on public.move_in_checklists
  for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and (
      match_id is null
      or exists (
        select 1
        from public.matches m
        where m.id = match_id
          and auth.uid() in (m.participant_a, m.participant_b)
      )
    )
  );

drop policy if exists move_in_checklists_match_read on public.move_in_checklists;
create policy move_in_checklists_match_read on public.move_in_checklists
  for select to authenticated
  using (
    match_id is not null
    and exists (
      select 1
      from public.matches m
      where m.id = match_id
        and auth.uid() in (m.participant_a, m.participant_b)
    )
  );

drop policy if exists move_in_items_owner on public.move_in_items;
create policy move_in_items_owner on public.move_in_items
  for all to authenticated
  using (
    exists (
      select 1
      from public.move_in_checklists c
      where c.id = checklist_id
        and c.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.move_in_checklists c
      where c.id = checklist_id
        and c.user_id = auth.uid()
    )
  );

drop policy if exists move_in_items_match_read on public.move_in_items;
create policy move_in_items_match_read on public.move_in_items
  for select to authenticated
  using (
    exists (
      select 1
      from public.move_in_checklists c
      join public.matches m on m.id = c.match_id
      where c.id = checklist_id
        and auth.uid() in (m.participant_a, m.participant_b)
    )
  );

drop policy if exists deposit_trackers_own on public.deposit_trackers;
create policy deposit_trackers_own on public.deposit_trackers
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists deposit_deductions_own on public.deposit_deductions;
create policy deposit_deductions_own on public.deposit_deductions
  for all to authenticated
  using (
    exists (
      select 1
      from public.deposit_trackers t
      where t.id = tracker_id
        and t.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.deposit_trackers t
      where t.id = tracker_id
        and t.user_id = auth.uid()
    )
  );

drop policy if exists support_tickets_insert_own on public.support_tickets;
create policy support_tickets_insert_own on public.support_tickets
  for insert to authenticated
  with check (user_id = auth.uid() and status = 'open');

drop policy if exists support_tickets_select on public.support_tickets;
create policy support_tickets_select on public.support_tickets
  for select to authenticated
  using (user_id = auth.uid() or public.is_staff());

revoke all on table public.notification_preferences from public;
revoke all on table public.rent_receipts from public;
revoke all on table public.rent_agreement_drafts from public;
revoke all on table public.move_in_checklists from public;
revoke all on table public.move_in_items from public;
revoke all on table public.deposit_trackers from public;
revoke all on table public.deposit_deductions from public;
revoke all on table public.support_tickets from public;

grant select, insert, update on public.notification_preferences to authenticated;
grant select, insert, update, delete on public.rent_receipts to authenticated;
grant select, insert, update, delete on public.rent_agreement_drafts to authenticated;
grant select, insert, update, delete on public.move_in_checklists to authenticated;
grant select, insert, update, delete on public.move_in_items to authenticated;
grant select, insert, update, delete on public.deposit_trackers to authenticated;
grant select, insert, update, delete on public.deposit_deductions to authenticated;
grant select, insert on public.support_tickets to authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on table public.notification_preferences from anon;
    revoke all on table public.rent_receipts from anon;
    revoke all on table public.rent_agreement_drafts from anon;
    revoke all on table public.move_in_checklists from anon;
    revoke all on table public.move_in_items from anon;
    revoke all on table public.deposit_trackers from anon;
    revoke all on table public.deposit_deductions from anon;
    revoke all on table public.support_tickets from anon;
  end if;
end $$;

create or replace function public.notification_category(p_type text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_type = 'match' then 'matches'
    when p_type = 'message' then 'chat'
    when p_type in (
      'visit_requested',
      'visit_accepted',
      'visit_declined',
      'visit_cancelled'
    ) then 'visits'
    when p_type in ('listing_interest', 'photo_request') then 'listings'
    else 'system'
  end;
$$;

create or replace function public.notification_allowed(
  p_user_id uuid,
  p_type text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select case public.notification_category(p_type)
        when 'matches' then p.matches
        when 'visits' then p.visits
        when 'chat' then p.chat
        when 'listings' then p.listings
        else p.system
      end
      from public.notification_preferences p
      where p.user_id = p_user_id
    ),
    true
  );
$$;

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
  if p_payload ? 'deposit_id' then
    if (p_payload - 'deposit_id') <> '{}'::jsonb then
      return false;
    end if;
    return (p_payload ->> 'deposit_id') ~ v_uuid;
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
    'listing_interest',
    'photo_request',
    'deposit_reminder'
  ) then
    return;
  end if;
  if not public.notification_allowed(p_user_id, p_type) then
    return;
  end if;
  if p_type in ('listing_interest', 'photo_request') then
    if not (
      p_payload ? 'property_id'
      and (p_payload - 'property_id') = '{}'::jsonb
    ) then
      return;
    end if;
  elsif p_type = 'deposit_reminder' then
    if not (
      p_payload ? 'deposit_id'
      and (p_payload - 'deposit_id') = '{}'::jsonb
    ) then
      return;
    end if;
  elsif p_payload ? 'property_id'
    or p_payload ? 'deposit_id'
    or not (p_payload ? 'match_id') then
    return;
  end if;
  if not public.notification_payload_ok(p_payload) then
    return;
  end if;
  insert into public.notifications (user_id, type, payload_minimal)
  values (p_user_id, p_type, p_payload);
end;
$$;

create or replace function public.remind_own_deposit(p_tracker_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_due date;
begin
  if auth.uid() is null then
    raise exception 'Sign in before setting a reminder.';
  end if;
  select user_id, refund_due_on
    into v_owner, v_due
  from public.deposit_trackers
  where id = p_tracker_id;
  if v_owner is null or v_owner <> auth.uid() then
    raise exception 'That deposit record is not yours.';
  end if;
  if v_due is null then
    raise exception 'Add a refund due date before setting a reminder.';
  end if;
  perform public.enqueue_notification(
    auth.uid(),
    'deposit_reminder',
    jsonb_build_object('deposit_id', p_tracker_id)
  );
  return exists (
    select 1
    from public.notifications n
    where n.user_id = auth.uid()
      and n.type = 'deposit_reminder'
      and n.payload_minimal ->> 'deposit_id' = p_tracker_id::text
      and n.created_at >= now() - interval '1 minute'
  );
end;
$$;

create or replace function public.profile_activity()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_saved_count integer;
  v_request_count integer;
  v_visit_count integer;
  v_match_count integer;
  v_viewed_available boolean := false;
  v_viewed_count integer := 0;
  v_saved jsonb := '[]'::jsonb;
  v_viewed jsonb := '[]'::jsonb;
  v_requests jsonb := '[]'::jsonb;
  v_visits jsonb := '[]'::jsonb;
  v_matches jsonb := '[]'::jsonb;
  v_user_col text;
begin
  if v_uid is null then
    raise exception 'Sign in before opening your profile.';
  end if;

  select count(*)::int into v_saved_count
  from public.interests
  where actor_user_id = v_uid
    and action = 'save';

  select coalesce(jsonb_agg(jsonb_build_object(
    'title', s.title,
    'locality', s.locality,
    'city', s.city
  )), '[]'::jsonb)
  into v_saved
  from (
    select p.title, p.locality, p.city
    from public.interests i
    join public.properties p on p.id = i.target_id
    where i.actor_user_id = v_uid
      and i.action = 'save'
      and i.target_type = 'property'
    order by i.updated_at desc
    limit 8
  ) s;

  select count(*)::int into v_request_count
  from public.listing_requirements
  where user_id = v_uid;

  select coalesce(jsonb_agg(jsonb_build_object(
    'city', r.city,
    'budget_min_inr', r.budget_min_inr,
    'budget_max_inr', r.budget_max_inr
  )), '[]'::jsonb)
  into v_requests
  from (
    select city, budget_min_inr, budget_max_inr
    from public.listing_requirements
    where user_id = v_uid
    order by updated_at desc
    limit 8
  ) r;

  select count(*)::int into v_visit_count
  from public.visit_requests vr
  join public.matches m on m.id = vr.match_id
  where v_uid in (m.participant_a, m.participant_b);

  select coalesce(jsonb_agg(jsonb_build_object(
    'status', v.status,
    'on', v.on_day
  )), '[]'::jsonb)
  into v_visits
  from (
    select vr.status::text as status, vr.created_at::date as on_day
    from public.visit_requests vr
    join public.matches m on m.id = vr.match_id
    where v_uid in (m.participant_a, m.participant_b)
    order by vr.created_at desc
    limit 8
  ) v;

  select count(*)::int into v_match_count
  from public.matches
  where status = 'active'
    and v_uid in (participant_a, participant_b);

  select coalesce(jsonb_agg(jsonb_build_object('name', x.name)), '[]'::jsonb)
  into v_matches
  from (
    select coalesce(nullif(btrim(pr.display_name), ''), 'Match') as name
    from public.matches m
    left join public.profiles pr
      on pr.user_id = case
        when m.participant_a = v_uid then m.participant_b
        else m.participant_a
      end
    where m.status = 'active'
      and v_uid in (m.participant_a, m.participant_b)
    order by m.created_at desc
    limit 8
  ) x;

  if to_regclass('public.listing_views') is not null then
    select c.column_name into v_user_col
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'listing_views'
      and c.column_name in ('user_id', 'viewer_user_id', 'viewer_id')
    order by case c.column_name
      when 'user_id' then 1
      when 'viewer_user_id' then 2
      else 3
    end
    limit 1;

    if v_user_col is not null
       and exists (
         select 1
         from information_schema.columns
         where table_schema = 'public'
           and table_name = 'listing_views'
           and column_name = 'property_id'
       ) then
      begin
        execute format(
          'select count(*)::int from public.listing_views where %I = $1',
          v_user_col
        ) into v_viewed_count using v_uid;

        execute format(
          'select coalesce(jsonb_agg(jsonb_build_object('
          || '''title'', x.title, ''locality'', x.locality, ''city'', x.city'
          || ')), ''[]''::jsonb) from ('
          || 'select p.title, p.locality, p.city '
          || 'from public.listing_views lv '
          || 'join public.properties p on p.id = lv.property_id '
          || 'where lv.%I = $1 limit 8) x',
          v_user_col
        ) into v_viewed using v_uid;
        v_viewed_available := true;
      exception
        when others then
          v_viewed_available := false;
          v_viewed_count := 0;
          v_viewed := '[]'::jsonb;
      end;
    end if;
  end if;

  return jsonb_build_object(
    'saved_count', v_saved_count,
    'viewed_available', v_viewed_available,
    'viewed_count', case when v_viewed_available then v_viewed_count else null end,
    'request_count', v_request_count,
    'visit_count', v_visit_count,
    'match_count', v_match_count,
    'saved', v_saved,
    'viewed', v_viewed,
    'requests', v_requests,
    'visits', v_visits,
    'matches', v_matches
  );
end;
$$;

revoke all on function public.notification_category(text) from public;
revoke all on function public.notification_allowed(uuid, text) from public;
revoke all on function public.notification_payload_ok(jsonb) from public;
revoke all on function public.enqueue_notification(uuid, text, jsonb) from public;
revoke all on function public.remind_own_deposit(uuid) from public;
revoke all on function public.profile_activity() from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.notification_category(text) from anon;
    revoke all on function public.notification_allowed(uuid, text) from anon;
    revoke all on function public.notification_payload_ok(jsonb) from anon;
    revoke all on function public.enqueue_notification(uuid, text, jsonb) from anon;
    revoke all on function public.remind_own_deposit(uuid) from anon;
    revoke all on function public.profile_activity() from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    revoke all on function public.notification_category(text) from authenticated;
    revoke all on function public.notification_allowed(uuid, text) from authenticated;
    revoke all on function public.enqueue_notification(uuid, text, jsonb) from authenticated;
  end if;
end $$;

grant execute on function public.notification_payload_ok(jsonb) to authenticated;
grant execute on function public.remind_own_deposit(uuid) to authenticated;
grant execute on function public.profile_activity() to authenticated;

do $homizi_inventory_storage$
begin
  if to_regclass('storage.buckets') is null
     or to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; inventory-photos bucket skipped';
    return;
  end if;
  insert into storage.buckets (id, name, public)
  values ('inventory-photos', 'inventory-photos', false)
  on conflict (id) do update
  set public = excluded.public;
  execute 'drop policy if exists inventory_photos_insert on storage.objects';
  execute 'drop policy if exists inventory_photos_select on storage.objects';
  execute 'drop policy if exists inventory_photos_update on storage.objects';
  execute 'drop policy if exists inventory_photos_delete on storage.objects';
  execute $policy$
    create policy inventory_photos_insert on storage.objects
    for insert to authenticated
    with check (
      bucket_id = 'inventory-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
  execute $policy$
    create policy inventory_photos_select on storage.objects
    for select to authenticated
    using (
      bucket_id = 'inventory-photos'
      and (
        (storage.foldername(name))[1] = auth.uid()::text
        or exists (
          select 1
          from public.move_in_items i
          join public.move_in_checklists c on c.id = i.checklist_id
          join public.matches m on m.id = c.match_id
          where i.photo_path = name
            and auth.uid() in (m.participant_a, m.participant_b)
        )
      )
    )
  $policy$;
  execute $policy$
    create policy inventory_photos_update on storage.objects
    for update to authenticated
    using (
      bucket_id = 'inventory-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
    with check (
      bucket_id = 'inventory-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
  execute $policy$
    create policy inventory_photos_delete on storage.objects
    for delete to authenticated
    using (
      bucket_id = 'inventory-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
exception
  when others then
    raise notice 'inventory-photos storage policies skipped: %', sqlerrm;
end
$homizi_inventory_storage$;
