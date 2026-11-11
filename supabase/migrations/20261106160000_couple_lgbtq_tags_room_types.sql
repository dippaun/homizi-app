-- Couple / LGBTQ+ friendly tags use property_features (tag:*).
-- Separate-room-in-flat listing types extend the property_type enum.
-- Already applied on staging: property_type has room_in_2bhk, room_in_3bhk,
-- and room_in_4bhk. Ship the file for the docs test. Do not paste or run it
-- again from an agent.

alter type public.property_type add value if not exists 'room_in_2bhk';
alter type public.property_type add value if not exists 'room_in_3bhk';
alter type public.property_type add value if not exists 'room_in_4bhk';

comment on type public.property_type is
  'Homizi listing kinds. room_in_* is one separate room inside a shared 2/3/4 BHK flat.';
