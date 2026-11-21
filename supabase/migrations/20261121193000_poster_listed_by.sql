-- NOT APPLIED. Paste this after review.
-- Widen properties.listed_by so a PG owner and a room sharer are stored
-- beside host and broker. The app already writes wizard:poster. This
-- backfills listed_by from that feature and from property_type = pg,
-- then returns listed_by on public.public_listings so guest search can
-- badge every poster. Owner stays listed_by = host.

alter table public.properties drop constraint if exists properties_listed_by;

update public.properties p
set listed_by = f.value
from public.property_features f
where f.property_id = p.id
  and f.feature_key = 'wizard:poster'
  and f.value in ('pg', 'room_sharer', 'broker');

update public.properties
set listed_by = 'pg'
where property_type = 'pg'
  and listed_by = 'host';

alter table public.properties
  add constraint properties_listed_by
  check (listed_by in ('host', 'broker', 'pg', 'room_sharer'));

comment on column public.properties.listed_by is
  'host (owner), broker, pg, or room_sharer. Search keeps all four.';

drop function if exists public.public_listings();

create function public.public_listings()
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
  listing_verified boolean,
  listed_by text
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
    p.listing_verified,
    p.listed_by
  from public.properties p
  where p.status = 'published'::public.listing_status
    and not public.is_blocked_with(p.host_user_id);
$$;

comment on function public.public_listings() is
  'Published listing cards, including listed_by, for anon and authenticated. Security definer. Contact and street address are not returned.';

revoke all on function public.public_listings() from public;
grant execute on function public.public_listings() to anon, authenticated;
