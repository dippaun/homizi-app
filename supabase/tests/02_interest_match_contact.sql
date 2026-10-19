-- Interest, atomic match, and contact gate. Includes leakage checks.
begin;
select no_plan();

select tests.create_supabase_user('tenant_a', 'gate_tenant@example.test', '+910000000031');
select tests.create_supabase_user('host_b', 'gate_host@example.test', '+910000000032');
select tests.create_supabase_user('stranger_c', 'gate_stranger@example.test');

select tests.authenticate_as('tenant_a');
set local role authenticated;

insert into public.listing_requirements (
  id, user_id, city, localities, budget_min_inr, budget_max_inr
) values (
  '55555555-5555-4555-8555-555555555501',
  tests.get_supabase_uid('tenant_a'),
  'Bengaluru',
  array['Koramangala'],
  10000,
  30000
);

select is(
  (public.publish_requirement('55555555-5555-4555-8555-555555555501'::uuid) ->> 'ok')::boolean,
  true,
  'tenant can publish a requirement'
);

reset role;
select tests.authenticate_as('host_b');
set local role authenticated;

update public.private_contacts
set phone = '+910000000032', email = 'gate_host@example.test'
where user_id = auth.uid();

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr
) values (
  '55555555-5555-4555-8555-555555555502',
  tests.get_supabase_uid('host_b'),
  'Gate test flat',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  20000
);

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('55555555-5555-4555-8555-555555555502', 'gate/1.jpg', 0, 'living'),
  ('55555555-5555-4555-8555-555555555502', 'gate/2.jpg', 1, 'bedroom'),
  ('55555555-5555-4555-8555-555555555502', 'gate/3.jpg', 2, 'kitchen');

select ok(
  (public.publish_listing('55555555-5555-4555-8555-555555555502'::uuid) ->> 'ok')::boolean,
  'host publishes the gate listing'
);

select is(
  (public.create_interest('property', '55555555-5555-4555-8555-555555555502', 'like') ->> 'error'),
  'self',
  'host cannot like their own listing'
);

reset role;
select tests.authenticate_as('tenant_a');
set local role authenticated;

select is(
  (public.create_interest('property', '55555555-5555-4555-8555-555555555502', 'like') -> 'match' ->> 'error'),
  'no_reciprocal',
  'one-sided like does not create a match'
);

select is(
  (public.create_mutual_match(tests.get_supabase_uid('host_b')) ->> 'error'),
  'no_reciprocal',
  'create_mutual_match refuses a one-sided like'
);

select is(
  (
    public.create_interest('property', '55555555-5555-4555-8555-555555555502', 'like') ->> 'idempotent'
  )::boolean,
  true,
  'repeating the same like is idempotent'
);

reset role;
select tests.authenticate_as('host_b');
set local role authenticated;

select ok(
  (
    public.create_interest(
      'listing_requirement',
      '55555555-5555-4555-8555-555555555501',
      'like'
    ) -> 'match' ->> 'match_id'
  ) is not null,
  'reciprocal likes create one match'
);

reset role;
create table tests.captured (
  key text primary key,
  value uuid
);
grant select on tests.captured to authenticated;
insert into tests.captured (key, value)
select 'gate_match', id
from public.matches
where participant_a = least(tests.get_supabase_uid('tenant_a'), tests.get_supabase_uid('host_b'))
  and participant_b = greatest(tests.get_supabase_uid('tenant_a'), tests.get_supabase_uid('host_b'));
select tests.authenticate_as('host_b');
set local role authenticated;

select is(
  (
    select count(*)
    from public.matches
    where id = (select value from tests.captured where key = 'gate_match')
  ),
  1::bigint,
  'only one match row exists for the pair'
);

select is(
  (
    public.create_mutual_match(tests.get_supabase_uid('tenant_a')) ->> 'idempotent'
  )::boolean,
  true,
  'create_mutual_match is idempotent'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('tenant_a');
set local role authenticated;

select ok(
  (public.get_contact_visibility(
    (select value from tests.captured where key = 'gate_match')
  ) ->> 'phone') is null,
  'phone is withheld before consent'
);
select is(
  (public.get_contact_visibility(
    (select value from tests.captured where key = 'gate_match')
  ) ->> 'reason'),
  'consent_required',
  'reason is consent_required'
);

reset role;
select tests.authenticate_as('host_b');
set local role authenticated;

select ok(
  (
    public.grant_contact_consent(
      (select value from tests.captured where key = 'gate_match'),
      'phone'
    ) ->> 'ok'
  )::boolean,
  'host can consent to share a phone'
);

reset role;
select tests.authenticate_as('tenant_a');
set local role authenticated;

select is(
  public.get_contact_visibility((select value from tests.captured where key = 'gate_match')) ->> 'phone',
  '+910000000032',
  'phone is returned after consent'
);
select ok(
  (public.get_contact_visibility((select value from tests.captured where key = 'gate_match')) ->> 'email') is null,
  'email stays hidden when the scope is phone only'
);

reset role;
select tests.authenticate_as('stranger_c');
set local role authenticated;

select ok(
  (public.get_contact_visibility((select value from tests.captured where key = 'gate_match')) ->> 'phone') is null,
  'a stranger cannot read the consented phone'
);
select is(
  (public.get_contact_visibility((select value from tests.captured where key = 'gate_match')) ->> 'reason'),
  'not_found',
  'strangers are not told the match exists'
);

reset role;
select tests.authenticate_as('host_b');
set local role authenticated;

select public.revoke_contact_consent((select value from tests.captured where key = 'gate_match'));

reset role;
select tests.authenticate_as('tenant_a');
set local role authenticated;

select ok(
  (public.get_contact_visibility((select value from tests.captured where key = 'gate_match')) ->> 'phone') is null,
  'revoked consent hides the phone again'
);

insert into public.blocks (blocker_id, blocked_user_id)
values (auth.uid(), tests.get_supabase_uid('host_b'));

reset role;
select tests.authenticate_as('host_b');
set local role authenticated;

select public.grant_contact_consent((select value from tests.captured where key = 'gate_match'), 'phone_and_email');

reset role;
select tests.authenticate_as('tenant_a');
set local role authenticated;

select is(
  public.get_contact_visibility((select value from tests.captured where key = 'gate_match')) ->> 'reason',
  'blocked',
  'a block hides contact even if consent exists'
);
select is(
  (public.create_interest('user', tests.get_supabase_uid('host_b'), 'like') ->> 'error'),
  'blocked',
  'a block rejects a new interest'
);

select ok(
  (
    select bool_and(c.relrowsecurity)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  ),
  'every public table has row level security'
);

select * from finish();
rollback;
