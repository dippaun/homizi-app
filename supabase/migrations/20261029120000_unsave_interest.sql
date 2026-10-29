-- Removes the signed-in user's save on one target.
-- Like and pass rows stay. The client cannot delete interests under RLS.

create or replace function public.unsave_interest(
  p_target_type public.interest_target_type,
  p_target_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;
  if p_target_id is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  delete from public.interests
  where actor_user_id = v_uid
    and target_type = p_target_type
    and target_id = p_target_id
    and action = 'save'
  returning id into v_id;

  return jsonb_build_object(
    'ok', true,
    'interest_id', v_id,
    'idempotent', v_id is null
  );
end;
$$;

revoke all on function public.unsave_interest(public.interest_target_type, uuid) from public, anon;
grant execute on function public.unsave_interest(public.interest_target_type, uuid) to authenticated;
