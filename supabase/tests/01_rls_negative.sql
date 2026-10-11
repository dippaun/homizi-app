-- Negative authorization: cross-user reads and writes must fail.
begin;
select no_plan();

select tests.create_supabase_user('tenant_a', 'tenant_a@example.test', '+910000000011');
select tests.create_supabase_user('host_b', 'host_b@example.test', '+910000000022');
select tests.create_supabase_user('stranger_c', 'stranger_c@example.test');

select tests.authenticate_as('host_b');
set local role authenticated;

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr
) values (
  '44444444-4444-4444-8444-444444444401',
  tests.get_supabase_uid('host_b'),
  'Published test flat',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  21000
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr
) values (
  '44444444-4444-4444-8444-444444444402',
  tests.get_supabase_uid('host_b'),
  'Secret draft',
  'Indiranagar',
  'Bengaluru',
  'studio',
  'furnished',
  30000
);

insert into public.property_private_details (property_id, address_line)
values ('44444444-4444-4444-8444-444444444401', '99 Fictional Cross');

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('44444444-4444-4444-8444-444444444401', 'test/1.jpg', 0, 'living'),
  ('44444444-4444-4444-8444-444444444401', 'test/2.jpg', 1, 'bedroom'),
  ('44444444-4444-4444-8444-444444444401', 'test/3.jpg', 2, 'kitchen');

select ok(
  (public.publish_listing('44444444-4444-4444-8444-444444444401'::uuid) ->> 'ok')::boolean,
  'host can publish a complete listing'
);

select is(
  (public.publish_listing('44444444-4444-4444-8444-444444444402'::uuid) ->> 'error'),
  'photos',
  'draft without three photos cannot be published'
);

reset role;
select tests.authenticate_as('tenant_a');
set local role authenticated;

select is(
  (
    select count(*) from public.private_contacts
    where user_id = tests.get_supabase_uid('host_b')
  ),
  0::bigint,
  'tenant cannot read the host private contact row'
);

select is(
  (
    select count(*) from public.property_private_details
    where property_id = '44444444-4444-4444-8444-444444444401'
  ),
  0::bigint,
  'tenant cannot read the street address'
);

select is(
  (
    select count(*) from public.properties
    where id = '44444444-4444-4444-8444-444444444402'
  ),
  0::bigint,
  'tenant cannot read a draft listing'
);

select is(
  (
    select title from public.properties
    where id = '44444444-4444-4444-8444-444444444401'
  ),
  'Published test flat',
  'tenant can read a published listing'
);

reset role;
select has_column(
  'public',
  'properties',
  'locality',
  'locality is on the public listing'
);
select hasnt_column(
  'public',
  'properties',
  'address_line',
  'street address is not a listing column'
);
select tests.authenticate_as('tenant_a');
set local role authenticated;

update public.profiles
set display_name = 'hacked'
where user_id = tests.get_supabase_uid('host_b');

select is(
  (select display_name from public.profiles where user_id = tests.get_supabase_uid('host_b')),
  '',
  'tenant cannot rename the host profile'
);

select throws_ok(
  $$update public.profiles set verification_status = 'mock_verified' where user_id = auth.uid()$$,
  '42501',
  'permission denied for table profiles',
  'client cannot set verification status'
);

select throws_ok(
  $$insert into public.interests (actor_user_id, target_type, target_id, action)
    values (auth.uid(), 'property', '44444444-4444-4444-8444-444444444401', 'like')$$,
  '42501'
);

select throws_ok(
  $$insert into public.matches (participant_a, participant_b)
    values ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002')$$,
  '42501'
);

select throws_ok(
  $$insert into public.payments (user_id, amount_inr) values (auth.uid(), 100)$$,
  '42501'
);

select throws_ok(
  $$update public.properties set status = 'published' where id = '44444444-4444-4444-8444-444444444402'$$,
  '42501'
);

select throws_ok(
  $$insert into public.blocks (blocker_id, blocked_user_id)
    values (tests.get_supabase_uid('host_b'), auth.uid())$$,
  '42501'
);

select throws_ok(
  $$select * from public.audit_events$$,
  '42501'
);

reset role;
select tests.clear_authentication();
set local role anon;

select throws_ok(
  $$select * from public.properties$$,
  '42501'
);

select throws_ok(
  $$select public.get_contact_visibility('33333333-3333-4333-8333-333333333301'::uuid)$$,
  '42501'
);

select * from finish();
rollback;
