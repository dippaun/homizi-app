-- The hosted SQL editor may have skipped the trigger on auth.users.
-- This function creates the same rows on first sign-in, for the caller only.

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
end;
$$;

revoke all on function public.ensure_own_account() from public, anon;
grant execute on function public.ensure_own_account() to authenticated;

do $$
begin
  drop trigger if exists on_auth_user_created on auth.users;
  create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_auth_user();
exception
  when insufficient_privilege then
    raise notice 'auth.users trigger skipped: %', sqlerrm;
end $$;
