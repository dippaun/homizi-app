-- Applied to staging (loraalfiuklespaldotd) on 16 Nov 2026.
-- Kept in the repo so the policy change is in migration history.
--
-- Why photos vanish for a real signed-in account
--
-- listing-photos is a private bucket. Anon SELECT is
-- listing_photos_select_published_anon, which calls
-- public.listing_photo_is_published(name). That function is security definer,
-- so it can see a published property_photos row without the caller's RLS.
--
-- Authenticated SELECT is listing_photos_select. It allows the caller's own
-- folder, or an EXISTS join from property_photos to properties that compares
-- property_photos.storage_path to the storage object name. The join runs as
-- the signed-in role, so RLS on both tables applies. Seeded photos store
-- https://homizi.netlify.app/demo_media/<file>, which is not an object name,
-- so the join never matches. createSignedUrl for a real upload then returns
-- no row for anyone who is not the folder owner.
--
-- This recreates the authenticated SELECT policy so a published photo is
-- readable the same way it is for anon, through the existing security definer
-- function. It does not grant USAGE on schema private, and it does not make
-- the bucket public. Owners can still read and write their own folder.

do $homizi_auth_photo$
begin
  if to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; authenticated photo policy skipped';
    return;
  end if;
  drop policy if exists listing_photos_select on storage.objects;
  create policy listing_photos_select on storage.objects
    for select to authenticated
    using (
      bucket_id = 'listing-photos'
      and (
        (storage.foldername(name))[1] = (auth.uid())::text
        or public.listing_photo_is_published(name)
      )
    );
exception
  when insufficient_privilege then
    raise notice 'authenticated listing photo policy skipped: %', sqlerrm;
end
$homizi_auth_photo$;
