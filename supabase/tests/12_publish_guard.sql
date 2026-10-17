-- Direct API publish cannot skip required fields, photos, or room order.
-- A street address stays out of the payload until a visit is accepted.
begin;
select no_plan();

select tests.create_supabase_user(
  'guard_host',
  'guard_host@example.test',
  '+910000000071'
);
select tests.create_supabase_user(
  'guard_tenant',
  'guard_tenant@example.test',
  '+910000000072'
);

select tests.authenticate_as('guard_host');
set local role authenticated;

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr
) values (
  '88888888-8888-4888-8888-888888888801',
  auth.uid(),
  'Incomplete flat',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  22000
);

reset role;
select set_config('request.jwt.claim.role', 'service_role', true);

select throws_ok(
  $$update public.properties
    set status = 'published'
    where id = '88888888-8888-4888-8888-888888888801'$$,
  '23514',
  'listing_incomplete',
  'a direct status update cannot publish a listing with fewer than 3 photos'
);

select throws_ok(
  $$insert into public.properties (
      id, host_user_id, title, locality, city, property_type, furnishing,
      rent_inr, status
    ) values (
      '88888888-8888-4888-8888-888888888809',
      tests.get_supabase_uid('guard_host'),
      'Inserted live',
      'Baner',
      'Pune',
      'apartment',
      'furnished',
      18000,
      'published'
    )$$,
  '23514',
  'listing_incomplete',
  'a direct insert cannot publish a listing without photos'
);

select set_config('request.jwt.claim.role', 'authenticated', true);
select tests.authenticate_as('guard_host');
set local role authenticated;

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('88888888-8888-4888-8888-888888888801', 'guard/0.slot', 0, 'living'),
  ('88888888-8888-4888-8888-888888888801', 'guard/1.slot', 1, 'bedroom'),
  ('88888888-8888-4888-8888-888888888801', 'guard/2.slot', 2, 'kitchen');

reset role;
update public.property_photos
set moderation_status = 'rejected'
where property_id = '88888888-8888-4888-8888-888888888801'
  and sort_order = 1;

select tests.authenticate_as('guard_host');
set local role authenticated;

select is(
  (public.publish_listing('88888888-8888-4888-8888-888888888801') ->> 'error'),
  'photos',
  'a rejected photo does not count toward the minimum of 3'
);

reset role;
update public.property_photos
set moderation_status = 'pending'
where property_id = '88888888-8888-4888-8888-888888888801'
  and sort_order = 1;

select tests.authenticate_as('guard_host');
set local role authenticated;

select is(
  (public.publish_listing('88888888-8888-4888-8888-888888888801') ->> 'ok'),
  'true',
  'publish_listing accepts three room photos in room-first order'
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr
) values (
  '88888888-8888-4888-8888-888888888802',
  auth.uid(),
  'Exterior first',
  'Indiranagar',
  'Bengaluru',
  'apartment',
  'semi_furnished',
  19000
);

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('88888888-8888-4888-8888-888888888802', 'guard/ext.slot', 0, 'exterior'),
  ('88888888-8888-4888-8888-888888888802', 'guard/liv.slot', 1, 'living'),
  ('88888888-8888-4888-8888-888888888802', 'guard/bed.slot', 2, 'bedroom');

select is(
  (public.publish_listing('88888888-8888-4888-8888-888888888802') ->> 'error'),
  'photo_order',
  'publish_listing refuses an exterior photo before the rooms'
);

insert into public.property_private_details (property_id, address_line, landmark)
values (
  '88888888-8888-4888-8888-888888888801',
  '12 Demo Cross, Koramangala',
  'Near the park'
);

select is(
  (public.get_precise_address('88888888-8888-4888-8888-888888888801') ->> 'revealed'),
  'true',
  'the host can read their own street line'
);
select is(
  (public.get_precise_address('88888888-8888-4888-8888-888888888801') ? 'phone'),
  false,
  'the address payload has no phone'
);
select is(
  (public.get_precise_address('88888888-8888-4888-8888-888888888801') ? 'email'),
  false,
  'the address payload has no email'
);

reset role;
select tests.clear_authentication();

insert into public.matches (id, participant_a, participant_b)
select
  '88888888-8888-4888-8888-888888888880',
  least(tests.get_supabase_uid('guard_host'), tests.get_supabase_uid('guard_tenant')),
  greatest(tests.get_supabase_uid('guard_host'), tests.get_supabase_uid('guard_tenant'));

insert into public.visit_requests (id, match_id, requester_id, proposed_slots)
values (
  '88888888-8888-4888-8888-888888888881',
  '88888888-8888-4888-8888-888888888880',
  tests.get_supabase_uid('guard_tenant'),
  '[{"starts_at":"2026-11-02T10:00:00Z"}]'::jsonb
);

select tests.authenticate_as('guard_tenant');
set local role authenticated;

select is(
  (public.get_precise_address('88888888-8888-4888-8888-888888888801') ->> 'revealed'),
  'false',
  'a tenant does not see the street line before the visit is agreed'
);
select is(
  (public.get_precise_address('88888888-8888-4888-8888-888888888801') ? 'address_line'),
  false,
  'the hidden payload does not include address_line'
);
select is(
  (public.get_precise_address('88888888-8888-4888-8888-888888888801') ? 'phone'),
  false,
  'the hidden payload does not include a phone'
);

reset role;
update public.visit_requests
set status = 'accepted'
where id = '88888888-8888-4888-8888-888888888881';

select tests.authenticate_as('guard_tenant');
set local role authenticated;

select is(
  (public.get_precise_address('88888888-8888-4888-8888-888888888801') ->> 'revealed'),
  'true',
  'an accepted visit reveals the street line'
);
select is(
  (public.get_precise_address('88888888-8888-4888-8888-888888888801') ->> 'address_line'),
  '12 Demo Cross, Koramangala',
  'the revealed line is the stored street address'
);
select is(
  (public.get_precise_address('88888888-8888-4888-8888-888888888801') ? 'phone'),
  false,
  'a revealed address still has no phone'
);
select is(
  (public.get_precise_address('88888888-8888-4888-8888-888888888801') ? 'email'),
  false,
  'a revealed address still has no email'
);

select * from finish();
rollback;
