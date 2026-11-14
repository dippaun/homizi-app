-- Live two-user feed. NOT APPLIED to staging: the owner pastes
-- docs/staging_apply_LIVE_1115.sql after saying yes.
--
-- Published homes, including PG and shared rooms, are readable by anyone
-- through public.public_listings(). Direct SELECT on properties stays
-- denied for anon, so drafts and street addresses stay hidden.
-- A like is visible to the sender and the person they liked, and to nobody else.
-- Inserting the second like creates one match. properties, interests, and
-- matches join the realtime publication. Listing-photo policies are confirmed,
-- and a published photo can be read without signing in.

create schema if not exists private;

-- ---------------------------------------------------------------------------
-- Published listings. Security definer stays in private. The public wrapper
-- is invoker and returns only the card columns. No phone, email, or street.
-- ---------------------------------------------------------------------------

create or replace function private.published_listing_rows()
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
set search_path = public
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
  where p.status = 'published'
    and not public.is_blocked_with(p.host_user_id);
$$;

revoke all on function private.published_listing_rows() from public, anon, authenticated;
grant execute on function private.published_listing_rows() to anon, authenticated;

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
security invoker
set search_path = public, private
as $$
  select * from private.published_listing_rows();
$$;

comment on function public.public_listings() is
  'Published listing cards for anon and authenticated. Verification is not required. Contact and street address are not returned.';

revoke all on function public.public_listings() from public;
grant execute on function public.public_listings() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Likes. The sender and the person they liked can read a like. Passes and
-- saves stay with the sender. Nobody else can read the row.
-- ---------------------------------------------------------------------------

drop policy if exists interests_select_own on public.interests;
drop policy if exists interests_select_parties on public.interests;
create policy interests_select_parties
  on public.interests
  for select
  to authenticated
  using (
    actor_user_id = auth.uid()
    or (
      action = 'like'
      and (
        (target_type = 'user' and target_id = auth.uid())
        or (
          target_type = 'property'
          and exists (
            select 1
            from public.properties p
            where p.id = interests.target_id
              and p.host_user_id = auth.uid()
          )
        )
        or (
          target_type = 'listing_requirement'
          and exists (
            select 1
            from public.listing_requirements r
            where r.id = interests.target_id
              and r.user_id = auth.uid()
          )
        )
      )
    )
  );

-- ---------------------------------------------------------------------------
-- Mutual like. create_interest already calls _try_mutual_match. This trigger
-- covers a direct insert as well. The function is idempotent, so both paths
-- leave one match row.
-- ---------------------------------------------------------------------------

create or replace function private.interests_try_mutual_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  if new.action is distinct from 'like'::public.interest_action then
    return new;
  end if;

  if new.target_type = 'property' then
    select p.host_user_id into v_owner
    from public.properties p
    where p.id = new.target_id;
  elsif new.target_type = 'listing_requirement' then
    select r.user_id into v_owner
    from public.listing_requirements r
    where r.id = new.target_id;
  elsif new.target_type = 'user' then
    v_owner := new.target_id;
  end if;

  if v_owner is not null and v_owner is distinct from new.actor_user_id then
    perform public._try_mutual_match(new.actor_user_id, v_owner);
  end if;
  return new;
end;
$$;

revoke all on function private.interests_try_mutual_match() from public, anon, authenticated;

drop trigger if exists interests_try_mutual_match on public.interests;
create trigger interests_try_mutual_match
  after insert on public.interests
  for each row execute function private.interests_try_mutual_match();

-- ---------------------------------------------------------------------------
-- Realtime. Messages are already published. Add the feed tables.
-- ---------------------------------------------------------------------------

alter table public.properties replica identity full;
alter table public.interests replica identity full;
alter table public.matches replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    raise notice 'supabase_realtime publication missing; live feed skipped';
    return;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'properties'
  ) then
    alter publication supabase_realtime add table public.properties;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'interests'
  ) then
    alter publication supabase_realtime add table public.interests;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'matches'
  ) then
    alter publication supabase_realtime add table public.matches;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
exception
  when insufficient_privilege then
    raise notice 'realtime publication update skipped: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- Contact stays behind get_contact_visibility. Confirm anon cannot read it.
-- ---------------------------------------------------------------------------

revoke all on public.private_contacts from anon, public;

-- ---------------------------------------------------------------------------
-- Listing photos. Confirm the owner policies, and let anon read a photo only
-- when it is attached to a published listing. The bucket stays private.
-- ---------------------------------------------------------------------------

create or replace function private.listing_photo_is_published(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.property_photos ph
    join public.properties p on p.id = ph.property_id
    where ph.storage_path = p_name
      and p.status = 'published'
  );
$$;

revoke all on function private.listing_photo_is_published(text) from public;
grant execute on function private.listing_photo_is_published(text) to anon, authenticated;

do $homizi_live_photos$
declare
  v_stmt text;
  v_stmts text[] := array[
    $sql$
      insert into storage.buckets (id, name, public)
      values ('listing-photos', 'listing-photos', false)
      on conflict (id) do update
      set public = false,
          file_size_limit = 5242880,
          allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
    $sql$,
    $sql$drop policy if exists listing_photos_insert on storage.objects$sql$,
    $sql$drop policy if exists listing_photos_select on storage.objects$sql$,
    $sql$drop policy if exists listing_photos_update on storage.objects$sql$,
    $sql$drop policy if exists listing_photos_delete on storage.objects$sql$,
    $sql$drop policy if exists listing_photos_select_published_anon on storage.objects$sql$,
    $sql$
      create policy listing_photos_insert on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $sql$,
    $sql$
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
    $sql$,
    $sql$
      create policy listing_photos_update on storage.objects
      for update to authenticated
      using (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
      with check (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $sql$,
    $sql$
      create policy listing_photos_delete on storage.objects
      for delete to authenticated
      using (
        bucket_id = 'listing-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
    $sql$,
    $sql$
      create policy listing_photos_select_published_anon on storage.objects
      for select to anon
      using (
        bucket_id = 'listing-photos'
        and private.listing_photo_is_published(name)
      )
    $sql$
  ];
begin
  if to_regclass('storage.buckets') is null
     or to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; listing-photos policies skipped';
    return;
  end if;
  foreach v_stmt in array v_stmts loop
    execute v_stmt;
  end loop;
exception
  when insufficient_privilege then
    raise notice 'listing-photos policies skipped: %', sqlerrm;
end
$homizi_live_photos$;
