-- Not applied by the app. Adds a city-scoped roommate list.
-- The deck already drops other cities on the device. After this is applied,
-- the server returns only the requested city, including a 0% score.

create or replace function public.list_roommate_seekers_in_city(p_city text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(item), '[]'::jsonb)
  from jsonb_array_elements(public.list_roommate_seekers()) as item
  where lower(btrim(coalesce(item->>'city', ''))) = lower(btrim(coalesce(p_city, '')))
    and btrim(coalesce(p_city, '')) <> '';
$$;

revoke all on function public.list_roommate_seekers_in_city(text) from public, anon;
grant execute on function public.list_roommate_seekers_in_city(text) to authenticated;

comment on function public.list_roommate_seekers_in_city(text) is
  'Roommate profiles in one city only. An empty city returns none.';
