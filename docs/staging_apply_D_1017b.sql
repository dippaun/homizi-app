-- HOMIZI integrations batch for a project that already ran
-- docs/staging_apply.sql, docs/staging_apply_next.sql,
-- docs/staging_apply_B_1017.sql, docs/staging_apply_C_1017.sql,
-- docs/staging_apply_B_1017b.sql, and docs/staging_apply_C_1017b.sql.
-- Paste this whole file into the dashboard SQL editor. Running it again is safe.
--
-- It applies:
--   20261017180000_map_coordinates.sql
--   20261017180100_device_tokens.sql
--   20261017180200_payments.sql
--   20261017180300_agreements_kyc.sql
--   20261017180400_service_leads.sql
-- No phone, email, Aadhaar number, or payment secret is inserted.

-- Public map points are locality-level. Exact coordinates stay on
-- property_private_details and leave get_precise_address only for the host
-- or after an accepted visit.

alter table public.properties
  add column if not exists approx_latitude numeric(6, 3),
  add column if not exists approx_longitude numeric(6, 3);

alter table public.properties
  drop constraint if exists properties_approx_pair;
alter table public.properties
  add constraint properties_approx_pair check (
    (approx_latitude is null and approx_longitude is null)
    or (
      approx_latitude is not null
      and approx_longitude is not null
      and approx_latitude between 6 and 37
      and approx_longitude between 68 and 98
    )
  );

comment on column public.properties.approx_latitude is
  'Public locality centre, snapped to 3 decimals. Not a building point.';
comment on column public.properties.approx_longitude is
  'Public locality centre, snapped to 3 decimals. Not a building point.';

create or replace function public.properties_snap_approx()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.approx_latitude is not null then
    new.approx_latitude := round(new.approx_latitude, 3);
  end if;
  if new.approx_longitude is not null then
    new.approx_longitude := round(new.approx_longitude, 3);
  end if;
  return new;
end;
$$;

drop trigger if exists properties_snap_approx on public.properties;
create trigger properties_snap_approx
  before insert or update of approx_latitude, approx_longitude
  on public.properties
  for each row execute function public.properties_snap_approx();

revoke all on function public.properties_snap_approx() from public, anon, authenticated;

grant insert (approx_latitude, approx_longitude)
  on public.properties to authenticated;
grant update (approx_latitude, approx_longitude)
  on public.properties to authenticated;

-- Backfill rows that already exist on a database seeded before this migration.
update public.properties
set approx_latitude = 12.935, approx_longitude = 77.624
where id = '22222222-2222-4222-8222-222222222201'
  and approx_latitude is null;

update public.properties
set approx_latitude = 18.559, approx_longitude = 73.787
where id = '22222222-2222-4222-8222-222222222202'
  and approx_latitude is null;

update public.property_private_details
set latitude = 12.935812, longitude = 77.625104
where property_id = '22222222-2222-4222-8222-222222222201'
  and latitude is null;

create or replace function public.get_precise_address(p_property_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_property public.properties;
  v_private public.property_private_details;
  v_agreed boolean := false;
  v_payload jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated', 'revealed', false);
  end if;
  select * into v_property from public.properties where id = p_property_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found', 'revealed', false);
  end if;
  if v_property.host_user_id <> v_uid
     and (
       v_property.status <> 'published'
       or public.is_blocked_with(v_property.host_user_id)
     ) then
    return jsonb_build_object('ok', false, 'error', 'not_found', 'revealed', false);
  end if;

  if v_property.host_user_id = v_uid then
    v_agreed := true;
  else
    select exists (
      select 1
      from public.visit_requests v
      join public.matches m on m.id = v.match_id
      where v.status in ('accepted', 'completed')
        and m.status = 'active'
        and (
          (m.participant_a = v_uid and m.participant_b = v_property.host_user_id)
          or (m.participant_b = v_uid and m.participant_a = v_property.host_user_id)
        )
    ) into v_agreed;
  end if;

  if not v_agreed then
    return jsonb_build_object('ok', true, 'revealed', false);
  end if;

  select * into v_private
  from public.property_private_details
  where property_id = p_property_id;
  if not found
     or v_private.address_line is null
     or char_length(btrim(v_private.address_line)) < 1 then
    return jsonb_build_object('ok', true, 'revealed', false);
  end if;

  v_payload := jsonb_build_object(
    'ok', true,
    'revealed', true,
    'address_line', v_private.address_line,
    'landmark', v_private.landmark
  );
  if v_private.latitude is not null then
    v_payload := v_payload || jsonb_build_object('latitude', v_private.latitude);
  end if;
  if v_private.longitude is not null then
    v_payload := v_payload || jsonb_build_object('longitude', v_private.longitude);
  end if;
  return v_payload;
end;
$$;

comment on function public.get_precise_address(uuid) is
  'Street line and exact coordinates for the host, or after an accepted visit. Hidden payloads omit latitude and longitude. Never returns phone or email.';

revoke all on function public.get_precise_address(uuid) from public, anon;
grant execute on function public.get_precise_address(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261017180000',
  'map_coordinates',
  array['docs/staging_apply_D_1017b.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

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

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261017180100',
  'device_tokens',
  array['docs/staging_apply_D_1017b.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

-- Extends the deferred payments placeholder. Clients still cannot insert
-- or update. Demo rows are written by create_demo_payment. Razorpay test
-- orders are written by the service role from an Edge Function.

alter table public.payments
  add column if not exists match_id uuid references public.matches (id),
  add column if not exists payee_user_id uuid references public.users (id),
  add column if not exists kind text,
  add column if not exists period_label text,
  add column if not exists provider text not null default 'demo',
  add column if not exists provider_order_id text,
  add column if not exists receipt_id text;

alter table public.payments drop constraint if exists payments_amount_inr_check;
alter table public.payments
  add constraint payments_amount_inr_check check (
    amount_inr >= 0 and amount_inr <= 10000000
  );

alter table public.payments drop constraint if exists payments_kind;
alter table public.payments
  add constraint payments_kind check (
    kind is null or kind in ('rent', 'deposit', 'maintenance')
  );

alter table public.payments drop constraint if exists payments_provider;
alter table public.payments
  add constraint payments_provider check (provider in ('demo', 'razorpay'));

alter table public.payments drop constraint if exists payments_period_label;
alter table public.payments
  add constraint payments_period_label check (
    period_label is null
    or (
      char_length(period_label) <= 40
      and position('@' in period_label) = 0
    )
  );

comment on table public.payments is
  'Rent, deposit, or maintenance between a match. No card data. Clients cannot write. Razorpay is test mode only.';

drop policy if exists payments_select_own on public.payments;
drop policy if exists payments_select_party on public.payments;
create policy payments_select_party on public.payments
  for select to authenticated
  using (user_id = auth.uid() or payee_user_id = auth.uid());

create or replace function public.payment_public_json(p public.payments)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id,
    'match_id', p.match_id,
    'kind', p.kind,
    'amount_inr', p.amount_inr,
    'status', p.status,
    'provider', p.provider,
    'period_label', p.period_label,
    'provider_order_id', p.provider_order_id,
    'receipt_id', p.receipt_id
  );
$$;

revoke all on function public.payment_public_json(public.payments) from public, anon, authenticated;
grant execute on function public.payment_public_json(public.payments) to service_role;

create or replace function public.create_demo_payment(
  p_match_id uuid,
  p_kind text,
  p_amount_inr integer,
  p_period_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_payee uuid;
  v_row public.payments;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_kind is null or p_kind not in ('rent', 'deposit', 'maintenance') then
    return jsonb_build_object('ok', false, 'error', 'kind');
  end if;
  if p_amount_inr is null or p_amount_inr < 1 or p_amount_inr > 10000000 then
    return jsonb_build_object('ok', false, 'error', 'amount');
  end if;
  if p_period_label is not null and (
    char_length(p_period_label) > 40 or position('@' in p_period_label) > 0
  ) then
    return jsonb_build_object('ok', false, 'error', 'period');
  end if;
  select * into v_match from public.matches where id = p_match_id;
  if not found or v_match.status <> 'active' then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  if v_match.participant_a = v_uid then
    v_payee := v_match.participant_b;
  elsif v_match.participant_b = v_uid then
    v_payee := v_match.participant_a;
  else
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  insert into public.payments (
    user_id, payee_user_id, match_id, kind, amount_inr, currency,
    status, provider, period_label
  ) values (
    v_uid, v_payee, p_match_id, p_kind, p_amount_inr, 'INR',
    'pending', 'demo', nullif(btrim(p_period_label), '')
  )
  returning * into v_row;
  return jsonb_build_object(
    'ok', true,
    'payment', public.payment_public_json(v_row)
  );
end;
$$;

create or replace function public.complete_demo_payment(
  p_payment_id uuid,
  p_success boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.payments;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_row from public.payments where id = p_payment_id;
  if not found or v_row.user_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_row.provider <> 'demo' then
    return jsonb_build_object('ok', false, 'error', 'not_demo');
  end if;
  if v_row.status <> 'pending' then
    return jsonb_build_object(
      'ok', true,
      'payment', public.payment_public_json(v_row)
    );
  end if;
  update public.payments
  set status = case when p_success then 'succeeded'::public.payment_status
                     else 'failed'::public.payment_status end
  where id = p_payment_id
  returning * into v_row;
  return jsonb_build_object(
    'ok', true,
    'payment', public.payment_public_json(v_row)
  );
end;
$$;

revoke all on function public.create_demo_payment(uuid, text, integer, text)
  from public, anon;
revoke all on function public.complete_demo_payment(uuid, boolean)
  from public, anon;
grant execute on function public.create_demo_payment(uuid, text, integer, text)
  to authenticated, service_role;
grant execute on function public.complete_demo_payment(uuid, boolean)
  to authenticated, service_role;

comment on function public.create_demo_payment(uuid, text, integer, text) is
  'Records a demo payment for a match participant. No money moves.';
comment on function public.complete_demo_payment(uuid, boolean) is
  'Marks a demo payment succeeded or failed. Refuses Razorpay rows.';

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261017180200',
  'payments',
  array['docs/staging_apply_D_1017b.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

-- Rent agreements and identity checks. verification_status on this table
-- is written by apply_verification_result, which refuses a signed-in user.
-- Raw Aadhaar numbers and documents are rejected. profiles.verification_status
-- stays the existing mock enum.

create table if not exists public.agreements (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id),
  created_by uuid not null references public.users (id),
  title text not null,
  draft_body text not null,
  status text not null default 'draft',
  provider text not null default 'demo',
  provider_reference text,
  stamp_amount_inr integer,
  source_draft_id uuid,
  tenant_signed_at timestamptz,
  owner_signed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint agreements_status check (
    status in (
      'draft',
      'sent',
      'tenant_signed',
      'owner_signed',
      'completed',
      'declined',
      'expired'
    )
  ),
  constraint agreements_provider check (provider in ('demo', 'digio')),
  constraint agreements_title check (
    char_length(btrim(title)) between 3 and 120
    and position('@' in title) = 0
  ),
  constraint agreements_body check (
    char_length(draft_body) between 1 and 8000
    and position('@' in draft_body) = 0
    and draft_body !~ '[0-9]{12}'
  ),
  constraint agreements_stamp check (
    stamp_amount_inr is null or stamp_amount_inr >= 0
  )
);

comment on table public.agreements is
  'E-sign status for a match. source_draft_id has no foreign key so a later draft table can arrive. Digio status is server-only.';
comment on column public.agreements.source_draft_id is
  'Optional id of a rent_agreement_drafts row. The foreign key is added when that table exists.';

do $agreements_draft_fk$
begin
  if to_regclass('public.rent_agreement_drafts') is not null
     and not exists (
       select 1
       from pg_constraint
       where conname = 'agreements_source_draft_fkey'
     ) then
    alter table public.agreements
      add constraint agreements_source_draft_fkey
      foreign key (source_draft_id)
      references public.rent_agreement_drafts (id)
      on delete set null;
  end if;
end
$agreements_draft_fk$;

drop trigger if exists agreements_set_updated_at on public.agreements;
create trigger agreements_set_updated_at
  before update on public.agreements
  for each row execute function public.set_updated_at();

alter table public.agreements enable row level security;

drop policy if exists agreements_select_party on public.agreements;
create policy agreements_select_party on public.agreements
  for select to authenticated
  using (
    exists (
      select 1
      from public.matches m
      where m.id = match_id
        and (m.participant_a = auth.uid() or m.participant_b = auth.uid())
    )
  );

grant select on public.agreements to authenticated;
grant all on public.agreements to service_role;

create table if not exists public.identity_verifications (
  user_id uuid primary key references public.users (id) on delete cascade,
  verification_status text not null default 'not_started',
  provider text not null default 'demo',
  document_kind text,
  provider_reference text,
  masked_last4 text,
  consented_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint identity_verifications_status check (
    verification_status in (
      'not_started',
      'consent_given',
      'pending',
      'verified',
      'rejected'
    )
  ),
  constraint identity_verifications_provider check (provider in ('demo', 'digio')),
  constraint identity_verifications_kind check (
    document_kind is null
    or document_kind in ('digilocker', 'aadhaar_offline', 'pan')
  ),
  constraint identity_verifications_mask check (
    masked_last4 is null or masked_last4 ~ '^[0-9A-Z]{4}$'
  ),
  constraint identity_verifications_reference check (
    provider_reference is null or provider_reference !~ '[0-9]{12}'
  )
);

comment on table public.identity_verifications is
  'Status, provider reference, and masked last 4 only. No Aadhaar number and no document.';

drop trigger if exists identity_verifications_set_updated_at
  on public.identity_verifications;
create trigger identity_verifications_set_updated_at
  before update on public.identity_verifications
  for each row execute function public.set_updated_at();

create or replace function public.identity_verifications_guard()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_role text := coalesce(auth.role(), '');
begin
  if new.provider_reference is not null and new.provider_reference ~ '[0-9]{12}' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  if new.masked_last4 is not null and new.masked_last4 !~ '^[0-9A-Z]{4}$' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  if (
    current_user in ('authenticated', 'anon')
    or v_role in ('authenticated', 'anon')
  ) and new.verification_status in ('pending', 'verified', 'rejected')
     and (
       tg_op = 'INSERT'
       or old.verification_status is distinct from new.verification_status
     ) then
    raise exception 'verification status is server-only' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists identity_verifications_guard on public.identity_verifications;
create trigger identity_verifications_guard
  before insert or update on public.identity_verifications
  for each row execute function public.identity_verifications_guard();

revoke all on function public.identity_verifications_guard() from public, anon, authenticated;

alter table public.identity_verifications enable row level security;

drop policy if exists identity_verifications_select_own on public.identity_verifications;
create policy identity_verifications_select_own on public.identity_verifications
  for select to authenticated
  using (user_id = auth.uid());

grant select on public.identity_verifications to authenticated;
grant all on public.identity_verifications to service_role;

create or replace function public.agreement_public_json(p public.agreements)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id,
    'title', p.title,
    'status', p.status,
    'provider', p.provider,
    'provider_reference', p.provider_reference,
    'stamp_amount_inr', p.stamp_amount_inr,
    'source_draft_id', p.source_draft_id,
    'draft_body', p.draft_body
  );
$$;

create or replace function public.identity_public_json(p public.identity_verifications)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'verification_status', p.verification_status,
    'provider', p.provider,
    'provider_reference', p.provider_reference,
    'document_kind', p.document_kind,
    'masked_last4', p.masked_last4
  );
$$;

revoke all on function public.agreement_public_json(public.agreements)
  from public, anon, authenticated;
revoke all on function public.identity_public_json(public.identity_verifications)
  from public, anon, authenticated;
grant execute on function public.agreement_public_json(public.agreements) to service_role;
grant execute on function public.identity_public_json(public.identity_verifications)
  to service_role;

create or replace function public.create_agreement(
  p_match_id uuid,
  p_title text,
  p_draft_body text,
  p_stamp_amount_inr integer default null,
  p_source_draft_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.agreements;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if not exists (
    select 1
    from public.matches m
    where m.id = p_match_id
      and m.status = 'active'
      and (m.participant_a = v_uid or m.participant_b = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  if p_title is null
     or char_length(btrim(p_title)) < 3
     or char_length(btrim(p_title)) > 120
     or position('@' in p_title) > 0
     or p_draft_body is null
     or char_length(p_draft_body) < 1
     or char_length(p_draft_body) > 8000
     or position('@' in p_draft_body) > 0
     or p_draft_body ~ '[0-9]{12}' then
    return jsonb_build_object('ok', false, 'error', 'draft');
  end if;
  insert into public.agreements (
    match_id, created_by, title, draft_body, status, provider,
    stamp_amount_inr, source_draft_id
  ) values (
    p_match_id, v_uid, btrim(p_title), p_draft_body, 'draft', 'demo',
    p_stamp_amount_inr, p_source_draft_id
  )
  returning * into v_row;
  return jsonb_build_object('ok', true, 'agreement', public.agreement_public_json(v_row));
end;
$$;

create or replace function public.send_agreement(p_agreement_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.agreements;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  select * into v_row from public.agreements where id = p_agreement_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if not exists (
    select 1 from public.matches m
    where m.id = v_row.match_id
      and (m.participant_a = v_uid or m.participant_b = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  if v_row.provider <> 'demo' then
    return jsonb_build_object('ok', false, 'error', 'provider');
  end if;
  if v_row.status = 'draft' then
    update public.agreements
    set status = 'sent'
    where id = p_agreement_id
    returning * into v_row;
  end if;
  return jsonb_build_object('ok', true, 'agreement', public.agreement_public_json(v_row));
end;
$$;

create or replace function public.demo_sign_agreement(
  p_agreement_id uuid,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.agreements;
  v_next text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_role is null or p_role not in ('tenant', 'owner') then
    return jsonb_build_object('ok', false, 'error', 'role');
  end if;
  select * into v_row from public.agreements where id = p_agreement_id;
  if not found or v_row.provider <> 'demo' then
    return jsonb_build_object('ok', false, 'error', 'not_demo');
  end if;
  if not exists (
    select 1 from public.matches m
    where m.id = v_row.match_id
      and (m.participant_a = v_uid or m.participant_b = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_participant');
  end if;
  v_next := case
    when v_row.status = 'sent' and p_role = 'tenant' then 'tenant_signed'
    when v_row.status = 'sent' and p_role = 'owner' then 'owner_signed'
    when v_row.status = 'tenant_signed' and p_role = 'owner' then 'completed'
    when v_row.status = 'owner_signed' and p_role = 'tenant' then 'completed'
    else null
  end;
  if v_next is null then
    return jsonb_build_object('ok', false, 'error', 'status');
  end if;
  update public.agreements
  set
    status = v_next,
    tenant_signed_at = case
      when p_role = 'tenant' then coalesce(tenant_signed_at, now())
      else tenant_signed_at
    end,
    owner_signed_at = case
      when p_role = 'owner' then coalesce(owner_signed_at, now())
      else owner_signed_at
    end
  where id = p_agreement_id
  returning * into v_row;
  return jsonb_build_object('ok', true, 'agreement', public.agreement_public_json(v_row));
end;
$$;

create or replace function public.apply_esign_result(
  p_agreement_id uuid,
  p_status text,
  p_provider_reference text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.agreements;
begin
  if coalesce(auth.role(), '') in ('authenticated', 'anon') then
    raise exception 'agreement status is server-only' using errcode = '42501';
  end if;
  if p_status is null or p_status not in (
    'sent', 'tenant_signed', 'owner_signed', 'completed', 'declined', 'expired'
  ) then
    return jsonb_build_object('ok', false, 'error', 'status');
  end if;
  if p_provider_reference is not null and (
    position('@' in p_provider_reference) > 0
    or p_provider_reference ~ '[0-9]{12}'
  ) then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  update public.agreements
  set
    status = p_status,
    provider = 'digio',
    provider_reference = coalesce(p_provider_reference, provider_reference)
  where id = p_agreement_id
  returning * into v_row;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'agreement', public.agreement_public_json(v_row));
end;
$$;

create or replace function public.record_kyc_consent(p_document_kind text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.identity_verifications;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_document_kind is null
     or p_document_kind not in ('digilocker', 'aadhaar_offline', 'pan') then
    return jsonb_build_object('ok', false, 'error', 'kind');
  end if;
  insert into public.identity_verifications (
    user_id, verification_status, provider, document_kind, consented_at
  ) values (
    v_uid, 'consent_given', 'demo', p_document_kind, now()
  )
  on conflict (user_id) do update
  set
    document_kind = excluded.document_kind,
    consented_at = now(),
    verification_status = case
      when public.identity_verifications.verification_status in (
        'pending', 'verified', 'rejected'
      ) then public.identity_verifications.verification_status
      else 'consent_given'
    end
  returning * into v_row;
  return jsonb_build_object(
    'ok', true,
    'verification', public.identity_public_json(v_row)
  );
end;
$$;

create or replace function public.apply_verification_result(
  p_user_id uuid,
  p_status text,
  p_provider text,
  p_reference text,
  p_masked_last4 text,
  p_document_kind text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.identity_verifications;
begin
  if coalesce(auth.role(), '') in ('authenticated', 'anon') then
    raise exception 'verification status is server-only' using errcode = '42501';
  end if;
  if p_status is null or p_status not in ('pending', 'verified', 'rejected') then
    return jsonb_build_object('ok', false, 'error', 'status');
  end if;
  if p_provider is null or p_provider not in ('demo', 'digio') then
    return jsonb_build_object('ok', false, 'error', 'provider');
  end if;
  if p_reference is not null and p_reference ~ '[0-9]{12}' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  if p_masked_last4 is not null and p_masked_last4 !~ '^[0-9A-Z]{4}$' then
    raise exception 'raw identity numbers are not stored' using errcode = '22023';
  end if;
  insert into public.identity_verifications (
    user_id, verification_status, provider, document_kind,
    provider_reference, masked_last4, consented_at
  ) values (
    p_user_id, p_status, p_provider, p_document_kind,
    p_reference, p_masked_last4, now()
  )
  on conflict (user_id) do update
  set
    verification_status = excluded.verification_status,
    provider = excluded.provider,
    document_kind = coalesce(excluded.document_kind, public.identity_verifications.document_kind),
    provider_reference = excluded.provider_reference,
    masked_last4 = excluded.masked_last4
  returning * into v_row;
  return jsonb_build_object(
    'ok', true,
    'verification', public.identity_public_json(v_row)
  );
end;
$$;

revoke all on function public.create_agreement(uuid, text, text, integer, uuid)
  from public, anon;
revoke all on function public.send_agreement(uuid) from public, anon;
revoke all on function public.demo_sign_agreement(uuid, text) from public, anon;
revoke all on function public.apply_esign_result(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.record_kyc_consent(text) from public, anon;
revoke all on function public.apply_verification_result(uuid, text, text, text, text, text)
  from public, anon, authenticated;

grant execute on function public.create_agreement(uuid, text, text, integer, uuid)
  to authenticated, service_role;
grant execute on function public.send_agreement(uuid) to authenticated, service_role;
grant execute on function public.demo_sign_agreement(uuid, text)
  to authenticated, service_role;
grant execute on function public.record_kyc_consent(text) to authenticated, service_role;
grant execute on function public.apply_esign_result(uuid, text, text) to service_role;
grant execute on function public.apply_verification_result(uuid, text, text, text, text, text)
  to service_role;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261017180300',
  'agreements_kyc',
  array['docs/staging_apply_D_1017b.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

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

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261017180400',
  'service_leads',
  array['docs/staging_apply_D_1017b.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

do $homizi_d_check$
begin
  if to_regprocedure('public.get_precise_address(uuid)') is null then
    raise exception 'get_precise_address was not created';
  end if;
  if to_regclass('public.device_tokens') is null then
    raise exception 'device_tokens was not created';
  end if;
  if to_regprocedure('public.create_demo_payment(uuid, text, integer, text)') is null then
    raise exception 'create_demo_payment was not created';
  end if;
  if to_regclass('public.agreements') is null
     or to_regclass('public.identity_verifications') is null then
    raise exception 'agreements or identity_verifications was not created';
  end if;
  if to_regclass('public.service_leads') is null then
    raise exception 'service_leads was not created';
  end if;
  if (
    select count(*)
    from supabase_migrations.schema_migrations
    where version in (
      '20261017180000',
      '20261017180100',
      '20261017180200',
      '20261017180300',
      '20261017180400'
    )
  ) <> 5 then
    raise exception 'integrations migrations were not recorded';
  end if;
end
$homizi_d_check$;
