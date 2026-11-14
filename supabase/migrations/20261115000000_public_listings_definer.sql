-- Follow-up for 20261114233000. NOT APPLIED: the owner pastes it after saying yes.
-- public.public_listings() was security invoker and selected from
-- private.published_listing_rows(). Anon and authenticated have no USAGE on
-- schema private, so the call failed with 42501. This recreates the function
-- as security definer. It reads only published card columns. It does not
-- grant USAGE on private.
--
-- The anon listing-photo policy had the same lookup: it called
-- private.listing_photo_is_published. That check now lives on a public
-- security definer function. staging_create_test_user and the auth trigger
-- already run as security definer, so a client never resolves schema private.

create or replace function public.public_listings()
returns table (
  id uuid,
  host_user_id uuid,
  title text,
  locality text,
  city text,
  rent_inr integer,
  deposit_inr integer,
  maintenance_inr integer,
  brokerage_inr integer,
  furnishing public.furnishing,
  property_type public.property_type,
  occupancy_max smallint,
  available_from date,
  published_at timestamptz,
  area_sqft integer,
  preferred_tenants text[],
  parking boolean,
  pets_allowed boolean,
  non_veg_allowed boolean,
  gated_society boolean,
  floor_no smallint,
  total_floors smallint,
  approx_latitude numeric,
  approx_longitude numeric,
  listing_verified boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.host_user_id,
    p.title,
    p.locality,
    p.city,
    p.rent_inr,
    p.deposit_inr,
    p.maintenance_inr,
    p.brokerage_inr,
    p.furnishing,
    p.property_type,
    p.occupancy_max,
    p.available_from,
    p.published_at,
    p.area_sqft,
    p.preferred_tenants,
    p.parking,
    p.pets_allowed,
    p.non_veg_allowed,
    p.gated_society,
    p.floor_no,
    p.total_floors,
    p.approx_latitude,
    p.approx_longitude,
    p.listing_verified
  from public.properties p
  where p.status = 'published'::public.listing_status
    and not public.is_blocked_with(p.host_user_id);
$$;

comment on function public.public_listings() is
  'Published listing cards for anon and authenticated. Security definer. Verification is not required. Contact and street address are not returned.';

revoke all on function public.public_listings() from public;
grant execute on function public.public_listings() to anon, authenticated;

revoke all on function private.published_listing_rows() from public, anon, authenticated;

create or replace function public.listing_photo_is_published(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.property_photos ph
    join public.properties p on p.id = ph.property_id
    where ph.storage_path = p_name
      and p.status = 'published'::public.listing_status
  );
$$;

comment on function public.listing_photo_is_published(text) is
  'True when the storage path is a photo on a published listing. No contact fields.';

revoke all on function public.listing_photo_is_published(text) from public;
grant execute on function public.listing_photo_is_published(text) to anon, authenticated;

revoke all on function private.listing_photo_is_published(text) from public, anon, authenticated;

do $homizi_public_photo$
begin
  if to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; anon photo policy skipped';
    return;
  end if;
  drop policy if exists listing_photos_select_published_anon on storage.objects;
  create policy listing_photos_select_published_anon on storage.objects
    for select to anon
    using (
      bucket_id = 'listing-photos'
      and public.listing_photo_is_published(name)
    );
exception
  when insufficient_privilege then
    raise notice 'anon listing photo policy skipped: %', sqlerrm;
end
$homizi_public_photo$;
