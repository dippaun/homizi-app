-- Lifestyle answers for Find Your Roomie.
-- Stored apart from roommate_profiles so the existing table select grant
-- cannot return smoking, drinking, food, guests, cooking, or the note.
-- A viewer reads a row only when it is their own, or they are verified and premium.

alter table public.profiles
  add column if not exists is_premium boolean not null default false;

comment on column public.profiles.is_premium is
  'Premium plan. Demo mode treats the signed-in viewer as premium. Lifestyle details stay hidden until the viewer is verified and premium.';

create table if not exists public.roommate_lifestyle (
  user_id uuid primary key references public.users (id) on delete cascade,
  smoking text,
  drinking text,
  food text,
  guests text,
  cooking text,
  note text not null default '',
  updated_at timestamptz not null default now()
);

do $roomie_lifestyle_checks$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'roommate_lifestyle_smoking'
  ) then
    alter table public.roommate_lifestyle
      add constraint roommate_lifestyle_smoking
      check (smoking is null or smoking in ('yes', 'no', 'undisclosed'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'roommate_lifestyle_drinking'
  ) then
    alter table public.roommate_lifestyle
      add constraint roommate_lifestyle_drinking
      check (drinking is null or drinking in ('yes', 'no', 'undisclosed'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'roommate_lifestyle_food'
  ) then
    alter table public.roommate_lifestyle
      add constraint roommate_lifestyle_food
      check (
        food is null
        or food in ('vegetarian', 'non_vegetarian', 'both', 'undisclosed')
      );
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'roommate_lifestyle_guests'
  ) then
    alter table public.roommate_lifestyle
      add constraint roommate_lifestyle_guests
      check (
        guests is null or guests in ('frequently', 'occasionally', 'rarely')
      );
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'roommate_lifestyle_cooking'
  ) then
    alter table public.roommate_lifestyle
      add constraint roommate_lifestyle_cooking
      check (
        cooking is null or cooking in ('cook_myself', 'shared', 'prefer_not')
      );
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'roommate_lifestyle_note'
  ) then
    alter table public.roommate_lifestyle
      add constraint roommate_lifestyle_note
      check (char_length(note) <= 200);
  end if;
end
$roomie_lifestyle_checks$;

comment on table public.roommate_lifestyle is
  'Lifestyle answers. Readable by the owner, or by a viewer who is verified and premium.';

comment on column public.roommate_lifestyle.note is
  'Optional other lifestyle preferences. At most 200 characters.';

drop trigger if exists roommate_lifestyle_set_updated_at on public.roommate_lifestyle;
create trigger roommate_lifestyle_set_updated_at
  before update on public.roommate_lifestyle
  for each row execute function public.set_updated_at();

create or replace function public.viewer_is_verified(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.user_id = p_user
      and p.verification_status = 'mock_verified'
  )
  or exists (
    select 1
    from public.identity_verifications iv
    where iv.user_id = p_user
      and (
        iv.aadhaar_status = 'verified'
        or iv.face_status = 'verified'
      )
  );
$$;

create or replace function public.viewer_can_read_lifestyle()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and coalesce(
      (select pr.is_premium from public.profiles pr where pr.user_id = auth.uid()),
      false
    )
    and public.viewer_is_verified(auth.uid());
$$;

create or replace function public.roommate_lifestyle(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.roommate_lifestyle;
  v_visible boolean;
begin
  if v_uid is null or p_user is null then
    return jsonb_build_object('visible', false);
  end if;
  v_visible := v_uid = p_user or public.viewer_can_read_lifestyle();
  if not v_visible then
    return jsonb_build_object('visible', false);
  end if;
  select * into v_row
  from public.roommate_lifestyle
  where user_id = p_user;
  if not found then
    return jsonb_build_object('visible', true);
  end if;
  return jsonb_build_object(
    'visible', true,
    'smoking', v_row.smoking,
    'drinking', v_row.drinking,
    'food', v_row.food,
    'guests', v_row.guests,
    'cooking', v_row.cooking,
    'note', v_row.note
  );
end;
$$;

revoke all on function public.viewer_is_verified(uuid) from public, anon, authenticated;
revoke all on function public.viewer_can_read_lifestyle() from public, anon;
grant execute on function public.viewer_can_read_lifestyle() to authenticated;
revoke all on function public.roommate_lifestyle(uuid) from public, anon;
grant execute on function public.roommate_lifestyle(uuid) to authenticated;

alter table public.roommate_lifestyle enable row level security;

drop policy if exists roommate_lifestyle_select on public.roommate_lifestyle;
create policy roommate_lifestyle_select on public.roommate_lifestyle
  for select to authenticated
  using (user_id = auth.uid() or public.viewer_can_read_lifestyle());

drop policy if exists roommate_lifestyle_insert on public.roommate_lifestyle;
create policy roommate_lifestyle_insert on public.roommate_lifestyle
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists roommate_lifestyle_update on public.roommate_lifestyle;
create policy roommate_lifestyle_update on public.roommate_lifestyle
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.roommate_lifestyle from public, anon;
grant select, insert, update on public.roommate_lifestyle to authenticated;
