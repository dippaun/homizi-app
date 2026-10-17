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
