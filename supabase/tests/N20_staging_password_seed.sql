-- The K listing seed must still write furnishing after it is a text array.
-- Migrations do not insert the staging password.
begin;
select no_plan();

select is(
  (
    select data_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'listing_requirements'
      and column_name = 'furnishing'
  ),
  'ARRAY',
  'listing requirement furnishing is an array after M'
);

select is(
  (select count(*)::int from private.staging_secrets),
  0,
  'migrations do not insert a staging password'
);

do $reseed_array_furnishing$
declare
  v_tenant uuid;
  v_requirement uuid := 'a1019100-0000-4000-8000-0000000000aa';
begin
  select id
  into v_tenant
  from auth.users
  where lower(email) = 'test@homizi.in'
  limit 1;

  if v_tenant is null then
    raise exception 'test@homizi.in is missing';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'listing_requirements'
      and column_name = 'furnishing'
      and data_type = 'ARRAY'
  ) then
    raise exception 'listing_requirements.furnishing is not an array';
  end if;

  insert into public.listing_requirements (
    id, user_id, city, localities, budget_min_inr, budget_max_inr,
    move_in_date, occupancy, property_types, furnishing, lifestyle, status,
    bedrooms, food_rule, pets_rule, household_rule, wanted_amenities
  )
  values (
    v_requirement,
    v_tenant,
    'Bengaluru',
    array['Koramangala', 'Whitefield', 'HSR Layout'],
    18000,
    28000,
    date '2026-11-20',
    2,
    array['apartment']::public.property_type[],
    array['furnished']::text[],
    array['pets_ok']::text[],
    'published'::public.listing_status,
    2,
    'non_veg_ok',
    'required',
    'family',
    array['Lift', 'Power backup']
  )
  on conflict (id) do update
  set furnishing = excluded.furnishing,
      updated_at = now();
end
$reseed_array_furnishing$;

select is(
  (
    select furnishing
    from public.listing_requirements
    where id = 'a1019100-0000-4000-8000-0000000000aa'
  ),
  array['furnished']::text[],
  'the K seed shape still writes furnishing after it became an array'
);

select * from finish();
rollback;
