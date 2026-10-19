-- Detailed seeker briefs, broker registration, and listing match scores.
-- Safe to run again. Gender is stored on the brief and is not a score input.

alter table public.listing_requirements
  add column if not exists seeker_kind text not null default 'tenant',
  add column if not exists lease_months smallint not null default 11,
  add column if not exists room_type text,
  add column if not exists parking_need text,
  add column if not exists preferred_floor text,
  add column if not exists lift_needed boolean not null default false,
  add column if not exists pets text,
  add column if not exists food_habit text,
  add column if not exists smoking text,
  add column if not exists drinking text,
  add column if not exists gender_preference text,
  add column if not exists occupancy_preference text,
  add column if not exists profession text,
  add column if not exists work_location text,
  add column if not exists commute text,
  add column if not exists guests_policy text,
  add column if not exists amenities text[] not null default '{}',
  add column if not exists about_me text,
  add column if not exists discoverable boolean not null default true,
  add column if not exists sleep_schedule text,
  add column if not exists cleanliness smallint not null default 3,
  add column if not exists social_style text,
  add column if not exists work_from_home boolean not null default false,
  add column if not exists cooking text,
  add column if not exists languages text[] not null default '{}',
  add column if not exists hobbies text[] not null default '{}',
  add column if not exists flatmate_note text,
  add column if not exists wizard_step smallint not null default 0;

alter table public.tenant_preferences
  add column if not exists city text,
  add column if not exists furnishing public.furnishing,
  add column if not exists seeker_kind text not null default 'tenant',
  add column if not exists lease_months smallint not null default 11,
  add column if not exists room_type text,
  add column if not exists parking_need text,
  add column if not exists preferred_floor text,
  add column if not exists lift_needed boolean not null default false,
  add column if not exists pets text,
  add column if not exists food_habit text,
  add column if not exists smoking text,
  add column if not exists drinking text,
  add column if not exists gender_preference text,
  add column if not exists occupancy_preference text,
  add column if not exists profession text,
  add column if not exists work_location text,
  add column if not exists commute text,
  add column if not exists guests_policy text,
  add column if not exists amenities text[] not null default '{}',
  add column if not exists about_me text,
  add column if not exists discoverable boolean not null default true,
  add column if not exists sleep_schedule text,
  add column if not exists cleanliness smallint not null default 3,
  add column if not exists social_style text,
  add column if not exists work_from_home boolean not null default false,
  add column if not exists cooking text,
  add column if not exists languages text[] not null default '{}',
  add column if not exists hobbies text[] not null default '{}',
  add column if not exists flatmate_note text;

comment on column public.listing_requirements.discoverable is
  'When false, hosts and brokers cannot see this published brief. Phone is still gated by mutual match.';
comment on column public.listing_requirements.gender_preference is
  'The person''s own household preference. requirement_listing_match must not read gender, religion, caste, or age.';

do $j_checks$
declare
  spec record;
begin
  for spec in
    select *
    from (values
      ('listing_requirements', 'listing_requirements_seeker_kind',
        'seeker_kind in (''tenant'', ''roommate'')'),
      ('listing_requirements', 'listing_requirements_lease_months',
        'lease_months between 1 and 36'),
      ('listing_requirements', 'listing_requirements_room_type',
        'room_type is null or room_type in (''private_room'', ''shared'', ''1rk'', ''1bhk'', ''2bhk'', ''3bhk'', ''4bhk'')'),
      ('listing_requirements', 'listing_requirements_parking_need',
        'parking_need is null or parking_need in (''none'', ''two_wheeler'', ''four_wheeler'', ''either'')'),
      ('listing_requirements', 'listing_requirements_preferred_floor',
        'preferred_floor is null or preferred_floor in (''any'', ''ground'', ''low'', ''mid'', ''high'')'),
      ('listing_requirements', 'listing_requirements_pets',
        'pets is null or pets in (''no_pets'', ''have_pets'', ''pets_ok'')'),
      ('listing_requirements', 'listing_requirements_food_habit',
        'food_habit is null or food_habit in (''veg'', ''non_veg'', ''eggetarian'')'),
      ('listing_requirements', 'listing_requirements_smoking',
        'smoking is null or smoking in (''no'', ''occasionally'', ''yes'')'),
      ('listing_requirements', 'listing_requirements_drinking',
        'drinking is null or drinking in (''no'', ''occasionally'', ''yes'')'),
      ('listing_requirements', 'listing_requirements_gender_preference',
        'gender_preference is null or gender_preference in (''any'', ''women'', ''men'')'),
      ('listing_requirements', 'listing_requirements_occupancy_preference',
        'occupancy_preference is null or occupancy_preference in (''just_me'', ''couple'', ''family'', ''shared'')'),
      ('listing_requirements', 'listing_requirements_profession',
        'profession is null or profession in (''student'', ''working'')'),
      ('listing_requirements', 'listing_requirements_guests_policy',
        'guests_policy is null or guests_policy in (''no_guests'', ''occasional'', ''often'')'),
      ('listing_requirements', 'listing_requirements_amenities',
        'amenities <@ array[''wifi'', ''ac'', ''washing_machine'', ''power_backup'', ''gym'', ''security'']::text[]'),
      ('listing_requirements', 'listing_requirements_about_me',
        'about_me is null or char_length(about_me) <= 500'),
      ('listing_requirements', 'listing_requirements_sleep_schedule',
        'sleep_schedule is null or sleep_schedule in (''early'', ''flexible'', ''night'')'),
      ('listing_requirements', 'listing_requirements_cleanliness',
        'cleanliness between 1 and 5'),
      ('listing_requirements', 'listing_requirements_social_style',
        'social_style is null or social_style in (''quiet'', ''balanced'', ''social'')'),
      ('listing_requirements', 'listing_requirements_cooking',
        'cooking is null or cooking in (''rarely'', ''sometimes'', ''often'')'),
      ('listing_requirements', 'listing_requirements_languages',
        'cardinality(languages) <= 12'),
      ('listing_requirements', 'listing_requirements_hobbies',
        'cardinality(hobbies) <= 12'),
      ('listing_requirements', 'listing_requirements_flatmate_note',
        'flatmate_note is null or char_length(flatmate_note) <= 500'),
      ('listing_requirements', 'listing_requirements_work_location',
        'work_location is null or char_length(work_location) <= 80'),
      ('listing_requirements', 'listing_requirements_commute',
        'commute is null or char_length(commute) <= 80'),
      ('listing_requirements', 'listing_requirements_wizard_step',
        'wizard_step between 0 and 20'),
      ('tenant_preferences', 'tenant_preferences_seeker_kind',
        'seeker_kind in (''tenant'', ''roommate'')'),
      ('tenant_preferences', 'tenant_preferences_lease_months',
        'lease_months between 1 and 36'),
      ('tenant_preferences', 'tenant_preferences_room_type',
        'room_type is null or room_type in (''private_room'', ''shared'', ''1rk'', ''1bhk'', ''2bhk'', ''3bhk'', ''4bhk'')'),
      ('tenant_preferences', 'tenant_preferences_parking_need',
        'parking_need is null or parking_need in (''none'', ''two_wheeler'', ''four_wheeler'', ''either'')'),
      ('tenant_preferences', 'tenant_preferences_preferred_floor',
        'preferred_floor is null or preferred_floor in (''any'', ''ground'', ''low'', ''mid'', ''high'')'),
      ('tenant_preferences', 'tenant_preferences_pets',
        'pets is null or pets in (''no_pets'', ''have_pets'', ''pets_ok'')'),
      ('tenant_preferences', 'tenant_preferences_food_habit',
        'food_habit is null or food_habit in (''veg'', ''non_veg'', ''eggetarian'')'),
      ('tenant_preferences', 'tenant_preferences_smoking',
        'smoking is null or smoking in (''no'', ''occasionally'', ''yes'')'),
      ('tenant_preferences', 'tenant_preferences_drinking',
        'drinking is null or drinking in (''no'', ''occasionally'', ''yes'')'),
      ('tenant_preferences', 'tenant_preferences_gender_preference',
        'gender_preference is null or gender_preference in (''any'', ''women'', ''men'')'),
      ('tenant_preferences', 'tenant_preferences_occupancy_preference',
        'occupancy_preference is null or occupancy_preference in (''just_me'', ''couple'', ''family'', ''shared'')'),
      ('tenant_preferences', 'tenant_preferences_profession',
        'profession is null or profession in (''student'', ''working'')'),
      ('tenant_preferences', 'tenant_preferences_guests_policy',
        'guests_policy is null or guests_policy in (''no_guests'', ''occasional'', ''often'')'),
      ('tenant_preferences', 'tenant_preferences_amenities',
        'amenities <@ array[''wifi'', ''ac'', ''washing_machine'', ''power_backup'', ''gym'', ''security'']::text[]'),
      ('tenant_preferences', 'tenant_preferences_about_me',
        'about_me is null or char_length(about_me) <= 500'),
      ('tenant_preferences', 'tenant_preferences_sleep_schedule',
        'sleep_schedule is null or sleep_schedule in (''early'', ''flexible'', ''night'')'),
      ('tenant_preferences', 'tenant_preferences_cleanliness',
        'cleanliness between 1 and 5'),
      ('tenant_preferences', 'tenant_preferences_social_style',
        'social_style is null or social_style in (''quiet'', ''balanced'', ''social'')'),
      ('tenant_preferences', 'tenant_preferences_cooking',
        'cooking is null or cooking in (''rarely'', ''sometimes'', ''often'')'),
      ('tenant_preferences', 'tenant_preferences_languages',
        'cardinality(languages) <= 12'),
      ('tenant_preferences', 'tenant_preferences_hobbies',
        'cardinality(hobbies) <= 12'),
      ('tenant_preferences', 'tenant_preferences_flatmate_note',
        'flatmate_note is null or char_length(flatmate_note) <= 500'),
      ('tenant_preferences', 'tenant_preferences_work_location',
        'work_location is null or char_length(work_location) <= 80'),
      ('tenant_preferences', 'tenant_preferences_commute',
        'commute is null or char_length(commute) <= 80'),
      ('tenant_preferences', 'tenant_preferences_city_len',
        'city is null or char_length(city) <= 80')
    ) as t(rel, con, expr)
  loop
    execute format(
      'alter table public.%I drop constraint if exists %I',
      spec.rel,
      spec.con
    );
    execute format(
      'alter table public.%I add constraint %I check (%s)',
      spec.rel,
      spec.con,
      spec.expr
    );
  end loop;
end
$j_checks$;

grant insert (
  seeker_kind, lease_months, room_type, parking_need, preferred_floor,
  lift_needed, pets, food_habit, smoking, drinking, gender_preference,
  occupancy_preference, profession, work_location, commute, guests_policy,
  amenities, about_me, discoverable, sleep_schedule, cleanliness, social_style,
  work_from_home, cooking, languages, hobbies, flatmate_note, wizard_step
) on public.listing_requirements to authenticated;
grant update (
  seeker_kind, lease_months, room_type, parking_need, preferred_floor,
  lift_needed, pets, food_habit, smoking, drinking, gender_preference,
  occupancy_preference, profession, work_location, commute, guests_policy,
  amenities, about_me, discoverable, sleep_schedule, cleanliness, social_style,
  work_from_home, cooking, languages, hobbies, flatmate_note, wizard_step
) on public.listing_requirements to authenticated;

alter table public.properties
  add column if not exists listed_by text not null default 'host',
  add column if not exists brokerage_terms text;

alter table public.properties drop constraint if exists properties_listed_by;
alter table public.properties
  add constraint properties_listed_by check (listed_by in ('host', 'broker'));

alter table public.properties drop constraint if exists properties_brokerage_terms;
alter table public.properties
  add constraint properties_brokerage_terms check (
    brokerage_terms is null or char_length(brokerage_terms) <= 160
  );

comment on column public.properties.listed_by is
  'host or broker. Broker-listed homes show a Broker chip and brokerage terms.';
comment on column public.properties.brokerage_terms is
  'Plain-language brokerage, shown with the Broker chip. Not a phone number.';

grant insert (listed_by, brokerage_terms) on public.properties to authenticated;
grant update (listed_by, brokerage_terms) on public.properties to authenticated;

create table if not exists public.broker_profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  full_name text not null default '',
  agency_name text not null default '',
  rera_number text,
  cities text[] not null default '{}',
  localities text[] not null default '{}',
  phone text,
  years_experience smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint broker_profiles_name_len check (char_length(full_name) <= 80),
  constraint broker_profiles_agency_len check (char_length(agency_name) <= 120),
  constraint broker_profiles_rera check (
    rera_number is null or rera_number ~ '^[A-Za-z0-9/-]{5,40}$'
  ),
  constraint broker_profiles_phone check (
    phone is null or phone ~ '^\+?[0-9]{10,15}$'
  ),
  constraint broker_profiles_years check (years_experience between 0 and 60),
  constraint broker_profiles_cities check (cardinality(cities) <= 12),
  constraint broker_profiles_localities check (cardinality(localities) <= 24)
);

comment on table public.broker_profiles is
  'Broker registration. Select is limited to the owner and staff so the phone is not public.';

drop trigger if exists broker_profiles_set_updated_at on public.broker_profiles;
create trigger broker_profiles_set_updated_at
  before update on public.broker_profiles
  for each row execute function public.set_updated_at();

alter table public.broker_profiles enable row level security;

drop policy if exists broker_profiles_self on public.broker_profiles;
create policy broker_profiles_self on public.broker_profiles
  for all to authenticated
  using (user_id = auth.uid() or public.is_staff())
  with check (user_id = auth.uid());

grant select, insert, update, delete on public.broker_profiles to authenticated;

drop policy if exists requirements_select on public.listing_requirements;
create policy requirements_select on public.listing_requirements
  for select to authenticated
  using (
    user_id = auth.uid()
    or (
      status = 'published'
      and discoverable
      and not public.is_blocked_with(user_id)
    )
  );

create index if not exists listing_requirements_discoverable_idx
  on public.listing_requirements (status, discoverable);

create or replace function public.requirement_listing_match(
  listing_id uuid,
  requirement_id uuid
) returns integer
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  l record;
  r record;
  score integer := 0;
  pt text;
  room text;
  type_ok boolean := false;
  wanted text[];
  hits integer;
  total integer;
begin
  select
    city,
    locality,
    rent_inr,
    property_type::text as property_type,
    furnishing::text as furnishing,
    available_from
  into l
  from public.properties
  where id = listing_id;
  if not found then
    return 0;
  end if;

  select
    city,
    localities,
    budget_min_inr,
    budget_max_inr,
    room_type,
    property_types,
    furnishing::text as furnishing,
    amenities,
    move_in_date
  into r
  from public.listing_requirements
  where id = requirement_id;
  if not found then
    return 0;
  end if;

  if lower(btrim(l.city)) = lower(btrim(r.city)) then
    score := score + 25;
  end if;
  if exists (
    select 1
    from unnest(coalesce(r.localities, '{}'::text[])) as loc
    where lower(btrim(loc)) = lower(btrim(l.locality))
  ) then
    score := score + 20;
  end if;
  if l.rent_inr >= r.budget_min_inr and l.rent_inr <= r.budget_max_inr then
    score := score + 20;
  elsif l.rent_inr >= round(r.budget_min_inr::numeric * 0.8)
    and l.rent_inr <= round(r.budget_max_inr::numeric * 1.2) then
    score := score + 10;
  end if;

  pt := l.property_type;
  room := coalesce(r.room_type, '');
  if room = '' then
    type_ok := coalesce(cardinality(r.property_types), 0) = 0
      or pt = any (select item::text from unnest(r.property_types) as item);
  elsif room = 'private_room' then
    type_ok := pt in ('private_room', 'apartment', 'independent_house', 'villa');
  elsif room = 'shared' then
    type_ok := pt in ('shared_room', 'pg');
  elsif room = '1rk' then
    type_ok := pt in ('studio', 'apartment');
  elsif room = '1bhk' then
    type_ok := pt in ('apartment', 'independent_house', 'villa', 'studio');
  elsif room in ('2bhk', '3bhk', '4bhk') then
    type_ok := pt in ('apartment', 'independent_house', 'villa');
  else
    type_ok := pt = any (select item::text from unnest(r.property_types) as item);
  end if;
  if type_ok then
    score := score + 15;
  end if;

  if r.furnishing is null or lower(r.furnishing) = lower(l.furnishing) then
    score := score + 10;
  end if;

  wanted := coalesce(r.amenities, '{}'::text[]);
  total := cardinality(wanted);
  if total = 0 then
    score := score + 5;
  else
    select count(*)::integer into hits
    from unnest(wanted) as item
    where exists (
      select 1
      from public.property_features as feature
      where feature.property_id = listing_id
        and feature.feature_key = 'amenity:' || item
    );
    score := score + round((hits::numeric / total) * 5)::integer;
  end if;

  if r.move_in_date is null
    or l.available_from is null
    or l.available_from <= r.move_in_date + 30 then
    score := score + 5;
  end if;

  if score < 0 then
    return 0;
  end if;
  if score > 100 then
    return 100;
  end if;
  return score;
end;
$$;

comment on function public.requirement_listing_match(uuid, uuid) is
  '0-100 fit of one listing against one requirement. Weights are documented in docs/MATCHING.md. Does not read gender, religion, caste, age, phone, or email. Hidden requirements score 0.';

create or replace function public.seekers_for_my_listings()
returns table (
  requirement_id uuid,
  listing_id uuid,
  display_name text,
  city text,
  localities text[],
  budget_min_inr integer,
  budget_max_inr integer,
  room_type text,
  seeker_kind text,
  about_me text,
  profession text,
  match_percent integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select distinct on (r.id)
    r.id,
    p.id,
    pr.display_name,
    r.city,
    r.localities,
    r.budget_min_inr,
    r.budget_max_inr,
    r.room_type,
    r.seeker_kind,
    r.about_me,
    r.profession,
    scored.match_percent
  from public.properties as p
  join public.listing_requirements as r
    on r.status = 'published'
   and r.discoverable
   and r.user_id <> auth.uid()
  left join public.profiles as pr
    on pr.user_id = r.user_id
  cross join lateral (
    select public.requirement_listing_match(p.id, r.id) as match_percent
  ) as scored
  where p.host_user_id = auth.uid()
    and p.status in ('published', 'draft')
  order by r.id, scored.match_percent desc, p.id;
$$;

comment on function public.seekers_for_my_listings() is
  'Best match of each opted-in published brief against the caller''s listings. No phone or email.';

revoke all on function public.requirement_listing_match(uuid, uuid) from public, anon;
revoke all on function public.seekers_for_my_listings() from public, anon;
grant execute on function public.requirement_listing_match(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.seekers_for_my_listings()
  to authenticated, service_role;

-- Staging catalog: 3 brokers, 6 listings, 17 seeker briefs (one opted out).
do $j_seed$
declare
  broker record;
  home record;
  seeker jsonb;
  seekers jsonb := $j_people$[
    {"user":"a1019201-0000-4000-8000-000000000001","req":"a1019301-0000-4000-8000-000000000001","email":"ananya.iyer@seed.homizi.test","name":"Ananya Iyer","role":"tenant","job":"Architect","city":"Bengaluru","localities":["Koramangala","Indiranagar"],"bmin":20000,"bmax":35000,"move":"2026-11-20","occ":1,"ptype":"apartment","furn":"semi_furnished","life":["non_smoker"],"kind":"tenant","lease":11,"room":"2bhk","parking":"four_wheeler","floor":"mid","lift":true,"pets":"no_pets","food":"veg","smoke":"no","drink":"no","gender":"any","opref":"just_me","prof":"working","work":"Indiranagar","commute":"Metro, about 25 minutes","guests":"occasional","amenities":["wifi","ac","washing_machine"],"about":"Architect in Indiranagar. I want a bright 2 BHK on an 11 month lease.","disc":true,"sleep":"flexible","clean":4,"social":"balanced","wfh":false,"cook":"sometimes","langs":["Hindi","English","Tamil"],"hobbies":["reading","yoga"],"note":""},
    {"user":"a1019202-0000-4000-8000-000000000002","req":"a1019302-0000-4000-8000-000000000002","email":"rohan.mehta@seed.homizi.test","name":"Rohan Mehta","role":"roommate","job":"Retail manager","city":"Mumbai","localities":["Andheri West","Bandra West"],"bmin":15000,"bmax":25000,"move":"2026-11-10","occ":1,"ptype":"private_room","furn":"semi_furnished","life":["night_owl"],"kind":"roommate","lease":11,"room":"private_room","parking":"two_wheeler","floor":"any","lift":false,"pets":"no_pets","food":"non_veg","smoke":"occasionally","drink":"occasionally","gender":"men","opref":"shared","prof":"working","work":"Andheri West","commute":"Local train, 20 minutes","guests":"often","amenities":["wifi","ac"],"about":"I cook most nights and keep late hours after a shift in Andheri.","disc":true,"sleep":"night","clean":3,"social":"social","wfh":false,"cook":"often","langs":["Hindi","English","Gujarati"],"hobbies":["cricket","cooking"],"note":"Someone who cooks and does not mind late hours."},
    {"user":"a1019203-0000-4000-8000-000000000003","req":"a1019303-0000-4000-8000-000000000003","email":"priya.nair@seed.homizi.test","name":"Priya Nair","role":"tenant","job":"Master's student","city":"Pune","localities":["Baner","Aundh"],"bmin":10000,"bmax":18000,"move":"2026-11-15","occ":1,"ptype":"apartment","furn":"furnished","life":["early_riser","wfh","non_smoker"],"kind":"tenant","lease":12,"room":"1bhk","parking":"none","floor":"low","lift":false,"pets":"no_pets","food":"eggetarian","smoke":"no","drink":"no","gender":"women","opref":"just_me","prof":"student","work":"Aundh","commute":"Bus, 30 minutes","guests":"no_guests","amenities":["wifi"],"about":"Master's student. I need a quiet 1 BHK near the bus to Aundh.","disc":true,"sleep":"early","clean":4,"social":"quiet","wfh":true,"cook":"rarely","langs":["English","Malayalam"],"hobbies":["reading"],"note":""},
    {"user":"a1019204-0000-4000-8000-000000000004","req":"a1019304-0000-4000-8000-000000000004","email":"kabir.singh@seed.homizi.test","name":"Kabir Singh","role":"roommate","job":"Analyst","city":"Delhi NCR","localities":["Dwarka","Vasant Kunj"],"bmin":8000,"bmax":14000,"move":"2026-12-01","occ":1,"ptype":"shared_room","furn":"unfurnished","life":["night_owl","pets_ok"],"kind":"roommate","lease":6,"room":"shared","parking":"two_wheeler","floor":"ground","lift":false,"pets":"pets_ok","food":"non_veg","smoke":"yes","drink":"occasionally","gender":"any","opref":"shared","prof":"working","work":"Dwarka","commute":"Metro, 15 minutes","guests":"occasional","amenities":["wifi","power_backup"],"about":"Working in Dwarka. Looking for a shared room and a desk.","disc":true,"sleep":"night","clean":2,"social":"social","wfh":false,"cook":"sometimes","langs":["Hindi","Punjabi"],"hobbies":["football","music"],"note":"A shared room with space for a desk."},
    {"user":"a1019205-0000-4000-8000-000000000005","req":"a1019305-0000-4000-8000-000000000005","email":"sana.qureshi@seed.homizi.test","name":"Sana Qureshi","role":"tenant","job":"Product manager","city":"Hyderabad","localities":["Gachibowli","Madhapur"],"bmin":25000,"bmax":45000,"move":"2026-11-25","occ":2,"ptype":"apartment","furn":"semi_furnished","life":["pets_ok","non_smoker"],"kind":"tenant","lease":11,"room":"3bhk","parking":"four_wheeler","floor":"high","lift":true,"pets":"have_pets","food":"veg","smoke":"no","drink":"no","gender":"any","opref":"couple","prof":"working","work":"Gachibowli","commute":"Cab, 20 minutes","guests":"occasional","amenities":["wifi","ac","gym","security"],"about":"Couple with a small dog. We need a 3 BHK and a lift.","disc":true,"sleep":"flexible","clean":5,"social":"balanced","wfh":false,"cook":"often","langs":["Hindi","Urdu","English"],"hobbies":["travel","cooking"],"note":""},
    {"user":"a1019206-0000-4000-8000-000000000006","req":"a1019306-0000-4000-8000-000000000006","email":"dev.patel@seed.homizi.test","name":"Dev Patel","role":"tenant","job":"Student","city":"Ahmedabad","localities":["Satellite","Vastrapur"],"bmin":8000,"bmax":14000,"move":"2026-11-05","occ":1,"ptype":"studio","furn":"furnished","life":["non_smoker"],"kind":"tenant","lease":6,"room":"1rk","parking":"two_wheeler","floor":"low","lift":false,"pets":"no_pets","food":"eggetarian","smoke":"no","drink":"no","gender":"men","opref":"just_me","prof":"student","work":"Vastrapur","commute":"Walk, 15 minutes","guests":"occasional","amenities":["wifi"],"about":"First year of a master's course near Vastrapur.","disc":true,"sleep":"flexible","clean":3,"social":"balanced","wfh":false,"cook":"sometimes","langs":["Gujarati","Hindi","English"],"hobbies":["cricket"],"note":""},
    {"user":"a1019207-0000-4000-8000-000000000007","req":"a1019307-0000-4000-8000-000000000007","email":"meera.krishnan@seed.homizi.test","name":"Meera Krishnan","role":"roommate","job":"Designer","city":"Bengaluru","localities":["Jayanagar","JP Nagar"],"bmin":12000,"bmax":22000,"move":"2026-11-18","occ":1,"ptype":"private_room","furn":"semi_furnished","life":["early_riser","wfh","non_smoker"],"kind":"roommate","lease":11,"room":"private_room","parking":"none","floor":"mid","lift":true,"pets":"no_pets","food":"veg","smoke":"no","drink":"no","gender":"women","opref":"just_me","prof":"working","work":"Jayanagar","commute":"Work from home three days","guests":"no_guests","amenities":["wifi","washing_machine"],"about":"I work from Jayanagar three days a week and keep a tidy kitchen.","disc":true,"sleep":"early","clean":5,"social":"quiet","wfh":true,"cook":"often","langs":["Tamil","English","Hindi"],"hobbies":["yoga","music"],"note":"A quiet person who also works from home."},
    {"user":"a1019208-0000-4000-8000-000000000008","req":"a1019308-0000-4000-8000-000000000008","email":"arjun.reddy@seed.homizi.test","name":"Arjun Reddy","role":"tenant","job":"Software engineer","city":"Hyderabad","localities":["Madhapur","Kondapur"],"bmin":18000,"bmax":32000,"move":"2026-12-01","occ":1,"ptype":"apartment","furn":"furnished","life":["night_owl","pets_ok","wfh"],"kind":"tenant","lease":12,"room":"2bhk","parking":"four_wheeler","floor":"high","lift":true,"pets":"pets_ok","food":"non_veg","smoke":"occasionally","drink":"yes","gender":"any","opref":"just_me","prof":"working","work":"Madhapur","commute":"Metro is fine","guests":"often","amenities":["wifi","ac","gym"],"about":"Software engineer. Office is in Madhapur, metro is fine.","disc":true,"sleep":"night","clean":3,"social":"social","wfh":true,"cook":"rarely","langs":["Telugu","English","Hindi"],"hobbies":["gym","gaming"],"note":""},
    {"user":"a1019209-0000-4000-8000-000000000009","req":"a1019309-0000-4000-8000-000000000009","email":"ishita.banerjee@seed.homizi.test","name":"Ishita Banerjee","role":"roommate","job":"Student","city":"Pune","localities":["Kothrud","Karve Nagar"],"bmin":7000,"bmax":12000,"move":"2026-11-08","occ":1,"ptype":"shared_room","furn":"unfurnished","life":["early_riser","non_smoker"],"kind":"roommate","lease":11,"room":"shared","parking":"none","floor":"any","lift":false,"pets":"no_pets","food":"veg","smoke":"no","drink":"no","gender":"women","opref":"shared","prof":"student","work":"Kothrud","commute":"Cycle, 10 minutes","guests":"no_guests","amenities":["wifi"],"about":"College in Kothrud. I want a calm vegetarian household.","disc":true,"sleep":"early","clean":4,"social":"quiet","wfh":false,"cook":"sometimes","langs":["Bengali","Hindi","English"],"hobbies":["reading","painting"],"note":"A calm vegetarian household."},
    {"user":"a1019210-0000-4000-8000-000000000010","req":"a1019310-0000-4000-8000-000000000010","email":"vikram.joshi@seed.homizi.test","name":"Vikram Joshi","role":"tenant","job":"Finance lead","city":"Mumbai","localities":["Powai","Andheri East"],"bmin":60000,"bmax":95000,"move":"2026-12-15","occ":4,"ptype":"apartment","furn":"furnished","life":["pets_ok","non_smoker"],"kind":"tenant","lease":24,"room":"4bhk","parking":"four_wheeler","floor":"high","lift":true,"pets":"have_pets","food":"non_veg","smoke":"no","drink":"occasionally","gender":"any","opref":"family","prof":"working","work":"BKC","commute":"Car, 40 minutes","guests":"occasional","amenities":["wifi","ac","gym","security","power_backup"],"about":"Family of four. We need car parking and a gym in the society.","disc":true,"sleep":"flexible","clean":4,"social":"balanced","wfh":false,"cook":"often","langs":["Hindi","Marathi","English"],"hobbies":["travel","gym"],"note":""},
    {"user":"a1019211-0000-4000-8000-000000000011","req":"a1019311-0000-4000-8000-000000000011","email":"fatima.sheikh@seed.homizi.test","name":"Fatima Sheikh","role":"tenant","job":"Consultant","city":"Delhi NCR","localities":["Noida Sector 62","Dwarka"],"bmin":14000,"bmax":24000,"move":"2026-11-12","occ":1,"ptype":"apartment","furn":"semi_furnished","life":["early_riser","non_smoker"],"kind":"tenant","lease":11,"room":"1bhk","parking":"none","floor":"mid","lift":true,"pets":"no_pets","food":"veg","smoke":"no","drink":"no","gender":"women","opref":"just_me","prof":"working","work":"Noida Sector 18","commute":"Metro under 40 minutes","guests":"occasional","amenities":["wifi","ac","security"],"about":"I work in Noida and want the commute under 40 minutes.","disc":true,"sleep":"early","clean":5,"social":"quiet","wfh":false,"cook":"sometimes","langs":["Hindi","Urdu","English"],"hobbies":["reading"],"note":""},
    {"user":"a1019212-0000-4000-8000-000000000012","req":"a1019312-0000-4000-8000-000000000012","email":"nikhil.rao@seed.homizi.test","name":"Nikhil Rao","role":"roommate","job":"Engineer","city":"Bengaluru","localities":["Whitefield","Marathahalli"],"bmin":14000,"bmax":24000,"move":"2026-11-22","occ":1,"ptype":"private_room","furn":"furnished","life":["night_owl","wfh","non_smoker"],"kind":"roommate","lease":11,"room":"private_room","parking":"two_wheeler","floor":"high","lift":true,"pets":"no_pets","food":"eggetarian","smoke":"no","drink":"occasionally","gender":"men","opref":"just_me","prof":"working","work":"Whitefield","commute":"Work from home most days","guests":"occasional","amenities":["wifi","ac","power_backup"],"about":"I work from home most days and use headphones on calls.","disc":true,"sleep":"night","clean":3,"social":"balanced","wfh":true,"cook":"rarely","langs":["Kannada","English","Hindi"],"hobbies":["gaming","music"],"note":"Someone who uses headphones on calls."},
    {"user":"a1019213-0000-4000-8000-000000000013","req":"a1019313-0000-4000-8000-000000000013","email":"lavanya.reddy@seed.homizi.test","name":"Lavanya Reddy","role":"tenant","job":"Lawyer","city":"Hyderabad","localities":["Banjara Hills","Jubilee Hills"],"bmin":22000,"bmax":40000,"move":"2026-12-05","occ":2,"ptype":"apartment","furn":"semi_furnished","life":["non_smoker"],"kind":"tenant","lease":11,"room":"2bhk","parking":"four_wheeler","floor":"mid","lift":true,"pets":"no_pets","food":"veg","smoke":"no","drink":"no","gender":"any","opref":"couple","prof":"working","work":"Banjara Hills","commute":"Cab, 15 minutes","guests":"occasional","amenities":["wifi","ac","washing_machine","security"],"about":"Moving in December on an 11 month lease. Vegetarian kitchen.","disc":true,"sleep":"flexible","clean":4,"social":"balanced","wfh":false,"cook":"often","langs":["Telugu","Hindi","English"],"hobbies":["cooking","dance"],"note":""},
    {"user":"a1019214-0000-4000-8000-000000000014","req":"a1019314-0000-4000-8000-000000000014","email":"harsh.agarwal@seed.homizi.test","name":"Harsh Agarwal","role":"roommate","job":"Student","city":"Ahmedabad","localities":["Navrangpura","Paldi"],"bmin":6000,"bmax":11000,"move":"2026-11-02","occ":1,"ptype":"shared_room","furn":"unfurnished","life":["night_owl"],"kind":"roommate","lease":6,"room":"shared","parking":"two_wheeler","floor":"ground","lift":false,"pets":"no_pets","food":"non_veg","smoke":"occasionally","drink":"occasionally","gender":"men","opref":"shared","prof":"student","work":"Navrangpura","commute":"Walk to college","guests":"often","amenities":["wifi"],"about":"College nearby. I cook on weekends and follow cricket.","disc":true,"sleep":"night","clean":2,"social":"social","wfh":false,"cook":"sometimes","langs":["Hindi","Gujarati"],"hobbies":["cricket"],"note":"Weekends are for cooking and cricket."},
    {"user":"a1019215-0000-4000-8000-000000000015","req":"a1019315-0000-4000-8000-000000000015","email":"diya.kapoor@seed.homizi.test","name":"Diya Kapoor","role":"tenant","job":"Marketing lead","city":"Delhi NCR","localities":["DLF Phase 2","Sohna Road"],"bmin":35000,"bmax":55000,"move":"2026-12-10","occ":3,"ptype":"apartment","furn":"furnished","life":["non_smoker"],"kind":"tenant","lease":12,"room":"3bhk","parking":"four_wheeler","floor":"mid","lift":true,"pets":"no_pets","food":"eggetarian","smoke":"no","drink":"no","gender":"any","opref":"family","prof":"working","work":"Cyber Hub","commute":"Car, 25 minutes","guests":"occasional","amenities":["wifi","ac","gym","security"],"about":"Moving with my parents for a year. A lift is important.","disc":true,"sleep":"flexible","clean":4,"social":"balanced","wfh":false,"cook":"often","langs":["Hindi","English","Punjabi"],"hobbies":["travel"],"note":""},
    {"user":"a1019216-0000-4000-8000-000000000016","req":"a1019316-0000-4000-8000-000000000016","email":"aditya.kulkarni@seed.homizi.test","name":"Aditya Kulkarni","role":"tenant","job":"Intern","city":"Pune","localities":["Viman Nagar","Kharadi"],"bmin":12000,"bmax":20000,"move":"2026-11-06","occ":1,"ptype":"apartment","furn":"furnished","life":["non_smoker"],"kind":"tenant","lease":3,"room":"1bhk","parking":"two_wheeler","floor":"low","lift":true,"pets":"no_pets","food":"veg","smoke":"no","drink":"no","gender":"any","opref":"just_me","prof":"student","work":"Kharadi","commute":"Bus, 20 minutes","guests":"occasional","amenities":["wifi","power_backup"],"about":"Internship in Kharadi from November. Eggetarian kitchen is fine; I cook veg.","disc":true,"sleep":"flexible","clean":3,"social":"balanced","wfh":false,"cook":"sometimes","langs":["Marathi","Hindi","English"],"hobbies":["music"],"note":""},
    {"user":"a1019217-0000-4000-8000-000000000017","req":"a1019317-0000-4000-8000-000000000017","email":"neelam.chopra@seed.homizi.test","name":"Neelam Chopra","role":"tenant","job":"Teacher","city":"Mumbai","localities":["Dadar","Matunga"],"bmin":25000,"bmax":40000,"move":"2026-11-28","occ":1,"ptype":"apartment","furn":"semi_furnished","life":["non_smoker"],"kind":"tenant","lease":11,"room":"2bhk","parking":"either","floor":"mid","lift":true,"pets":"no_pets","food":"veg","smoke":"no","drink":"no","gender":"women","opref":"just_me","prof":"working","work":"Dadar","commute":"Local train","guests":"occasional","amenities":["wifi","ac"],"about":"This brief stays private. I will reach out myself.","disc":false,"sleep":"flexible","clean":4,"social":"quiet","wfh":false,"cook":"sometimes","langs":["Hindi","English"],"hobbies":["reading"],"note":""}
  ]$j_people$::jsonb;
begin
  if to_regprocedure('public.homizi_seed_auth_user(uuid,text)') is null then
    raise notice 'homizi_seed_auth_user missing; J19 seed skipped';
    return;
  end if;

  for broker in
    select *
    from (values
      (
        'a1019001-0000-4000-8000-000000000001'::uuid,
        'meenal.deshpande@seed.homizi.test',
        'Meenal Deshpande',
        'Deshpande Realty',
        'PRM/KA/RERA/1251/446/AG/171018/000441',
        array['Bengaluru', 'Hyderabad']::text[],
        array['Koramangala', 'Indiranagar', 'Gachibowli']::text[],
        '+919812340011',
        8::smallint
      ),
      (
        'a1019002-0000-4000-8000-000000000002'::uuid,
        'farhan.qureshi@seed.homizi.test',
        'Farhan Qureshi',
        'Qureshi Estates',
        'A51800033421',
        array['Mumbai', 'Pune']::text[],
        array['Andheri West', 'Baner']::text[],
        '+919812340022',
        11::smallint
      ),
      (
        'a1019003-0000-4000-8000-000000000003'::uuid,
        'ritika.shah@seed.homizi.test',
        'Ritika Shah',
        'Shah Homes',
        'DLRERA2024A00192',
        array['Delhi NCR', 'Ahmedabad']::text[],
        array['Dwarka', 'Satellite']::text[],
        '+919812340033',
        6::smallint
      )
    ) as t(
      id, email, full_name, agency, rera, cities, localities, phone, years
    )
  loop
    perform public.homizi_seed_auth_user(broker.id, broker.email);
    insert into public.users (id, status, primary_role)
    values (broker.id, 'active', 'host')
    on conflict (id) do update
    set status = 'active',
        primary_role = 'host';
    insert into public.profiles (user_id, display_name, occupation, public_bio, primary_role)
    values (
      broker.id,
      broker.full_name,
      'Broker',
      broker.agency || ' lists homes across ' || array_to_string(broker.cities, ' and ') || '.',
      'broker'
    )
    on conflict (user_id) do update
    set display_name = excluded.display_name,
        occupation = excluded.occupation,
        public_bio = excluded.public_bio,
        primary_role = 'broker';
    insert into public.private_contacts (user_id, email, phone)
    values (broker.id, broker.email, broker.phone)
    on conflict (user_id) do update
    set email = excluded.email,
        phone = excluded.phone;
    insert into public.host_profiles (user_id, host_category, company_name)
    values (broker.id, 'broker', broker.agency)
    on conflict (user_id) do update
    set host_category = 'broker',
        company_name = excluded.company_name;
    insert into public.broker_profiles (
      user_id, full_name, agency_name, rera_number, cities, localities, phone, years_experience
    ) values (
      broker.id, broker.full_name, broker.agency, broker.rera,
      broker.cities, broker.localities, broker.phone, broker.years
    )
    on conflict (user_id) do update
    set full_name = excluded.full_name,
        agency_name = excluded.agency_name,
        rera_number = excluded.rera_number,
        cities = excluded.cities,
        localities = excluded.localities,
        phone = excluded.phone,
        years_experience = excluded.years_experience;
  end loop;

  for home in
    select *
    from (values
      (
        'a1019101-0000-4000-8000-000000000001'::uuid,
        'a1019001-0000-4000-8000-000000000001'::uuid,
        '2 BHK in Koramangala', 'Koramangala', 'Bengaluru',
        'apartment'::public.property_type, 'semi_furnished'::public.furnishing,
        28000, 56000, 1100, 4::smallint, 8::smallint, 12.935::numeric, 77.624::numeric,
        array['wifi', 'ac', 'washing_machine', 'security']::text[]
      ),
      (
        'a1019102-0000-4000-8000-000000000002'::uuid,
        'a1019001-0000-4000-8000-000000000001'::uuid,
        '3 BHK in Gachibowli', 'Gachibowli', 'Hyderabad',
        'apartment'::public.property_type, 'semi_furnished'::public.furnishing,
        42000, 84000, 1650, 7::smallint, 14::smallint, 17.440::numeric, 78.349::numeric,
        array['wifi', 'ac', 'gym', 'security']::text[]
      ),
      (
        'a1019103-0000-4000-8000-000000000003'::uuid,
        'a1019002-0000-4000-8000-000000000002'::uuid,
        '1 BHK in Andheri West', 'Andheri West', 'Mumbai',
        'apartment'::public.property_type, 'furnished'::public.furnishing,
        32000, 64000, 620, 3::smallint, 12::smallint, 19.136::numeric, 72.829::numeric,
        array['wifi', 'ac', 'security']::text[]
      ),
      (
        'a1019104-0000-4000-8000-000000000004'::uuid,
        'a1019002-0000-4000-8000-000000000002'::uuid,
        '2 BHK in Baner', 'Baner', 'Pune',
        'apartment'::public.property_type, 'semi_furnished'::public.furnishing,
        22000, 44000, 980, 5::smallint, 11::smallint, 18.559::numeric, 73.786::numeric,
        array['wifi', 'washing_machine', 'power_backup']::text[]
      ),
      (
        'a1019105-0000-4000-8000-000000000005'::uuid,
        'a1019003-0000-4000-8000-000000000003'::uuid,
        '2 BHK in Dwarka', 'Dwarka', 'Delhi NCR',
        'apartment'::public.property_type, 'semi_furnished'::public.furnishing,
        24000, 48000, 1050, 6::smallint, 12::smallint, 28.592::numeric, 77.046::numeric,
        array['wifi', 'power_backup', 'security']::text[]
      ),
      (
        'a1019106-0000-4000-8000-000000000006'::uuid,
        'a1019003-0000-4000-8000-000000000003'::uuid,
        '3 BHK in Satellite', 'Satellite', 'Ahmedabad',
        'apartment'::public.property_type, 'furnished'::public.furnishing,
        30000, 60000, 1480, 4::smallint, 10::smallint, 23.030::numeric, 72.512::numeric,
        array['wifi', 'ac', 'gym', 'security']::text[]
      )
    ) as t(
      id, host_id, title, locality, city, property_type, furnishing,
      rent_inr, deposit_inr, area_sqft, floor_no, total_floors, lat, lng, amenities
    )
  loop
    insert into public.properties (
      id, host_user_id, title, locality, city, property_type, furnishing,
      rent_inr, deposit_inr, maintenance_inr, occupancy_max, status,
      available_from, published_at, address_visibility,
      area_sqft, preferred_tenants, parking, pets_allowed, non_veg_allowed,
      gated_society, floor_no, total_floors, approx_latitude, approx_longitude,
      listed_by, brokerage_terms
    ) values (
      home.id, home.host_id, home.title, home.locality, home.city,
      home.property_type, home.furnishing,
      home.rent_inr, home.deposit_inr, 1500, 4, 'published',
      date '2026-11-01', timestamptz '2026-10-18 09:00:00+00', 'locality_only',
      home.area_sqft, array['any']::text[], true, true, true,
      true, home.floor_no, home.total_floors, home.lat, home.lng,
      'broker', 'One month rent, paid when the agreement is signed'
    )
    on conflict (id) do update
    set host_user_id = excluded.host_user_id,
        title = excluded.title,
        locality = excluded.locality,
        city = excluded.city,
        property_type = excluded.property_type,
        furnishing = excluded.furnishing,
        rent_inr = excluded.rent_inr,
        deposit_inr = excluded.deposit_inr,
        status = 'published',
        available_from = excluded.available_from,
        area_sqft = excluded.area_sqft,
        floor_no = excluded.floor_no,
        total_floors = excluded.total_floors,
        approx_latitude = excluded.approx_latitude,
        approx_longitude = excluded.approx_longitude,
        listed_by = 'broker',
        brokerage_terms = excluded.brokerage_terms;

    delete from public.property_photos where property_id = home.id;
    insert into public.property_photos (
      id, property_id, storage_path, sort_order, photo_type, moderation_status
    ) values
      (
        (
          substr(replace(home.id::text, '-', ''), 1, 8) || '-' ||
          substr(md5(home.id::text || ':0'), 1, 4) || '-4000-8000-' ||
          substr(md5(home.id::text || ':0'), 5, 12)
        )::uuid,
        home.id,
        'https://homizi.netlify.app/demo_media/living_01.webp',
        0,
        'living',
        'approved'
      ),
      (
        (
          substr(replace(home.id::text, '-', ''), 1, 8) || '-' ||
          substr(md5(home.id::text || ':1'), 1, 4) || '-4000-8000-' ||
          substr(md5(home.id::text || ':1'), 5, 12)
        )::uuid,
        home.id,
        'https://homizi.netlify.app/demo_media/bed_01.webp',
        1,
        'bedroom',
        'approved'
      ),
      (
        (
          substr(replace(home.id::text, '-', ''), 1, 8) || '-' ||
          substr(md5(home.id::text || ':2'), 1, 4) || '-4000-8000-' ||
          substr(md5(home.id::text || ':2'), 5, 12)
        )::uuid,
        home.id,
        'https://homizi.netlify.app/demo_media/kitchen_01.webp',
        2,
        'kitchen',
        'approved'
      );

    delete from public.property_features
    where property_id = home.id
      and feature_key like 'amenity:%';
    insert into public.property_features (property_id, feature_key, value)
    select home.id, 'amenity:' || item, 'yes'
    from unnest(home.amenities) as item;
  end loop;

  for seeker in
    select value from jsonb_array_elements(seekers)
  loop
    perform public.homizi_seed_auth_user(
      (seeker->>'user')::uuid,
      seeker->>'email'
    );
    insert into public.users (id, status, primary_role)
    values ((seeker->>'user')::uuid, 'active', 'tenant')
    on conflict (id) do update
    set status = 'active',
        primary_role = 'tenant';
    insert into public.profiles (
      user_id, display_name, occupation, public_bio, primary_role
    ) values (
      (seeker->>'user')::uuid,
      seeker->>'name',
      seeker->>'job',
      seeker->>'about',
      seeker->>'role'
    )
    on conflict (user_id) do update
    set display_name = excluded.display_name,
        occupation = excluded.occupation,
        public_bio = excluded.public_bio,
        primary_role = excluded.primary_role;
    insert into public.private_contacts (user_id, email, phone)
    values ((seeker->>'user')::uuid, seeker->>'email', null)
    on conflict (user_id) do update
    set email = excluded.email,
        phone = null;
    insert into public.listing_requirements (
      id, user_id, city, localities, budget_min_inr, budget_max_inr,
      move_in_date, occupancy, property_types, furnishing, lifestyle, status,
      seeker_kind, lease_months, room_type, parking_need, preferred_floor,
      lift_needed, pets, food_habit, smoking, drinking, gender_preference,
      occupancy_preference, profession, work_location, commute, guests_policy,
      amenities, about_me, discoverable, sleep_schedule, cleanliness,
      social_style, work_from_home, cooking, languages, hobbies, flatmate_note,
      wizard_step
    ) values (
      (seeker->>'req')::uuid,
      (seeker->>'user')::uuid,
      seeker->>'city',
      array(select jsonb_array_elements_text(seeker->'localities')),
      (seeker->>'bmin')::integer,
      (seeker->>'bmax')::integer,
      (seeker->>'move')::date,
      (seeker->>'occ')::smallint,
      array[(seeker->>'ptype')::public.property_type],
      (seeker->>'furn')::public.furnishing,
      array(select jsonb_array_elements_text(seeker->'life')),
      'published',
      seeker->>'kind',
      (seeker->>'lease')::smallint,
      seeker->>'room',
      seeker->>'parking',
      seeker->>'floor',
      (seeker->>'lift')::boolean,
      seeker->>'pets',
      seeker->>'food',
      seeker->>'smoke',
      seeker->>'drink',
      seeker->>'gender',
      seeker->>'opref',
      seeker->>'prof',
      seeker->>'work',
      seeker->>'commute',
      seeker->>'guests',
      array(select jsonb_array_elements_text(seeker->'amenities')),
      seeker->>'about',
      (seeker->>'disc')::boolean,
      seeker->>'sleep',
      (seeker->>'clean')::smallint,
      seeker->>'social',
      (seeker->>'wfh')::boolean,
      seeker->>'cook',
      array(select jsonb_array_elements_text(seeker->'langs')),
      array(select jsonb_array_elements_text(seeker->'hobbies')),
      nullif(seeker->>'note', ''),
      12
    )
    on conflict (id) do update
    set city = excluded.city,
        localities = excluded.localities,
        budget_min_inr = excluded.budget_min_inr,
        budget_max_inr = excluded.budget_max_inr,
        move_in_date = excluded.move_in_date,
        occupancy = excluded.occupancy,
        property_types = excluded.property_types,
        furnishing = excluded.furnishing,
        lifestyle = excluded.lifestyle,
        status = 'published',
        seeker_kind = excluded.seeker_kind,
        lease_months = excluded.lease_months,
        room_type = excluded.room_type,
        parking_need = excluded.parking_need,
        preferred_floor = excluded.preferred_floor,
        lift_needed = excluded.lift_needed,
        pets = excluded.pets,
        food_habit = excluded.food_habit,
        smoking = excluded.smoking,
        drinking = excluded.drinking,
        gender_preference = excluded.gender_preference,
        occupancy_preference = excluded.occupancy_preference,
        profession = excluded.profession,
        work_location = excluded.work_location,
        commute = excluded.commute,
        guests_policy = excluded.guests_policy,
        amenities = excluded.amenities,
        about_me = excluded.about_me,
        discoverable = excluded.discoverable,
        sleep_schedule = excluded.sleep_schedule,
        cleanliness = excluded.cleanliness,
        social_style = excluded.social_style,
        work_from_home = excluded.work_from_home,
        cooking = excluded.cooking,
        languages = excluded.languages,
        hobbies = excluded.hobbies,
        flatmate_note = excluded.flatmate_note,
        wizard_step = excluded.wizard_step;
    insert into public.tenant_preferences (
      user_id, city, budget_min_inr, budget_max_inr, move_in_date, localities,
      occupancy, property_types, furnishing, lifestyle, seeker_kind, lease_months,
      room_type, parking_need, preferred_floor, lift_needed, pets, food_habit,
      smoking, drinking, gender_preference, occupancy_preference, profession,
      work_location, commute, guests_policy, amenities, about_me, discoverable,
      sleep_schedule, cleanliness, social_style, work_from_home, cooking,
      languages, hobbies, flatmate_note
    ) values (
      (seeker->>'user')::uuid,
      seeker->>'city',
      (seeker->>'bmin')::integer,
      (seeker->>'bmax')::integer,
      (seeker->>'move')::date,
      array(select jsonb_array_elements_text(seeker->'localities')),
      (seeker->>'occ')::smallint,
      array[(seeker->>'ptype')::public.property_type],
      (seeker->>'furn')::public.furnishing,
      array(select jsonb_array_elements_text(seeker->'life')),
      seeker->>'kind',
      (seeker->>'lease')::smallint,
      seeker->>'room',
      seeker->>'parking',
      seeker->>'floor',
      (seeker->>'lift')::boolean,
      seeker->>'pets',
      seeker->>'food',
      seeker->>'smoke',
      seeker->>'drink',
      seeker->>'gender',
      seeker->>'opref',
      seeker->>'prof',
      seeker->>'work',
      seeker->>'commute',
      seeker->>'guests',
      array(select jsonb_array_elements_text(seeker->'amenities')),
      seeker->>'about',
      (seeker->>'disc')::boolean,
      seeker->>'sleep',
      (seeker->>'clean')::smallint,
      seeker->>'social',
      (seeker->>'wfh')::boolean,
      seeker->>'cook',
      array(select jsonb_array_elements_text(seeker->'langs')),
      array(select jsonb_array_elements_text(seeker->'hobbies')),
      nullif(seeker->>'note', '')
    )
    on conflict (user_id) do update
    set city = excluded.city,
        budget_min_inr = excluded.budget_min_inr,
        budget_max_inr = excluded.budget_max_inr,
        move_in_date = excluded.move_in_date,
        localities = excluded.localities,
        occupancy = excluded.occupancy,
        property_types = excluded.property_types,
        furnishing = excluded.furnishing,
        lifestyle = excluded.lifestyle,
        seeker_kind = excluded.seeker_kind,
        lease_months = excluded.lease_months,
        room_type = excluded.room_type,
        parking_need = excluded.parking_need,
        preferred_floor = excluded.preferred_floor,
        lift_needed = excluded.lift_needed,
        pets = excluded.pets,
        food_habit = excluded.food_habit,
        smoking = excluded.smoking,
        drinking = excluded.drinking,
        gender_preference = excluded.gender_preference,
        occupancy_preference = excluded.occupancy_preference,
        profession = excluded.profession,
        work_location = excluded.work_location,
        commute = excluded.commute,
        guests_policy = excluded.guests_policy,
        amenities = excluded.amenities,
        about_me = excluded.about_me,
        discoverable = excluded.discoverable,
        sleep_schedule = excluded.sleep_schedule,
        cleanliness = excluded.cleanliness,
        social_style = excluded.social_style,
        work_from_home = excluded.work_from_home,
        cooking = excluded.cooking,
        languages = excluded.languages,
        hobbies = excluded.hobbies,
        flatmate_note = excluded.flatmate_note;
  end loop;
end
$j_seed$;
