-- PROPOSED, NOT APPLIED. Do not run until the owner approves this exact file.
--
-- HOMIZI Premium keeps its source of truth in RevenueCat (entitlement
-- `premium`). This optional table mirrors the entitlement so server-side
-- rules (for example "unlimited owner contacts") can read it without calling
-- RevenueCat. Nothing in the app depends on it yet: the app reads the
-- entitlement from the RevenueCat SDK.
--
-- Writes would come from a future RevenueCat webhook edge function running
-- with the service role. Clients can read only their own row.

create table if not exists public.premium_entitlements (
  user_id uuid primary key references auth.users (id) on delete cascade,
  plan text not null check (plan in ('monthly', 'annual')),
  is_active boolean not null default true,
  expires_at timestamptz,
  source text not null default 'revenuecat',
  is_sandbox boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.premium_entitlements enable row level security;

drop policy if exists premium_entitlements_select_own
  on public.premium_entitlements;
create policy premium_entitlements_select_own
  on public.premium_entitlements
  for select
  to authenticated
  using (user_id = (select auth.uid()));

-- No insert, update, or delete policy: clients cannot grant themselves Premium.
revoke all on public.premium_entitlements from anon;
revoke insert, update, delete on public.premium_entitlements from authenticated;
