-- Profile-to-profile chat on the existing conversations and messages tables.
-- Not applied to a hosted project from this change. The owner applies it.
--
-- conversations already exist for matches (match_id was required). This makes
-- match_id optional, stores last_message_at and an optional listing_id, and
-- adds conversation_members so two profiles can talk without a match row.
-- messages gains read_at. The contact check on messages.body is unchanged, so
-- a phone number or an email is still refused.
--
-- Realtime for public.messages is confirmed again. It was first added in
-- 20261016183000_realtime_moderation_analytics.sql.

alter table public.conversations
  alter column match_id drop not null;

alter table public.conversations
  add column if not exists last_message_at timestamptz;

alter table public.conversations
  add column if not exists listing_id uuid references public.properties (id) on delete set null;

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

alter table public.messages
  add column if not exists read_at timestamptz;

create index if not exists conversation_members_user_idx
  on public.conversation_members (user_id);

create index if not exists conversations_last_message_idx
  on public.conversations (last_message_at desc);

insert into public.conversation_members (conversation_id, user_id)
select c.id, m.participant_a
from public.conversations c
join public.matches m on m.id = c.match_id
on conflict do nothing;

insert into public.conversation_members (conversation_id, user_id)
select c.id, m.participant_b
from public.conversations c
join public.matches m on m.id = c.match_id
on conflict do nothing;

update public.conversations c
set last_message_at = sub.last_at
from (
  select conversation_id, max(created_at) as last_at
  from public.messages
  group by conversation_id
) sub
where c.id = sub.conversation_id
  and c.last_message_at is null;

-- ---------------------------------------------------------------------------
-- Membership check used by RLS. Security definer so policies do not recurse
-- into conversation_members.
-- ---------------------------------------------------------------------------

create or replace function public.is_conversation_member(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_members
    where conversation_id = p_conversation_id
      and user_id = auth.uid()
  );
$$;

revoke all on function public.is_conversation_member(uuid) from public, anon;
grant execute on function public.is_conversation_member(uuid) to authenticated;

alter table public.conversation_members enable row level security;

drop policy if exists conversation_members_select_participant
  on public.conversation_members;
create policy conversation_members_select_participant
  on public.conversation_members
  for select to authenticated
  using (public.is_conversation_member(conversation_id));

drop policy if exists conversations_select_direct_member on public.conversations;
create policy conversations_select_direct_member
  on public.conversations
  for select to authenticated
  using (public.is_conversation_member(id));

drop policy if exists messages_select_direct_member on public.messages;
create policy messages_select_direct_member
  on public.messages
  for select to authenticated
  using (public.is_conversation_member(conversation_id));

drop policy if exists messages_insert_direct_member on public.messages;
create policy messages_insert_direct_member
  on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_conversation_member(conversation_id)
    and not exists (
      select 1
      from public.conversation_members other
      where other.conversation_id = messages.conversation_id
        and other.user_id <> auth.uid()
        and public.is_blocked_with(other.user_id)
    )
  );

grant select on public.conversation_members to authenticated;

-- ---------------------------------------------------------------------------
-- One direct thread per pair. listing is stored when it is a real property.
-- A match conversation is left as it is; this only creates match_id-null rows.
-- ---------------------------------------------------------------------------

create or replace function public.get_or_create_direct_conversation(
  other_user uuid,
  listing uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_listing uuid;
begin
  if v_uid is null then
    raise exception 'unauthenticated' using errcode = '28000';
  end if;
  if other_user is null or other_user = v_uid then
    raise exception 'invalid user' using errcode = '22023';
  end if;
  if not exists (
    select 1
    from public.users
    where id = other_user
      and status = 'active'
  ) then
    raise exception 'invalid user' using errcode = '22023';
  end if;
  if public.is_blocked_with(other_user) then
    raise exception 'blocked' using errcode = '42501';
  end if;

  v_listing := null;
  if listing is not null and exists (
    select 1 from public.properties where id = listing
  ) then
    v_listing := listing;
  end if;

  perform pg_advisory_xact_lock(
    hashtext(least(v_uid::text, other_user::text)),
    hashtext(greatest(v_uid::text, other_user::text))
  );

  select c.id
  into v_id
  from public.conversations c
  where c.match_id is null
    and public.is_conversation_member(c.id)
    and exists (
      select 1
      from public.conversation_members m
      where m.conversation_id = c.id
        and m.user_id = other_user
    )
    and (
      select count(*)
      from public.conversation_members m
      where m.conversation_id = c.id
    ) = 2
  order by c.created_at
  limit 1;

  if v_id is not null then
    if v_listing is not null then
      update public.conversations
      set listing_id = coalesce(listing_id, v_listing)
      where id = v_id
        and listing_id is null;
    end if;
    return v_id;
  end if;

  insert into public.conversations (listing_id, last_message_at)
  values (v_listing, now())
  returning id into v_id;

  insert into public.conversation_members (conversation_id, user_id)
  values (v_id, v_uid), (v_id, other_user);

  return v_id;
end;
$$;

revoke all on function public.get_or_create_direct_conversation(uuid, uuid) from public, anon;
grant execute on function public.get_or_create_direct_conversation(uuid, uuid) to authenticated;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'unauthenticated' using errcode = '28000';
  end if;
  if not public.is_conversation_member(p_conversation_id) then
    raise exception 'not_participant' using errcode = '42501';
  end if;
  update public.messages
  set read_at = now()
  where conversation_id = p_conversation_id
    and sender_id <> v_uid
    and read_at is null;
end;
$$;

revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

create or replace function public.touch_conversation_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set last_message_at = new.created_at,
      updated_at = now()
  where id = new.conversation_id;
  return new;
end;
$$;

revoke all on function public.touch_conversation_on_message() from public, anon;

drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation
  after insert on public.messages
  for each row
  execute function public.touch_conversation_on_message();

alter table public.messages replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    raise notice 'supabase_realtime publication missing; chat realtime skipped';
    return;
  end if;
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
exception
  when insufficient_privilege then
    raise notice 'realtime publication update skipped: %', sqlerrm;
end $$;

comment on table public.conversation_members is
  'Profiles in a conversation. Direct threads have two rows and a null match_id.';

comment on function public.get_or_create_direct_conversation(uuid, uuid) is
  'Returns the direct conversation for the signed-in user and other_user. listing is kept when it is a property id.';
