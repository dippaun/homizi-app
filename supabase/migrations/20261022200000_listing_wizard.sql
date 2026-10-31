-- HOMIZI property listing wizard for a project that already ran earlier staging SQL.
-- Paste this whole file into the dashboard SQL editor. Running it again is safe.
--
-- The Flutter client does not write these tables yet. Wizard answers are stored
-- as property_features keys wizard:* and near:* so the current properties insert
-- still matches the granted columns. Apply this file later, then point the
-- client at these tables. Do not add the new columns to the client insert
-- payload until that change is reviewed.
--
-- gender_preference is a host preference only. score_compatibility must not
-- read it. photos_verified is a staff check. A listing owner must not set it.
-- No service role key, secret key, or database password is in this file.

reset role;

do $$
begin
  if to_regclass('public.properties') is null
     or to_regclass('public.property_features') is null
     or to_regprocedure('public.set_updated_at()') is null
     or to_regprocedure('public.is_blocked_with(uuid)') is null then
    raise exception 'Apply the earlier HOMIZI staging SQL before this file.';
  end if;
end $$;

create table if not exists public.property_listing_details (
  property_id uuid primary key references public.properties (id) on delete cascade,
  listing_intent text not null,
  building_name text not null default '',
  building_kind text not null default '',
  configuration text not null default '',
  rentable_area text not null default '',
  parking_kind text not null default '',
  property_age_years smallint,
  wc_type text not null default '',
  water_supply text not null default '',
  water_hours text not null default '',
  pets_allowed boolean,
  guests_allowed boolean,
  non_veg_allowed boolean,
  drinking_allowed boolean,
  partying_allowed boolean,
  suitable_for text[] not null default '{}',
  gender_preference text not null default '',
  preferred_occupation text not null default '',
  cook_service boolean,
  maid_service boolean,
  flatmates_brief text not null default '',
  link_flatmate_profiles boolean not null default false,
  possession_date text not null default '',
  highlights text not null default '',
  one_time_charges_inr integer not null default 0,
  electricity_inr integer not null default 0,
  water_charge_inr integer not null default 0,
  wifi_charge_inr integer not null default 0,
  other_monthly_inr integer not null default 0,
  photos_declared boolean not null default false,
  photos_verified boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint property_listing_details_intent check (
    listing_intent in ('room', 'whole_flat', 'pg', 'shared_space')
  ),
  constraint property_listing_details_kind check (
    building_kind in ('', 'apartment', 'house', 'pg', 'villa', 'floor')
  ),
  constraint property_listing_details_rentable check (
    rentable_area in ('', 'single', 'double', 'entire')
  ),
  constraint property_listing_details_parking check (
    parking_kind in ('', 'car', 'bike', 'none')
  ),
  constraint property_listing_details_age check (
    property_age_years is null
    or property_age_years between 0 and 80
  ),
  constraint property_listing_details_wc check (
    wc_type in ('', 'separate', 'shared')
  ),
  constraint property_listing_details_water check (
    water_supply in ('', 'municipal', 'tanker')
  ),
  constraint property_listing_details_gender check (
    gender_preference in ('', 'male', 'female', 'any')
  ),
  constraint property_listing_details_money check (
    one_time_charges_inr >= 0
    and electricity_inr >= 0
    and water_charge_inr >= 0
    and wifi_charge_inr >= 0
    and other_monthly_inr >= 0
  ),
  constraint property_listing_details_text check (
    char_length(building_name) <= 80
    and char_length(water_hours) <= 40
    and char_length(flatmates_brief) <= 240
    and char_length(highlights) <= 280
    and char_length(possession_date) <= 40
  )
);

comment on table public.property_listing_details is
  'Wizard answers that are not columns on properties. The app still writes wizard:* feature keys until this table is wired up.';

comment on column public.property_listing_details.gender_preference is
  'Host preference only. score_compatibility must not read gender, religion, caste, or age.';

comment on column public.property_listing_details.photos_verified is
  'Staff photo check. Distinct from photos_declared. Listing owners cannot set this true.';

comment on column public.property_listing_details.photos_declared is
  'The host uploaded the required photo sequence. This is not a staff verification.';

create table if not exists public.property_nearby (
  property_id uuid not null references public.properties (id) on delete cascade,
  kind text not null,
  place_name text not null,
  distance_km numeric(5, 1) not null,
  travel_minutes integer not null,
  primary key (property_id, kind),
  constraint property_nearby_kind check (
    kind in (
      'metro',
      'train',
      'bus',
      'airport',
      'hospital',
      'supermarket',
      'mall',
      'movie',
      'gym'
    )
  ),
  constraint property_nearby_distance check (
    distance_km >= 0 and distance_km <= 80
  ),
  constraint property_nearby_minutes check (travel_minutes between 1 and 180),
  constraint property_nearby_name check (char_length(place_name) between 1 and 80)
);

comment on table public.property_nearby is
  'Estimated nearby places. distance_km and travel_minutes are both stored. The app still writes near:* feature keys until this table is wired up.';

drop trigger if exists property_listing_details_set_updated_at
  on public.property_listing_details;
create trigger property_listing_details_set_updated_at
  before update on public.property_listing_details
  for each row execute function public.set_updated_at();

-- A signed-in host cannot grant their own listing a photos-verified badge.
create or replace function public.property_listing_details_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.role() is distinct from 'service_role' then
    new.photos_verified := false;
  end if;
  return new;
end;
$$;

drop trigger if exists property_listing_details_guard
  on public.property_listing_details;
create trigger property_listing_details_guard
  before insert or update on public.property_listing_details
  for each row execute function public.property_listing_details_guard();

alter table public.property_listing_details enable row level security;
alter table public.property_nearby enable row level security;

grant select, insert, update, delete on public.property_listing_details to authenticated;
grant select, insert, update, delete on public.property_nearby to authenticated;

drop policy if exists property_listing_details_select on public.property_listing_details;
create policy property_listing_details_select on public.property_listing_details
  for select to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id
        and (
          p.host_user_id = auth.uid()
          or (
            p.status = 'published'
            and not public.is_blocked_with(p.host_user_id)
          )
        )
    )
  );

drop policy if exists property_listing_details_write on public.property_listing_details;
create policy property_listing_details_write on public.property_listing_details
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );

drop policy if exists property_nearby_select on public.property_nearby;
create policy property_nearby_select on public.property_nearby
  for select to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id
        and (
          p.host_user_id = auth.uid()
          or (
            p.status = 'published'
            and not public.is_blocked_with(p.host_user_id)
          )
        )
    )
  );

drop policy if exists property_nearby_write on public.property_nearby;
create policy property_nearby_write on public.property_nearby
  for all to authenticated
  using (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.properties p
      where p.id = property_id and p.host_user_id = auth.uid()
    )
  );

