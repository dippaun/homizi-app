-- delete_own_account runs as its owner (postgres). storage.objects has row
-- level security, and the listing-photos delete policy is only for the
-- authenticated role, so the owner delete matched no rows and left the
-- caller's photos in place. This policy lets that function remove objects
-- under the signed-in user's folder. It does not grant the role to clients.

do $$
begin
  if to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; listing photo delete policy skipped';
    return;
  end if;
  execute 'drop policy if exists listing_photos_delete_by_owner on storage.objects';
  execute $policy$
    create policy listing_photos_delete_by_owner on storage.objects
    for delete to postgres
    using (
      bucket_id = 'listing-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
exception
  when others then
    raise notice 'listing photo delete policy skipped: %', sqlerrm;
end
$$;

create or replace function public.delete_own_account()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_storage_removed boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  if to_regclass('storage.objects') is not null then
    begin
      -- storage.protect_delete blocks SQL deletes unless this setting is on.
      perform set_config('storage.allow_delete_query', 'true', true);
      delete from storage.objects
      where bucket_id = 'listing-photos'
        and split_part(name, '/', 1) = v_uid::text;
      v_storage_removed := true;
    exception
      when insufficient_privilege or undefined_table then
        v_storage_removed := false;
    end;
  end if;

  delete from public.reports
  where reporter_id = v_uid
     or target_id = v_uid
     or target_id in (
       select id from public.properties where host_user_id = v_uid
     )
     or target_id in (
       select id from public.listing_requirements where user_id = v_uid
     )
     or target_id in (
       select m.id
       from public.messages m
       join public.conversations c on c.id = m.conversation_id
       join public.matches mt on mt.id = c.match_id
       where mt.participant_a = v_uid or mt.participant_b = v_uid
     );

  delete from public.notifications
  where user_id <> v_uid
    and payload_minimal ->> 'match_id' in (
      select id::text
      from public.matches
      where participant_a = v_uid or participant_b = v_uid
    );

  delete from public.interests
  where (
    target_type = 'user' and target_id = v_uid
  ) or (
    target_type = 'property'
    and target_id in (select id from public.properties where host_user_id = v_uid)
  ) or (
    target_type = 'listing_requirement'
    and target_id in (
      select id from public.listing_requirements where user_id = v_uid
    )
  );

  delete from public.matches
  where participant_a = v_uid or participant_b = v_uid;

  delete from public.properties
  where host_user_id = v_uid;

  delete from auth.users
  where id = v_uid;

  return jsonb_build_object('ok', true, 'storage_removed', v_storage_removed);
end;
$$;

comment on function public.delete_own_account() is
  'The client lists and removes listing-photos under the user id, calls this function, then auth.signOut. This function deletes those storage objects, related rows, and auth.users. Cascades remove the profile, private contact, preferences, and messages. The body has no phone, email, or address_line.';
