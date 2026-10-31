-- Paste after HOST / MATCH / LISTING / UNSAVE. Non-destructive advisor fixes.

-- Non-destructive advisor fixes.
-- Sets search_path on helper functions and revokes anon EXECUTE
-- on host onboarding SECURITY DEFINER RPCs. Safe to re-run.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.compatibility_colour(
  score integer,
  important_mismatch boolean
) returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when coalesce(important_mismatch, false) then 'red'
    when score >= 70 then 'green'
    when score >= 40 then 'yellow'
    else 'red'
  end;
$$;

create or replace function public.guard_host_authorization_status()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status = 'verified'
     and auth.uid() is not null
     and not exists (
       select 1 from public.staff_roles as staff
       where staff.user_id = auth.uid()
     )
     and (tg_op = 'INSERT' or old.status is distinct from 'verified') then
    new.status := 'under_review';
  end if;
  return new;
end;
$$;

revoke all on function public.apply_host_onboarding(
  text, text, text, text[], boolean, text, text, text[], text, text, text, jsonb
) from public, anon;

revoke all on function public.read_own_host_legal_name() from public, anon;

grant execute on function public.apply_host_onboarding(
  text, text, text, text[], boolean, text, text, text[], text, text, text, jsonb
) to authenticated;

grant execute on function public.read_own_host_legal_name() to authenticated;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261031134015',
  'fix_function_search_path_and_revoke_anon_host_rpcs',
  array['docs/staging_apply_ADVISOR_1031.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
