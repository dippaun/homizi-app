-- Paste after ADVISOR. Adds room_in_* property types for separate rooms in a flat.
-- Couple / LGBTQ+ friendly tags use property_features (tag:*); no column change.
-- Do not apply from the app or CI; paste in the Supabase SQL editor when ready.

-- Couple / LGBTQ+ friendly tags use property_features (tag:*).
-- Separate-room-in-flat listing types extend the property_type enum.
-- Do not apply to staging from the agent; ship the file only.

alter type public.property_type add value if not exists 'room_in_2bhk';
alter type public.property_type add value if not exists 'room_in_3bhk';
alter type public.property_type add value if not exists 'room_in_4bhk';

comment on type public.property_type is
  'Homizi listing kinds. room_in_* is one separate room inside a shared 2/3/4 BHK flat.';

insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261106160000',
  'couple_lgbtq_tags_room_types',
  array['docs/staging_apply_TAGS_1106.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
