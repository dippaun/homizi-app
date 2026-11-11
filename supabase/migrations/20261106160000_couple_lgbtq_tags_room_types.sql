-- Couple / LGBTQ+ friendly tags use property_features (tag:*).
-- Separate-room-in-flat listing types extend the property_type enum.
-- Do not apply to staging from the agent; ship the file only.

alter type public.property_type add value if not exists 'room_in_2bhk';
alter type public.property_type add value if not exists 'room_in_3bhk';
alter type public.property_type add value if not exists 'room_in_4bhk';

comment on type public.property_type is
  'Homizi listing kinds. room_in_* is one separate room inside a shared 2/3/4 BHK flat.';
