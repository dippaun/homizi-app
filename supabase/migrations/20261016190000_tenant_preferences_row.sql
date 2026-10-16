-- A fresh account gets an empty tenant_preferences row.
-- Discover does not read this row as a filter. Blank means show every
-- published home. Safe to run more than once.

create or replace function public.ensure_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := nullif(auth.jwt() ->> 'email', '');
begin
  if v_uid is null then
    raise exception 'Sign in before creating a profile.'
      using errcode = '42501';
  end if;
  insert into public.users (id) values (v_uid) on conflict (id) do nothing;
  insert into public.profiles (user_id) values (v_uid) on conflict (user_id) do nothing;
  insert into public.private_contacts (user_id, email)
  values (v_uid, v_email)
  on conflict (user_id) do update
  set email = coalesce(public.private_contacts.email, excluded.email);
  insert into public.tenant_preferences (user_id)
  values (v_uid)
  on conflict (user_id) do nothing;
end;
$$;

revoke all on function public.ensure_own_account() from public, anon;
grant execute on function public.ensure_own_account() to authenticated;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id) values (new.id) on conflict do nothing;
  insert into public.profiles (user_id) values (new.id) on conflict do nothing;
  insert into public.private_contacts (user_id, email)
  values (new.id, new.email)
  on conflict (user_id) do nothing;
  insert into public.tenant_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

insert into public.tenant_preferences (user_id)
select id from public.users
on conflict (user_id) do nothing;
