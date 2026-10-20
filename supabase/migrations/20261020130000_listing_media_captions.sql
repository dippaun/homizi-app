-- Optional captions on listing photos.
-- Video is not added. The private listing-photos bucket stays at 5 MB and
-- JPEG, PNG, and WebP. A 20 MB MP4 would need a larger object limit or
-- another bucket, and the app has no video player dependency.
-- Clients still cannot write moderation_status. A blank caption is stored
-- as null so the gallery can fall back to the room type.

create or replace function public.listing_caption_issue(p_caption text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_text text := btrim(coalesce(p_caption, ''));
  v_collapsed text;
begin
  if v_text = '' then
    return null;
  end if;
  if char_length(v_text) > 80 then
    return 'Keep the caption to 80 characters.';
  end if;
  if v_text ~* '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}' then
    return 'A caption cannot include an email.';
  end if;
  v_collapsed := v_text;
  while v_collapsed ~ '\d[\s.\-]+\d' loop
    v_collapsed := regexp_replace(v_collapsed, '(\d)[\s.\-]+(\d)', '\1\2', 'g');
  end loop;
  if v_collapsed ~ '\d{10,}' then
    return 'A caption cannot include a phone number.';
  end if;
  return null;
end;
$$;

revoke all on function public.listing_caption_issue(text) from public, anon;
grant execute on function public.listing_caption_issue(text) to authenticated, service_role;

comment on function public.listing_caption_issue(text) is
  'Null when a photo caption is empty or safe. Otherwise a short refusal. No phone number or email.';

create or replace function public.property_photos_guard_caption()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_issue text;
begin
  if NEW.caption is null then
    return NEW;
  end if;
  NEW.caption := btrim(NEW.caption);
  if NEW.caption = '' then
    NEW.caption := null;
    return NEW;
  end if;
  v_issue := public.listing_caption_issue(NEW.caption);
  if v_issue is not null then
    raise exception '%', v_issue
      using errcode = '22023';
  end if;
  return NEW;
end;
$$;

revoke all on function public.property_photos_guard_caption() from public, anon;
grant execute on function public.property_photos_guard_caption() to authenticated, service_role;

comment on function public.property_photos_guard_caption() is
  'Trims a photo caption, stores a blank as null, and refuses a phone number or email.';

alter table public.property_photos
  add column if not exists caption text;

comment on column public.property_photos.caption is
  'Optional gallery description, at most 80 characters. No phone number or email. Null means the room type is the label.';

alter table public.property_photos
  drop constraint if exists property_photos_caption_ok;

alter table public.property_photos
  add constraint property_photos_caption_ok
  check (public.listing_caption_issue(caption) is null);

drop trigger if exists property_photos_guard_caption on public.property_photos;

create trigger property_photos_guard_caption
  before insert or update of caption on public.property_photos
  for each row
  execute function public.property_photos_guard_caption();

grant insert (caption), update (caption)
  on public.property_photos to authenticated;
