-- Shared role contract for HOMIZI.
-- profiles.primary_role is the product role. users.primary_role stays the
-- legacy enum (unset, tenant, host, both) so existing rows and policies keep
-- working.
--
-- Legacy mapping, applied only when profiles.primary_role is still null:
--   tenant -> tenant
--   host   -> host, or broker when host_profiles.host_category is broker
--   both   -> tenant (they were already looking; they can switch to host)
--   unset  -> null, so the role picker still runs

alter table public.profiles
  add column if not exists primary_role text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_primary_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_primary_role_check
      check (primary_role in ('roommate', 'tenant', 'host', 'broker'));
  end if;
end $$;

comment on column public.profiles.primary_role is
  'Product role: roommate, tenant, host, or broker. Null until the person picks. Legacy users.primary_role values are mapped in; both becomes tenant.';

update public.profiles as p
set primary_role = case
  when u.primary_role::text = 'tenant' then 'tenant'
  when u.primary_role::text = 'host'
    and exists (
      select 1
      from public.host_profiles as h
      where h.user_id = p.user_id
        and h.host_category = 'broker'
    ) then 'broker'
  when u.primary_role::text = 'host' then 'host'
  when u.primary_role::text = 'both' then 'tenant'
  else p.primary_role
end
from public.users as u
where u.id = p.user_id
  and p.primary_role is null
  and u.primary_role::text in ('tenant', 'host', 'both');

grant update (primary_role) on public.profiles to authenticated;
