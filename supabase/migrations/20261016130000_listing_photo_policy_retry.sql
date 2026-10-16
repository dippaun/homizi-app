-- The first schema apply can skip listing-photos policies when the SQL role
-- does not own storage.objects. Retry as supabase_storage_admin when this
-- session may assume that role. Safe to run again.

do $homizi_photos$
declare
  v_stmt text;
  v_error text := '';
  v_done boolean := false;
  v_stmts text[] := array[
    $homizi_photo_stmt$
      insert into storage.buckets (id, name, public)
      values ('listing-photos', 'listing-photos', false)
      on conflict (id) do nothing
    $homizi_photo_stmt$,
    $homizi_photo_stmt$
      update storage.buckets
      set
        public = false,
        file_size_limit = 5242880,
        allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
      where id = 'listing-photos'
    $homizi_photo_stmt$,
    $homizi_photo_stmt$drop policy if exists listing_photos_insert on storage.objects$homizi_photo_stmt$,
    $homizi_photo_stmt$drop policy if exists listing_photos_select on storage.objects$homizi_photo_stmt$,
    $homizi_photo_stmt$drop policy if exists listing_photos_update on storage.objects$homizi_photo_stmt$,
    $homizi_photo_stmt$drop policy if exists listing_photos_delete on storage.objects$homizi_photo_stmt$,
    $homizi_photo_stmt$
      create policy listing_photos_insert on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $homizi_photo_stmt$,
    $homizi_photo_stmt$
      create policy listing_photos_select on storage.objects
      for select to authenticated
      using (
        bucket_id = 'listing-photos'
        and (
          (storage.foldername(name))[1] = auth.uid()::text
          or exists (
            select 1
            from public.property_photos ph
            join public.properties p on p.id = ph.property_id
            where ph.storage_path = name
              and p.status = 'published'
          )
        )
      )
    $homizi_photo_stmt$,
    $homizi_photo_stmt$
      create policy listing_photos_update on storage.objects
      for update to authenticated
      using (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $homizi_photo_stmt$,
    $homizi_photo_stmt$
      create policy listing_photos_delete on storage.objects
      for delete to authenticated
      using (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $homizi_photo_stmt$
  ];
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; listing-photos policies skipped';
    return;
  end if;

  begin
    foreach v_stmt in array v_stmts loop
      execute v_stmt;
    end loop;
    v_done := true;
  exception
    when insufficient_privilege then
      v_error := sqlerrm;
  end;

  if v_done then
    return;
  end if;

  if current_user is distinct from 'supabase_storage_admin'
     and exists (select 1 from pg_roles where rolname = 'supabase_storage_admin')
     and pg_has_role(session_user, 'supabase_storage_admin', 'member') then
    begin
      execute 'set local role supabase_storage_admin';
      foreach v_stmt in array v_stmts loop
        execute v_stmt;
      end loop;
    exception
      when insufficient_privilege then
        raise notice 'listing-photos policies skipped: %', sqlerrm;
    end;
  else
    raise notice 'listing-photos policies skipped: %', v_error;
  end if;
end
$homizi_photos$;
