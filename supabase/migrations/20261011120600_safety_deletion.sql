-- Report details cannot carry a phone or an email. Account deletion removes
-- the signed-in person on this database. It does not call an outside vendor.

alter table public.reports
  drop constraint if exists reports_details_no_contact;
alter table public.reports
  add constraint reports_details_no_contact check (
    details is null or not public.contains_contact_text(details)
  );

create or replace function public.delete_own_account()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  if to_regclass('storage.objects') is not null then
    begin
      delete from storage.objects
      where bucket_id = 'listing-photos'
        and split_part(name, '/', 1) = v_uid::text;
    exception
      when others then
        null;
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

  return jsonb_build_object('ok', true);
end;
$$;

comment on function public.delete_own_account() is
  'Deletes the signed-in account, their listings, messages, and private contact row on this database. Does not return contact fields.';

revoke all on function public.delete_own_account() from public, anon, authenticated;
grant execute on function public.delete_own_account() to authenticated;
