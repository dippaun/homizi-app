-- NOT APPLIED. One combined change for account data that had no column.
--
-- roommate_profiles.brief stores the full ranked roommate form (order,
-- must-haves, and answers that are not their own columns).
-- tenant_preferences.intake stores the tenant home form (address, type,
-- rooms, pin). Localities and occupancy still use the existing columns.
-- Existing grants on both tables cover the new columns.

alter table public.roommate_profiles
  add column if not exists brief jsonb;

comment on column public.roommate_profiles.brief is
  'Full roommate requirements form. Faith and hometown stay inside this object and are not scored.';

alter table public.tenant_preferences
  add column if not exists intake jsonb;

comment on column public.tenant_preferences.intake is
  'Tenant home form saved on the device and copied here for a signed-in account. Not a public card.';
