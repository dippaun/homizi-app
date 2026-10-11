-- Keep listing photos private, small, and limited to image types.
-- Paths stay owner-scoped through the storage policies in the access migration.

do $$
begin
  if to_regclass('storage.buckets') is null then
    raise notice 'storage schema not present; listing-photos limits skipped';
    return;
  end if;

  update storage.buckets
  set
    public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
  where id = 'listing-photos';
end $$;
