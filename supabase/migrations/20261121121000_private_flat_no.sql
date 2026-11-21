-- NOT APPLIED. House or flat number stays off public listings.
--
-- property_private_details is readable only by the listing's owner.
-- public.public_listings() does not return this column.
-- public.get_precise_address() does not return this column, so a visitor
-- never sees the flat number even after a visit is accepted.

alter table public.property_private_details
  add column if not exists flat_no text;

comment on column public.property_private_details.flat_no is
  'House or flat number. Owner only. Never copied onto a public listing or profile.';
