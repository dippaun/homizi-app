-- HOMIZI roommate matching for a project that already ran earlier staging SQL.
-- Paste this whole file into the dashboard SQL editor. Running it again is safe.
--
-- It applies 20261018130000_roommate_matching.sql.
-- Apply docs/staging_apply_J_1019.sql first so profiles.primary_role exists.
-- The seed is idempotent. Phone and email stay on private_contacts.
-- No service role key, secret key, or database password is in this file.

-- Roommate discovery and compatibility.
-- profiles.primary_role is the product role from
-- 20261018120000_profiles_primary_role.sql (roommate, tenant, host, broker).
-- Age is stored for the card and is not scored. Religion and caste are not read.

create table if not exists public.roommate_profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  discoverable boolean not null default false,
  open_to_flatmates boolean not null default false,
  seeking_role text not null default 'roommate',
  city text not null default '',
  localities text[] not null default '{}',
  budget_min_inr integer,
  budget_max_inr integer,
  move_in_date date,
  gender text,
  gender_preference text,
  occupancy text,
  food text,
  food_dealbreaker boolean not null default false,
  smoking text,
  smoking_dealbreaker boolean not null default false,
  pets text,
  pets_dealbreaker boolean not null default false,
  sleep text,
  cleanliness smallint,
  social text,
  wfh text,
  cooking text,
  guests text,
  languages text[] not null default '{}',
  hobbies text[] not null default '{}',
  thoughts text not null default '',
  age smallint,
  updated_at timestamptz not null default now()
);

do $roommate_profile_checks$
begin
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_role') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_role
      check (seeking_role in ('roommate', 'tenant'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_gender') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_gender
      check (gender is null or gender in ('woman', 'man', 'nonbinary', 'undisclosed'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_gender_pref') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_gender_pref
      check (gender_preference is null or gender_preference in ('any', 'women', 'men', 'same'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_occupancy') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_occupancy
      check (occupancy is null or occupancy in ('shared', 'solo', 'any'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_food') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_food
      check (food is null or food in ('veg', 'eggetarian', 'non_veg', 'any'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_smoking') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_smoking
      check (smoking is null or smoking in ('never', 'sometimes', 'regularly'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_pets') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_pets
      check (pets is null or pets in ('none', 'has', 'ok'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_sleep') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_sleep
      check (sleep is null or sleep in ('early', 'flexible', 'night'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_clean') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_clean
      check (cleanliness is null or cleanliness between 1 and 5);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_social') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_social
      check (social is null or social in ('quiet', 'balanced', 'social'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_wfh') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_wfh
      check (wfh is null or wfh in ('office', 'hybrid', 'home'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_cooking') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_cooking
      check (cooking is null or cooking in ('rarely', 'sometimes', 'often'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_guests') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_guests
      check (guests is null or guests in ('rare', 'sometimes', 'often'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_age') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_age
      check (age is null or age between 18 and 99);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_budget') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_budget
      check (
        budget_min_inr is null
        or budget_max_inr is null
        or budget_min_inr <= budget_max_inr
      );
  end if;
  if not exists (select 1 from pg_constraint where conname = 'roommate_profiles_thoughts') then
    alter table public.roommate_profiles
      add constraint roommate_profiles_thoughts
      check (char_length(thoughts) <= 500);
  end if;
end
$roommate_profile_checks$;

comment on table public.roommate_profiles is
  'Discoverable flatmate preferences. Phone and email are not stored here.';

create index if not exists roommate_profiles_discoverable_idx
  on public.roommate_profiles (discoverable, seeking_role);

drop trigger if exists roommate_profiles_set_updated_at on public.roommate_profiles;
create trigger roommate_profiles_set_updated_at
  before update on public.roommate_profiles
  for each row execute function public.set_updated_at();

alter table public.roommate_profiles enable row level security;

drop policy if exists roommate_profiles_select_own on public.roommate_profiles;
create policy roommate_profiles_select_own on public.roommate_profiles
  for select to authenticated
  using (user_id = auth.uid() or public.is_staff());

drop policy if exists roommate_profiles_insert_own on public.roommate_profiles;
create policy roommate_profiles_insert_own on public.roommate_profiles
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists roommate_profiles_update_own on public.roommate_profiles;
create policy roommate_profiles_update_own on public.roommate_profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.roommate_profiles from public, anon;
grant select, insert, update on public.roommate_profiles to authenticated;

-- Weights: docs/MATCHING.md. Religion, caste, and age are not read.

create or replace function public._roommate_budget_points(
  a_min integer, a_max integer, b_min integer, b_max integer
) returns integer
language plpgsql immutable
set search_path = public
as $$
declare
  a0 integer;
  a1 integer;
  b0 integer;
  b1 integer;
  gap integer;
  bound integer;
begin
  if (a_min is null and a_max is null) or (b_min is null and b_max is null) then
    return 6;
  end if;
  a0 := least(coalesce(a_min, a_max), coalesce(a_max, a_min));
  a1 := greatest(coalesce(a_min, a_max), coalesce(a_max, a_min));
  b0 := least(coalesce(b_min, b_max), coalesce(b_max, b_min));
  b1 := greatest(coalesce(b_min, b_max), coalesce(b_max, b_min));
  if a1 >= b0 and b1 >= a0 then
    return 12;
  end if;
  if a1 < b0 then
    gap := b0 - a1;
  else
    gap := a0 - b1;
  end if;
  bound := least(a1, b1);
  if bound <= 0 then
    return 0;
  end if;
  if gap * 5 <= bound then
    return 6;
  end if;
  return 0;
end;
$$;

create or replace function public._roommate_locality_points(
  p_city_a text, p_city_b text, p_a text[], p_b text[]
) returns integer
language plpgsql immutable
set search_path = public
as $$
declare
  v_city_a text := lower(btrim(coalesce(p_city_a, '')));
  v_city_b text := lower(btrim(coalesce(p_city_b, '')));
  v_left integer;
  v_right integer;
  v_shared boolean;
begin
  if v_city_a = '' or v_city_a <> v_city_b then
    return 0;
  end if;
  select count(*) into v_left
  from unnest(coalesce(p_a, '{}'::text[])) as item
  where btrim(item) <> '';
  select count(*) into v_right
  from unnest(coalesce(p_b, '{}'::text[])) as item
  where btrim(item) <> '';
  if v_left = 0 or v_right = 0 then
    return 6;
  end if;
  select exists (
    select 1
    from unnest(p_a) as left_item
    join unnest(p_b) as right_item
      on lower(btrim(left_item)) = lower(btrim(right_item))
    where btrim(left_item) <> '' and btrim(right_item) <> ''
  ) into v_shared;
  if v_shared then
    return 10;
  end if;
  return 4;
end;
$$;

create or replace function public._roommate_accepts(
  p_pref text, p_self text, p_other text
) returns boolean
language plpgsql immutable
set search_path = public
as $$
declare
  v_pref text := lower(btrim(coalesce(p_pref, '')));
  v_self text := lower(btrim(coalesce(p_self, '')));
  v_other text := lower(btrim(coalesce(p_other, '')));
begin
  if v_pref = '' or v_pref = 'any' then
    return true;
  end if;
  if v_other = '' or v_other = 'undisclosed' then
    return true;
  end if;
  if v_pref = 'women' then
    return v_other = 'woman';
  end if;
  if v_pref = 'men' then
    return v_other = 'man';
  end if;
  if v_pref = 'same' then
    if v_self = '' or v_self = 'undisclosed' then
      return true;
    end if;
    return v_self = v_other;
  end if;
  return true;
end;
$$;

create or replace function public._roommate_scale(
  p_a text, p_b text, p_order text[], p_full integer, p_near integer, p_far integer, p_unknown integer
) returns integer
language plpgsql immutable
set search_path = public
as $$
declare
  v_a text := lower(btrim(coalesce(p_a, '')));
  v_b text := lower(btrim(coalesce(p_b, '')));
  v_ia integer;
  v_ib integer;
  v_distance integer;
begin
  if v_a = '' or v_b = '' then
    return p_unknown;
  end if;
  v_ia := array_position(p_order, v_a);
  v_ib := array_position(p_order, v_b);
  if v_ia is null or v_ib is null then
    return p_unknown;
  end if;
  v_distance := abs(v_ia - v_ib);
  if v_distance = 0 then
    return p_full;
  end if;
  if v_distance = 1 then
    return p_near;
  end if;
  return p_far;
end;
$$;

create or replace function public._roommate_list_points(p_a text[], p_b text[])
returns integer
language plpgsql immutable
set search_path = public
as $$
declare
  v_left integer;
  v_right integer;
  v_shared boolean;
begin
  select count(*) into v_left
  from unnest(coalesce(p_a, '{}'::text[])) as item
  where btrim(item) <> '';
  select count(*) into v_right
  from unnest(coalesce(p_b, '{}'::text[])) as item
  where btrim(item) <> '';
  if v_left = 0 or v_right = 0 then
    return 2;
  end if;
  select exists (
    select 1
    from unnest(p_a) as left_item
    join unnest(p_b) as right_item
      on lower(btrim(left_item)) = lower(btrim(right_item))
    where btrim(left_item) <> '' and btrim(right_item) <> ''
  ) into v_shared;
  if v_shared then
    return 4;
  end if;
  return 0;
end;
$$;

create or replace function public._roommate_thought_tokens(p_text text)
returns text[]
language sql immutable
set search_path = public
as $$
  select coalesce(array_agg(distinct token), '{}'::text[])
  from (
    select token
    from regexp_split_to_table(lower(coalesce(p_text, '')), '[^a-z]+') as token
    where char_length(token) >= 4
      and token not in (
        'with', 'this', 'that', 'your', 'want', 'looking', 'from', 'they', 'their'
      )
  ) as words;
$$;

create or replace function public._roommate_thought_points(p_a text, p_b text)
returns integer
language plpgsql immutable
set search_path = public
as $$
declare
  v_left text[] := public._roommate_thought_tokens(p_a);
  v_right text[] := public._roommate_thought_tokens(p_b);
  v_shared integer;
begin
  if coalesce(array_length(v_left, 1), 0) = 0
     or coalesce(array_length(v_right, 1), 0) = 0 then
    return 2;
  end if;
  select count(*) into v_shared
  from (
    select unnest(v_left)
    intersect
    select unnest(v_right)
  ) as shared;
  if v_shared >= 2 then
    return 5;
  end if;
  if v_shared = 1 then
    return 3;
  end if;
  return 0;
end;
$$;

create or replace function public._roommate_row(
  p_key text, p_label text, p_points integer, p_max integer, p_detail text
) returns jsonb
language sql immutable
set search_path = public
as $$
  select jsonb_build_object(
    'key', p_key,
    'label', p_label,
    'ok', p_points = p_max,
    'detail', p_detail,
    'points', p_points,
    'max', p_max
  );
$$;

create or replace function public._roommate_compatibility_detail(p_a uuid, p_b uuid)
returns jsonb
language plpgsql stable
security definer
set search_path = public
as $$
declare
  l public.roommate_profiles;
  r public.roommate_profiles;
  v_city integer;
  v_locality integer;
  v_budget integer;
  v_move integer;
  v_gender integer;
  v_occupancy integer;
  v_food integer;
  v_smoking integer;
  v_pets integer;
  v_sleep integer;
  v_clean integer;
  v_social integer;
  v_wfh integer;
  v_cooking integer;
  v_guests integer;
  v_languages integer;
  v_hobbies integer;
  v_thoughts integer;
  v_food_conflict boolean;
  v_smoke_conflict boolean;
  v_pet_conflict boolean;
  v_rows jsonb := '[]'::jsonb;
  v_highlights jsonb := '[]'::jsonb;
  v_score integer;
  v_label text;
  v_days integer;
begin
  select * into l from public.roommate_profiles where user_id = p_a;
  select * into r from public.roommate_profiles where user_id = p_b;
  if l.user_id is null or r.user_id is null then
    return jsonb_build_object('score', 0, 'rows', '[]'::jsonb, 'highlights', '[]'::jsonb);
  end if;

  if lower(btrim(coalesce(l.city, ''))) <> ''
     and lower(btrim(l.city)) = lower(btrim(coalesce(r.city, ''))) then
    v_city := 12;
  else
    v_city := 0;
  end if;
  v_locality := public._roommate_locality_points(l.city, r.city, l.localities, r.localities);
  v_budget := public._roommate_budget_points(
    l.budget_min_inr, l.budget_max_inr, r.budget_min_inr, r.budget_max_inr
  );
  if l.move_in_date is null or r.move_in_date is null then
    v_move := 8;
  else
    v_days := abs(l.move_in_date - r.move_in_date);
    v_move := case when v_days <= 30 then 8 when v_days <= 60 then 4 else 0 end;
  end if;
  if public._roommate_accepts(l.gender_preference, l.gender, r.gender)
     and public._roommate_accepts(r.gender_preference, r.gender, l.gender) then
    v_gender := 8;
  else
    v_gender := 0;
  end if;
  if lower(btrim(coalesce(l.occupancy, ''))) = ''
     or lower(btrim(coalesce(r.occupancy, ''))) = ''
     or lower(btrim(l.occupancy)) = 'any'
     or lower(btrim(r.occupancy)) = 'any'
     or lower(btrim(l.occupancy)) = lower(btrim(r.occupancy)) then
    v_occupancy := 4;
  else
    v_occupancy := 0;
  end if;

  v_food_conflict := false;
  if lower(btrim(coalesce(l.food, ''))) <> ''
     and lower(btrim(coalesce(r.food, ''))) <> ''
     and lower(btrim(l.food)) <> 'any'
     and lower(btrim(r.food)) <> 'any'
     and lower(btrim(l.food)) <> lower(btrim(r.food)) then
    if lower(btrim(l.food)) = 'veg' or lower(btrim(r.food)) = 'veg' then
      v_food_conflict := true;
    elsif (lower(btrim(l.food)) = 'eggetarian' and lower(btrim(r.food)) = 'non_veg')
       or (lower(btrim(r.food)) = 'eggetarian' and lower(btrim(l.food)) = 'non_veg') then
      v_food_conflict := true;
    end if;
  end if;
  v_food := case
    when v_food_conflict and (l.food_dealbreaker or r.food_dealbreaker) then 0
    else 2
  end;

  v_smoke_conflict := lower(btrim(coalesce(l.smoking, ''))) <> ''
    and lower(btrim(coalesce(r.smoking, ''))) <> ''
    and lower(btrim(l.smoking)) <> lower(btrim(r.smoking))
    and (lower(btrim(l.smoking)) = 'never' or lower(btrim(r.smoking)) = 'never');
  v_smoking := case
    when v_smoke_conflict and (l.smoking_dealbreaker or r.smoking_dealbreaker) then 0
    else 2
  end;

  v_pet_conflict := (
    lower(btrim(coalesce(l.pets, ''))) = 'has' and lower(btrim(coalesce(r.pets, ''))) = 'none'
  ) or (
    lower(btrim(coalesce(l.pets, ''))) = 'none' and lower(btrim(coalesce(r.pets, ''))) = 'has'
  );
  v_pets := case
    when v_pet_conflict and (l.pets_dealbreaker or r.pets_dealbreaker) then 0
    else 2
  end;

  v_sleep := public._roommate_scale(l.sleep, r.sleep, array['early', 'flexible', 'night'], 5, 3, 0, 3);
  if l.cleanliness is null or r.cleanliness is null
     or l.cleanliness < 1 or l.cleanliness > 5
     or r.cleanliness < 1 or r.cleanliness > 5 then
    v_clean := 3;
  else
    v_clean := case abs(l.cleanliness - r.cleanliness)
      when 0 then 5
      when 1 then 3
      when 2 then 1
      else 0
    end;
  end if;
  v_social := public._roommate_scale(l.social, r.social, array['quiet', 'balanced', 'social'], 5, 3, 0, 3);
  if lower(btrim(coalesce(l.wfh, ''))) = '' or lower(btrim(coalesce(r.wfh, ''))) = '' then
    v_wfh := 2;
  elsif lower(btrim(l.wfh)) = lower(btrim(r.wfh)) then
    v_wfh := 4;
  elsif lower(btrim(l.wfh)) = 'hybrid' or lower(btrim(r.wfh)) = 'hybrid' then
    v_wfh := 2;
  else
    v_wfh := 0;
  end if;
  v_cooking := public._roommate_scale(l.cooking, r.cooking, array['rarely', 'sometimes', 'often'], 4, 2, 0, 2);
  v_guests := public._roommate_scale(l.guests, r.guests, array['rare', 'sometimes', 'often'], 4, 2, 0, 2);
  v_languages := public._roommate_list_points(l.languages, r.languages);
  v_hobbies := public._roommate_list_points(l.hobbies, r.hobbies);
  v_thoughts := public._roommate_thought_points(l.thoughts, r.thoughts);

  v_rows := jsonb_build_array(
    public._roommate_row('city', 'City', v_city, 12, case when v_city = 12 then 'Same city.' else 'Different cities.' end),
    public._roommate_row('locality', 'Locality', v_locality, 10, case v_locality when 10 then 'Shared locality.' when 6 then 'Locality not set.' when 4 then 'Same city, different localities.' else 'No shared locality.' end),
    public._roommate_row('budget', 'Budget', v_budget, 12, case
      when l.budget_min_inr is null and l.budget_max_inr is null then 'Budgets are not set.'
      when r.budget_min_inr is null and r.budget_max_inr is null then 'Budgets are not set.'
      when v_budget = 12 then 'Budgets overlap.'
      when v_budget = 6 then 'Budgets are close.'
      else 'Budgets do not overlap.'
    end),
    public._roommate_row('move_in', 'Move-in', v_move, 8, case
      when l.move_in_date is null or r.move_in_date is null then 'Move-in is flexible.'
      when v_move = 8 then 'Move-in dates are within a month.'
      when v_move = 4 then 'Move-in dates are within two months.'
      else 'Move-in dates are far apart.'
    end),
    public._roommate_row('gender', 'Gender preference', v_gender, 8, case when v_gender = 8 then 'Gender preferences fit.' else 'A gender preference does not fit.' end),
    public._roommate_row('occupancy', 'Occupancy', v_occupancy, 4, case when v_occupancy = 4 then 'Occupancy preferences fit.' else 'Occupancy preferences differ.' end),
    public._roommate_row('food', 'Food', v_food, 2, case when v_food = 2 then 'Food habits fit.' else 'A food dealbreaker conflicts.' end),
    public._roommate_row('smoking', 'Smoking', v_smoking, 2, case when v_smoking = 2 then 'Smoking habits fit.' else 'A smoking dealbreaker conflicts.' end),
    public._roommate_row('pets', 'Pets', v_pets, 2, case when v_pets = 2 then 'Pet habits fit.' else 'A pet dealbreaker conflicts.' end),
    public._roommate_row('sleep', 'Sleep', v_sleep, 5, case when v_sleep = 5 then 'Sleep schedules match.' when v_sleep = 0 then 'Sleep schedules differ.' else 'Sleep schedules are close or not set.' end),
    public._roommate_row('cleanliness', 'Cleanliness', v_clean, 5, case when v_clean = 5 then 'Cleanliness matches.' when v_clean = 0 then 'Cleanliness is far apart.' else 'Cleanliness is close or not set.' end),
    public._roommate_row('social', 'Social', v_social, 5, case when v_social = 5 then 'Social levels match.' when v_social = 0 then 'Social levels differ.' else 'Social levels are close or not set.' end),
    public._roommate_row('wfh', 'Work from home', v_wfh, 4, case when v_wfh = 4 then 'Work styles match.' when v_wfh = 0 then 'Work styles differ.' else 'Work styles are close or not set.' end),
    public._roommate_row('cooking', 'Cooking', v_cooking, 4, case when v_cooking = 4 then 'Cooking habits match.' when v_cooking = 0 then 'Cooking habits differ.' else 'Cooking habits are close or not set.' end),
    public._roommate_row('guests', 'Guests', v_guests, 4, case when v_guests = 4 then 'Guest habits match.' when v_guests = 0 then 'Guest habits differ.' else 'Guest habits are close or not set.' end),
    public._roommate_row('languages', 'Languages', v_languages, 4, case
      when coalesce(array_length(l.languages, 1), 0) = 0 or coalesce(array_length(r.languages, 1), 0) = 0 then 'A language list is not set.'
      when v_languages = 4 then 'You share a language.'
      else 'No shared language.'
    end),
    public._roommate_row('hobbies', 'Hobbies', v_hobbies, 4, case
      when coalesce(array_length(l.hobbies, 1), 0) = 0 or coalesce(array_length(r.hobbies, 1), 0) = 0 then 'A hobby list is not set.'
      when v_hobbies = 4 then 'You share a hobby.'
      else 'No shared hobby.'
    end),
    public._roommate_row('thoughts', 'Flatmate notes', v_thoughts, 5, case
      when coalesce(array_length(public._roommate_thought_tokens(l.thoughts), 1), 0) = 0
        or coalesce(array_length(public._roommate_thought_tokens(r.thoughts), 1), 0) = 0
        then 'Flatmate notes are not set.'
      when v_thoughts = 5 then 'Flatmate notes overlap.'
      when v_thoughts = 3 then 'Flatmate notes share a little.'
      else 'Flatmate notes do not overlap.'
    end)
  );

  if v_city = 12 then
    v_highlights := v_highlights || jsonb_build_array(
      'You both look in ' || btrim(l.city) || '.'
    );
  end if;
  select btrim(left_item) into v_label
  from unnest(l.localities) as left_item
  where btrim(left_item) <> ''
    and exists (
      select 1 from unnest(r.localities) as right_item
      where lower(btrim(right_item)) = lower(btrim(left_item))
        and btrim(right_item) <> ''
    )
  limit 1;
  if v_label is not null then
    v_highlights := v_highlights || jsonb_build_array('You both named ' || v_label || '.');
  end if;
  if v_budget = 12 then
    v_highlights := v_highlights || jsonb_build_array('You both fit an overlapping budget.');
  end if;
  if l.move_in_date is not null and r.move_in_date is not null and v_move = 8 then
    v_highlights := v_highlights || jsonb_build_array(
      'You both want to move within a month of each other.'
    );
  end if;
  if lower(btrim(coalesce(l.sleep, ''))) <> ''
     and lower(btrim(l.sleep)) = lower(btrim(coalesce(r.sleep, ''))) then
    v_highlights := v_highlights || jsonb_build_array(
      case lower(btrim(l.sleep))
        when 'early' then 'You both keep early hours.'
        when 'night' then 'You both keep late hours.'
        else 'You both keep flexible hours.'
      end
    );
  end if;
  if l.cleanliness is not null and r.cleanliness is not null
     and l.cleanliness >= 4 and r.cleanliness >= 4
     and abs(l.cleanliness - r.cleanliness) <= 1 then
    v_highlights := v_highlights || jsonb_build_array('You both like a tidy home.');
  end if;
  if lower(btrim(coalesce(l.social, ''))) <> ''
     and lower(btrim(l.social)) = lower(btrim(coalesce(r.social, ''))) then
    v_highlights := v_highlights || jsonb_build_array(
      case lower(btrim(l.social))
        when 'quiet' then 'You both want a quiet home.'
        when 'social' then 'You both want a social home.'
        else 'You both want a balanced home.'
      end
    );
  end if;
  if lower(btrim(coalesce(l.wfh, ''))) <> ''
     and lower(btrim(l.wfh)) = lower(btrim(coalesce(r.wfh, ''))) then
    v_highlights := v_highlights || jsonb_build_array(
      case lower(btrim(l.wfh))
        when 'home' then 'You both work from home.'
        when 'office' then 'You both work from an office.'
        else 'You both work a hybrid week.'
      end
    );
  end if;
  for v_label in
    select btrim(left_item)
    from unnest(l.languages) as left_item
    where btrim(left_item) <> ''
      and lower(btrim(left_item)) in (
        select lower(btrim(right_item))
        from unnest(r.languages) as right_item
        where btrim(right_item) <> ''
      )
    limit 2
  loop
    v_highlights := v_highlights || jsonb_build_array('You both speak ' || v_label || '.');
  end loop;
  for v_label in
    select btrim(left_item)
    from unnest(l.hobbies) as left_item
    where btrim(left_item) <> ''
      and lower(btrim(left_item)) in (
        select lower(btrim(right_item))
        from unnest(r.hobbies) as right_item
        where btrim(right_item) <> ''
      )
    limit 2
  loop
    v_highlights := v_highlights || jsonb_build_array('You both enjoy ' || v_label || '.');
  end loop;

  v_score := v_city + v_locality + v_budget + v_move + v_gender + v_occupancy
    + v_food + v_smoking + v_pets + v_sleep + v_clean + v_social + v_wfh
    + v_cooking + v_guests + v_languages + v_hobbies + v_thoughts;
  if v_score < 0 then
    v_score := 0;
  elsif v_score > 100 then
    v_score := 100;
  end if;
  return jsonb_build_object('score', v_score, 'rows', v_rows, 'highlights', v_highlights);
end;
$$;

create or replace function public.roommate_compatibility(a uuid, b uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'permission denied for function roommate_compatibility'
      using errcode = '42501';
  end if;
  if auth.uid() is distinct from a
     and auth.uid() is distinct from b
     and not public.is_staff() then
    raise exception 'permission denied for function roommate_compatibility'
      using errcode = '42501';
  end if;
  return (public._roommate_compatibility_detail(a, b) ->> 'score')::integer;
end;
$$;

create or replace function public.roommate_compatibility_breakdown(a uuid, b uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'permission denied for function roommate_compatibility_breakdown'
      using errcode = '42501';
  end if;
  if auth.uid() is distinct from a
     and auth.uid() is distinct from b
     and not public.is_staff() then
    raise exception 'permission denied for function roommate_compatibility_breakdown'
      using errcode = '42501';
  end if;
  return public._roommate_compatibility_detail(a, b);
end;
$$;

create or replace function public.list_roommate_seekers(
  p_locality text default null,
  p_budget_min integer default null,
  p_budget_max integer default null,
  p_gender text default null,
  p_move_in_window text default null,
  p_today date default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := coalesce(p_today, current_date);
  v_rows jsonb;
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;
  select coalesce(jsonb_agg(item order by score desc, display_name), '[]'::jsonb)
  into v_rows
  from (
    select
      p.display_name,
      public._roommate_compatibility_detail(v_uid, rp.user_id) ->> 'score' as score_text,
      (public._roommate_compatibility_detail(v_uid, rp.user_id) ->> 'score')::integer as score,
      jsonb_build_object(
        'user_id', rp.user_id,
        'display_name', p.display_name,
        'age', rp.age,
        'profession', p.occupation,
        'photo_url', p.avatar_path,
        'city', rp.city,
        'localities', rp.localities,
        'budget_min_inr', rp.budget_min_inr,
        'budget_max_inr', rp.budget_max_inr,
        'move_in_date', rp.move_in_date,
        'gender', rp.gender,
        'seeking_role', rp.seeking_role,
        'score', (public._roommate_compatibility_detail(v_uid, rp.user_id) ->> 'score')::integer,
        'verified',
          coalesce(ub.aadhaar_verified, false)
          or coalesce(ub.face_verified, false)
          or p.verification_status = 'mock_verified',
        'aadhaar_verified', coalesce(ub.aadhaar_verified, false),
        'face_verified', coalesce(ub.face_verified, false),
        'likes_you', exists (
          select 1 from public.interests i
          where i.actor_user_id = rp.user_id
            and i.target_type = 'user'
            and i.target_id = v_uid
            and i.action = 'like'
        )
      ) as item
    from public.roommate_profiles rp
    join public.users u on u.id = rp.user_id
    join public.profiles p on p.user_id = rp.user_id
    left join public.user_badges ub on ub.user_id = rp.user_id
    where rp.discoverable
      and u.status = 'active'
      and rp.user_id <> v_uid
      and (
        coalesce(p.primary_role, rp.seeking_role) = 'roommate'
        or (
          coalesce(p.primary_role, rp.seeking_role) = 'tenant'
          and rp.open_to_flatmates
        )
      )
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = v_uid and b.blocked_user_id = rp.user_id)
           or (b.blocker_id = rp.user_id and b.blocked_user_id = v_uid)
      )
      and (
        p_locality is null or btrim(p_locality) = ''
        or rp.city ilike '%' || p_locality || '%'
        or exists (
          select 1 from unnest(rp.localities) as loc
          where loc ilike '%' || p_locality || '%'
        )
      )
      and (
        p_gender is null or btrim(p_gender) = '' or lower(p_gender) = 'any'
        or lower(coalesce(rp.gender, '')) = lower(p_gender)
      )
      and (
        p_budget_min is null or p_budget_max is null
        or (rp.budget_min_inr is null and rp.budget_max_inr is null)
        or (
          coalesce(rp.budget_max_inr, rp.budget_min_inr) >= p_budget_min
          and coalesce(rp.budget_min_inr, rp.budget_max_inr) <= p_budget_max
        )
      )
      and (
        p_move_in_window is null
        or btrim(p_move_in_window) = ''
        or p_move_in_window = 'any'
        or (p_move_in_window = 'flexible' and rp.move_in_date is null)
        or (
          p_move_in_window in ('30', '60')
          and (
            rp.move_in_date is null
            or abs(rp.move_in_date - v_today) <= p_move_in_window::integer
          )
        )
      )
  ) as scored;
  return v_rows;
end;
$$;

comment on function public.roommate_compatibility(uuid, uuid) is
  'Roommate compatibility from 0 to 100. Does not read religion, caste, or age.';

revoke all on function public._roommate_budget_points(integer, integer, integer, integer) from public, anon, authenticated;
revoke all on function public._roommate_locality_points(text, text, text[], text[]) from public, anon, authenticated;
revoke all on function public._roommate_accepts(text, text, text) from public, anon, authenticated;
revoke all on function public._roommate_scale(text, text, text[], integer, integer, integer, integer) from public, anon, authenticated;
revoke all on function public._roommate_list_points(text[], text[]) from public, anon, authenticated;
revoke all on function public._roommate_thought_tokens(text) from public, anon, authenticated;
revoke all on function public._roommate_thought_points(text, text) from public, anon, authenticated;
revoke all on function public._roommate_row(text, text, integer, integer, text) from public, anon, authenticated;
revoke all on function public._roommate_compatibility_detail(uuid, uuid) from public, anon, authenticated;
revoke all on function public.roommate_compatibility(uuid, uuid) from public, anon;
revoke all on function public.roommate_compatibility_breakdown(uuid, uuid) from public, anon;
revoke all on function public.list_roommate_seekers(text, integer, integer, text, text, date) from public, anon;

grant execute on function public.roommate_compatibility(uuid, uuid) to authenticated;
grant execute on function public.roommate_compatibility_breakdown(uuid, uuid) to authenticated;
grant execute on function public.list_roommate_seekers(text, integer, integer, text, text, date) to authenticated;

-- Staging roommate seekers. Safe to run again.
-- test@homizi.in keeps an existing password. A brand-new mailbox copies
-- private.staging_secrets.test_password when that row is already set.
-- This seed does not invent a password and does not replace one.
-- Public rows have no phone. Contact stays on private_contacts.

do $roommate_seed$
declare
  v_viewer uuid;
  v_existed boolean;
  v_id uuid;
  v_req uuid;
  v_bio text;
  v_lifestyle text[];
  v_password text;
  rec record;
begin
  if to_regclass('auth.users') is null then
    raise notice 'auth.users missing; roommate seed skipped';
    return;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'primary_role'
  ) then
    raise exception 'profiles.primary_role is missing; apply 20261018120000 first';
  end if;

  select id into v_viewer
  from auth.users
  where lower(email) = 'test@homizi.in'
  limit 1;
  v_existed := v_viewer is not null;
  if not v_existed then
    v_viewer := 'a1019000-0000-4000-8000-000000000001';
    perform public.homizi_seed_auth_user(v_viewer, 'test@homizi.in');
    if to_regclass('private.staging_secrets') is not null then
      select value
      into v_password
      from private.staging_secrets
      where key = 'test_password';
      if v_password is not null and btrim(v_password) <> '' then
        update auth.users
        set encrypted_password = extensions.crypt(
          v_password,
          extensions.gen_salt('bf')
        )
        where id = v_viewer;
      end if;
    end if;
  end if;

  for rec in
    select * from (values
    ('001', 'test@homizi.in', 'Ananya Iyer', 27, 'Product manager', 2, 'Bengaluru', array['Koramangala', 'Indiranagar']::text[], 18000, 32000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', true, 'never', true, 'none', false, 'early', 4, 'quiet', 'hybrid', 'often', 'rare', array['English', 'Hindi', 'Kannada']::text[], array['reading', 'yoga', 'cooking']::text[], 'I want a quiet flatmate who cooks and keeps the kitchen clean.', true, true, false, 'roommate', false, true),
    ('011', 'roommate-011@example.test', 'Mira Shah', 26, 'Architect', 1, 'Bengaluru', array['Koramangala']::text[], 18000, 32000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 5, 'quiet', 'hybrid', 'often', 'rare', array['English', 'Hindi']::text[], array['reading', 'yoga']::text[], '', true, false, true, 'roommate', true, true),
    ('012', 'roommate-012@example.test', 'Aisha Rahman', 28, 'Product designer', 2, 'Bengaluru', array['Indiranagar']::text[], 18000, 32000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 4, 'balanced', 'hybrid', 'sometimes', 'sometimes', array['English', 'Hindi']::text[], array['reading', 'yoga']::text[], 'A quiet weeknight and a clean kitchen.', true, true, false, 'roommate', true, true),
    ('013', 'roommate-013@example.test', 'Kabir Rao', 27, 'Software engineer', 3, 'Bengaluru', array['HSR Layout']::text[], 18000, 32000, date '2026-12-01', 'man', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'night', 4, 'balanced', 'home', 'often', 'rare', array['English', 'Hindi']::text[], array['reading', 'yoga']::text[], 'I work late and like a calm flat.', false, false, false, 'roommate', true, true),
    ('014', 'roommate-014@example.test', 'Rohan Mehta', 31, 'Consultant', 4, 'Mumbai', array['Andheri']::text[], 20000, 40000, date '2026-12-10', 'man', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'night', 1, 'social', 'office', 'rarely', 'often', array['Marathi']::text[], array['cricket']::text[], 'Weekend cricket and late dinners.', false, false, false, 'roommate', true, true),
    ('015', 'roommate-015@example.test', 'Sana Qureshi', 25, 'Journalist', 5, 'Mumbai', array['Bandra']::text[], 25000, 45000, date '2026-12-01', 'woman', 'any', 'shared', 'eggetarian', true, 'never', false, 'none', false, 'early', 4, 'balanced', 'hybrid', 'often', 'rare', array['English', 'Hindi']::text[], array['reading']::text[], 'I want a quiet flatmate.', true, false, false, 'roommate', true, true),
    ('016', 'roommate-016@example.test', 'Neel Kapoor', 29, 'Analyst', 6, 'Mumbai', array['Powai']::text[], 18000, 32000, date '2026-12-01', 'man', 'any', 'shared', 'veg', false, 'sometimes', false, 'none', false, 'flexible', 4, 'quiet', 'hybrid', 'often', 'rare', array['English', 'Hindi']::text[], array['yoga']::text[], 'Hybrid weeks and a tidy desk.', false, false, false, 'roommate', true, true),
    ('017', 'roommate-017@example.test', 'Isha Kulkarni', 24, 'Teacher', 1, 'Pune', array['Kothrud']::text[], 12000, 22000, date '2026-11-20', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 4, 'quiet', 'hybrid', 'often', 'rare', array['Marathi', 'Hindi']::text[], array['cooking']::text[], 'Early mornings and home food.', true, false, false, 'roommate', true, true),
    ('018', 'roommate-018@example.test', 'Dev Patil', 33, 'Chef', 2, 'Pune', array['Baner']::text[], 18000, 32000, date '2026-12-01', 'man', 'any', 'shared', 'non_veg', false, 'never', false, 'ok', false, 'night', 4, 'quiet', 'hybrid', 'often', 'rare', array['Marathi', 'English']::text[], array['cooking']::text[], 'I cook most nights.', false, false, false, 'roommate', true, true),
    ('019', 'roommate-019@example.test', 'Meera Joshi', 27, 'UX researcher', 3, 'Pune', array['Viman Nagar']::text[], 18000, 32000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 5, 'quiet', 'home', 'often', 'rare', array['English', 'Hindi']::text[], array['reading', 'yoga']::text[], 'Quiet flatmate, please.', true, false, false, 'roommate', true, true),
    ('020', 'roommate-020@example.test', 'Aarav Malik', 26, 'Lawyer', 4, 'Delhi NCR', array['Gurugram']::text[], 20000, 35000, date '2026-12-01', 'man', 'any', 'shared', 'veg', false, 'regularly', false, 'none', false, 'early', 4, 'social', 'hybrid', 'often', 'often', array['Hindi', 'English']::text[], array['football']::text[], 'Evenings out with friends.', false, false, false, 'roommate', true, true),
    ('021', 'roommate-021@example.test', 'Priya Nair', 30, 'Doctor', 5, 'Delhi NCR', array['Noida']::text[], 18000, 32000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', true, 'never', false, 'none', false, 'night', 5, 'quiet', 'hybrid', 'often', 'rare', array['English', 'Hindi', 'Malayalam']::text[], array['yoga']::text[], 'Night shifts and a clean kitchen.', true, false, false, 'roommate', true, true),
    ('022', 'roommate-022@example.test', 'Rahul Verma', 28, 'Data scientist', 6, 'Delhi NCR', array['Dwarka']::text[], 18000, 32000, date '2026-12-01', 'man', 'any', 'shared', 'veg', false, 'never', false, 'has', true, 'night', 4, 'quiet', 'home', 'often', 'rare', array['Hindi']::text[], array['gaming']::text[], 'I have a cat and work from home.', false, false, false, 'roommate', true, true),
    ('023', 'roommate-023@example.test', 'Anika Reddy', 25, 'Pharmacist', 1, 'Hyderabad', array['Gachibowli']::text[], 15000, 28000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 4, 'quiet', 'hybrid', 'often', 'rare', array['Telugu', 'English', 'Hindi']::text[], array['reading']::text[], 'A quiet flat near work.', true, false, false, 'roommate', true, true),
    ('024', 'roommate-024@example.test', 'Varun Rao', 32, 'Founder', 2, 'Hyderabad', array['Madhapur']::text[], 25000, 50000, date '2026-12-01', 'man', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 4, 'quiet', 'hybrid', 'often', 'sometimes', array['English', 'Hindi', 'Telugu']::text[], array['cricket', 'reading']::text[], 'Hybrid work and weekend cricket.', false, false, false, 'roommate', true, true),
    ('025', 'roommate-025@example.test', 'Diya Krishnan', 23, 'Student', 3, 'Hyderabad', array['Kondapur']::text[], 8000, 15000, date '2027-01-15', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 4, 'social', 'hybrid', 'often', 'often', array['Telugu', 'English']::text[], array['dance']::text[], 'Friends over on weekends.', false, false, false, 'roommate', true, true),
    ('026', 'roommate-026@example.test', 'Het Shah', 27, 'Chartered accountant', 4, 'Ahmedabad', array['Satellite']::text[], 14000, 26000, date '2026-12-01', 'man', 'any', 'shared', 'veg', true, 'never', false, 'none', false, 'early', 5, 'quiet', 'hybrid', 'often', 'rare', array['Gujarati', 'Hindi', 'English']::text[], array['reading']::text[], 'Early start and a vegetarian kitchen.', false, false, true, 'roommate', true, true),
    ('027', 'roommate-027@example.test', 'Nisha Patel', 29, 'Architect', 5, 'Ahmedabad', array['Bodakdev']::text[], 18000, 32000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 4, 'balanced', 'hybrid', 'often', 'rare', array['Gujarati', 'English', 'Hindi']::text[], array['yoga', 'reading']::text[], 'I want a tidy shared flat.', true, false, false, 'roommate', true, true),
    ('028', 'roommate-028@example.test', 'Jay Mehta', 26, 'Engineer', 6, 'Ahmedabad', array['Prahlad Nagar']::text[], 18000, 32000, date '2026-12-01', 'man', 'any', 'shared', 'veg', false, 'sometimes', false, 'none', false, 'night', 4, 'quiet', 'office', 'often', 'rare', array['Gujarati', 'Hindi']::text[], array['cricket']::text[], 'Office days and late nights.', false, false, false, 'roommate', true, true),
    ('029', 'roommate-029@example.test', 'Pooja Desai', 31, 'Designer', 1, 'Ahmedabad', array['SG Highway']::text[], 18000, 30000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 4, 'quiet', 'hybrid', 'often', 'rare', array['Gujarati', 'English', 'Hindi']::text[], array['cooking', 'yoga']::text[], 'Quiet evenings and home cooking.', true, false, false, 'roommate', true, true),
    ('030', 'roommate-030@example.test', 'Tara Iyer', 28, 'Writer', 2, 'Bengaluru', array['Whitefield']::text[], 18000, 32000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 4, 'quiet', 'home', 'often', 'rare', array['English', 'Tamil', 'Hindi']::text[], array['reading', 'yoga']::text[], 'A quiet corner and early nights.', true, true, false, 'tenant', true, true),
    ('031', 'roommate-031@example.test', 'Omar Farooq', 34, 'Photographer', 3, 'Hyderabad', array['Jubilee Hills']::text[], 20000, 38000, date '2026-12-01', 'man', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'night', 4, 'social', 'hybrid', 'often', 'sometimes', array['English', 'Hindi', 'Urdu']::text[], array['photography']::text[], 'Late shoots and a social flat.', false, false, false, 'roommate', true, true),
    ('032', 'roommate-032@example.test', 'Leela Menon', 26, 'Nurse', 4, 'Pune', array['Kalyani Nagar']::text[], 18000, 32000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', true, 'never', true, 'none', false, 'early', 5, 'quiet', 'hybrid', 'often', 'rare', array['Malayalam', 'English', 'Hindi']::text[], array['yoga', 'cooking']::text[], 'Early shifts and a vegetarian kitchen.', true, true, false, 'tenant', true, true),
    ('098', 'roommate-098@example.test', 'Closed Tenant', 29, 'Analyst', 3, 'Bengaluru', array['Koramangala']::text[], 18000, 32000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 4, 'quiet', 'hybrid', 'often', 'rare', array['English', 'Hindi']::text[], array['reading', 'yoga']::text[], 'A private rental search, not open to flatmates.', false, false, false, 'tenant', true, false),
    ('099', 'roommate-099@example.test', 'Hidden Seeker', 28, 'Researcher', 5, 'Bengaluru', array['Koramangala']::text[], 18000, 32000, date '2026-12-01', 'woman', 'any', 'shared', 'veg', false, 'never', false, 'none', false, 'early', 4, 'quiet', 'hybrid', 'often', 'rare', array['English', 'Hindi']::text[], array['reading', 'yoga']::text[], 'This profile stays out of roommate discovery.', false, false, false, 'roommate', false, true)
    ) as t(suffix, email, display_name, age, profession, photo, city, localities, budget_min, budget_max, move_in, gender, gender_pref, occupancy, food, food_db, smoking, smoking_db, pets, pets_db, sleep, cleanliness, social, wfh, cooking, guests, languages, hobbies, thoughts, verified, face, likes_you, seeking_role, discoverable, open_to)
  loop
    if rec.suffix = '001' then
      v_id := v_viewer;
    else
      v_id := ('a1019000-0000-4000-8000-000000000' || rec.suffix)::uuid;
      perform public.homizi_seed_auth_user(v_id, rec.email);
    end if;
    v_req := ('e1019000-0000-4000-8000-000000000' || rec.suffix)::uuid;
    v_bio := case
      when char_length(btrim(rec.thoughts)) >= 20 then rec.thoughts
      else 'Looking for a flatmate in ' || rec.city || '.'
    end;
    v_lifestyle := array_remove(array[
      case when rec.smoking = 'never' then 'non_smoker' end,
      case when rec.sleep = 'early' then 'early_riser' end,
      case when rec.sleep = 'night' then 'night_owl' end,
      case when rec.pets in ('ok', 'has') then 'pets_ok' end,
      case when rec.wfh in ('home', 'hybrid') then 'wfh' end
    ], null::text);

    insert into public.users (id, status, primary_role)
    values (v_id, 'active', 'tenant')
    on conflict (id) do update
    set status = 'active',
        primary_role = 'tenant';

    insert into public.profiles (
      user_id, display_name, occupation, public_bio, avatar_path, age_range,
      verification_status, primary_role
    ) values (
      v_id,
      rec.display_name,
      rec.profession,
      v_bio,
      'https://homizi.netlify.app/demo_media/avatar_0' || rec.photo::text || '.webp',
      case
        when rec.age <= 24 then '18-24'
        when rec.age <= 30 then '25-30'
        when rec.age <= 35 then '31-35'
        when rec.age <= 45 then '36-45'
        else '45+'
      end,
      case when rec.verified then 'mock_verified'::public.verification_status
           else 'not_started'::public.verification_status end,
      rec.seeking_role
    )
    on conflict (user_id) do update
    set display_name = excluded.display_name,
        occupation = excluded.occupation,
        public_bio = excluded.public_bio,
        avatar_path = excluded.avatar_path,
        age_range = excluded.age_range,
        verification_status = excluded.verification_status,
        primary_role = excluded.primary_role;

    insert into public.private_contacts (user_id, email, phone)
    values (v_id, rec.email, null)
    on conflict (user_id) do update
    set email = excluded.email,
        phone = null;

    insert into public.listing_requirements (
      id, user_id, city, localities, budget_min_inr, budget_max_inr,
      move_in_date, occupancy, property_types, furnishing, lifestyle, status
    ) values (
      v_req, v_id, rec.city, rec.localities, rec.budget_min, rec.budget_max,
      rec.move_in, 1, array['apartment']::public.property_type[], 'furnished',
      v_lifestyle, 'published'
    )
    on conflict (id) do update
    set status = 'published',
        city = excluded.city,
        localities = excluded.localities,
        budget_min_inr = excluded.budget_min_inr,
        budget_max_inr = excluded.budget_max_inr,
        move_in_date = excluded.move_in_date,
        lifestyle = excluded.lifestyle;

    insert into public.roommate_profiles (
      user_id, discoverable, open_to_flatmates, seeking_role, city, localities,
      budget_min_inr, budget_max_inr, move_in_date, gender, gender_preference,
      occupancy, food, food_dealbreaker, smoking, smoking_dealbreaker, pets,
      pets_dealbreaker, sleep, cleanliness, social, wfh, cooking, guests,
      languages, hobbies, thoughts, age
    ) values (
      v_id, rec.discoverable, rec.open_to, rec.seeking_role, rec.city, rec.localities,
      rec.budget_min, rec.budget_max, rec.move_in, rec.gender, rec.gender_pref,
      rec.occupancy, rec.food, rec.food_db, rec.smoking, rec.smoking_db, rec.pets,
      rec.pets_db, rec.sleep, rec.cleanliness, rec.social, rec.wfh, rec.cooking,
      rec.guests, rec.languages, rec.hobbies, rec.thoughts, rec.age
    )
    on conflict (user_id) do update
    set discoverable = excluded.discoverable,
        open_to_flatmates = excluded.open_to_flatmates,
        seeking_role = excluded.seeking_role,
        city = excluded.city,
        localities = excluded.localities,
        budget_min_inr = excluded.budget_min_inr,
        budget_max_inr = excluded.budget_max_inr,
        move_in_date = excluded.move_in_date,
        gender = excluded.gender,
        gender_preference = excluded.gender_preference,
        occupancy = excluded.occupancy,
        food = excluded.food,
        food_dealbreaker = excluded.food_dealbreaker,
        smoking = excluded.smoking,
        smoking_dealbreaker = excluded.smoking_dealbreaker,
        pets = excluded.pets,
        pets_dealbreaker = excluded.pets_dealbreaker,
        sleep = excluded.sleep,
        cleanliness = excluded.cleanliness,
        social = excluded.social,
        wfh = excluded.wfh,
        cooking = excluded.cooking,
        guests = excluded.guests,
        languages = excluded.languages,
        hobbies = excluded.hobbies,
        thoughts = excluded.thoughts,
        age = excluded.age;

    if rec.verified then
      insert into public.identity_verifications (
        user_id, verification_status, provider, aadhaar_status, face_status
      ) values (
        v_id,
        'verified',
        'demo',
        'verified',
        case when rec.face then 'verified' else 'not_started' end
      )
      on conflict (user_id) do update
      set verification_status = excluded.verification_status,
          provider = excluded.provider,
          aadhaar_status = excluded.aadhaar_status,
          face_status = excluded.face_status;
    end if;

    if rec.likes_you and v_id is distinct from v_viewer then
      insert into public.interests (
        actor_user_id, target_type, target_id, action
      ) values (
        v_id, 'user', v_viewer, 'like'
      )
      on conflict (actor_user_id, target_type, target_id, action) do nothing;
    end if;
  end loop;
end
$roommate_seed$;

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261018130000',
  'roommate_matching',
  array['docs/staging_apply_L_1019.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;

-- Account deletion must remove listing-photos under storage row security.
-- Idempotent. Apply after 20261018130000 in this same file.

-- delete_own_account runs as its owner (postgres). storage.objects has row
-- level security, and the listing-photos delete policy is only for the
-- authenticated role, so the owner delete matched no rows and left the
-- caller's photos in place. This policy lets that function remove objects
-- under the signed-in user's folder. It does not grant the role to clients.

do $$
begin
  if to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; listing photo delete policy skipped';
    return;
  end if;
  execute 'drop policy if exists listing_photos_delete_by_owner on storage.objects';
  execute $policy$
    create policy listing_photos_delete_by_owner on storage.objects
    for delete to postgres
    using (
      bucket_id = 'listing-photos'
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  $policy$;
exception
  when others then
    raise notice 'listing photo delete policy skipped: %', sqlerrm;
end
$$;

create or replace function public.delete_own_account()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_storage_removed boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'unauthenticated');
  end if;

  if to_regclass('storage.objects') is not null then
    begin
      -- storage.protect_delete blocks SQL deletes unless this setting is on.
      perform set_config('storage.allow_delete_query', 'true', true);
      delete from storage.objects
      where bucket_id = 'listing-photos'
        and split_part(name, '/', 1) = v_uid::text;
      v_storage_removed := true;
    exception
      when insufficient_privilege or undefined_table then
        v_storage_removed := false;
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

  return jsonb_build_object('ok', true, 'storage_removed', v_storage_removed);
end;
$$;

comment on function public.delete_own_account() is
  'The client lists and removes listing-photos under the user id, calls this function, then auth.signOut. This function deletes those storage objects, related rows, and auth.users. Cascades remove the profile, private contact, preferences, and messages. The body has no phone, email, or address_line.';

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261019102100',
  'delete_account_storage',
  array['docs/staging_apply_L_1019.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
