-- Live seekers for a host's Matches tab.
-- Not applied from this change. The owner applies it.
--
-- tenant_preferences and roommate_profiles are readable only by their owner.
-- This definer returns the public preference fields a host needs to score a
-- seeker. Phone, email, and street address are not selected.

create or replace function public.host_live_seekers()
returns table (
  user_id uuid,
  display_name text,
  occupation text,
  avatar_path text,
  city text,
  localities text[],
  budget_min_inr integer,
  budget_max_inr integer,
  property_types text[],
  room_type text[],
  move_in_date date
)
language sql
stable
security definer
set search_path = public
as $$
  select distinct on (u.id)
    u.id,
    pr.display_name,
    pr.occupation,
    pr.avatar_path,
    coalesce(r.city, tp.city, ''),
    coalesce(r.localities, tp.localities, '{}'::text[]),
    coalesce(r.budget_min_inr, tp.budget_min_inr),
    coalesce(r.budget_max_inr, tp.budget_max_inr),
    coalesce(r.property_types::text[], tp.property_types::text[], '{}'::text[]),
    coalesce(r.room_type, tp.room_type, '{}'::text[]),
    coalesce(r.move_in_date, tp.move_in_date)
  from public.users u
  left join public.profiles pr on pr.user_id = u.id
  left join public.listing_requirements r
    on r.user_id = u.id
   and r.status = 'published'
   and r.discoverable
  left join public.tenant_preferences tp on tp.user_id = u.id
  left join public.roommate_profiles rp
    on rp.user_id = u.id
   and rp.discoverable
  where u.id <> auth.uid()
    and u.status = 'active'
    and (
      r.id is not null
      or rp.user_id is not null
      or (
        tp.user_id is not null
        and (
          nullif(btrim(coalesce(tp.city, '')), '') is not null
          or tp.budget_min_inr is not null
          or tp.budget_max_inr is not null
        )
      )
    )
  order by u.id;
$$;

revoke all on function public.host_live_seekers() from public, anon;
grant execute on function public.host_live_seekers() to authenticated;

comment on function public.host_live_seekers() is
  'Public preference rows for seekers a host can score. No phone, email, or street address.';
