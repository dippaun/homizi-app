-- Map coordinates, payments, agreements, identity checks, and service leads.
begin;
select no_plan();

select tests.create_supabase_user('d_host', 'd_host@example.test', '+910000000081');
select tests.create_supabase_user('d_tenant', 'd_tenant@example.test', '+910000000082');
select tests.create_supabase_user('d_stranger', 'd_stranger@example.test');
select tests.create_supabase_user('d_staff', 'd_staff@example.test');

select tests.authenticate_as('d_host');
set local role authenticated;

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr,
  approx_latitude, approx_longitude
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01',
  auth.uid(),
  'Map flat',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  22000,
  12.935812,
  77.625104
);

select is(
  (
    select approx_latitude::text
    from public.properties
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01'
  ),
  '12.936',
  'a public coordinate snaps to 3 decimals'
);

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01', 'd/0.slot', 0, 'living'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01', 'd/1.slot', 1, 'bedroom'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01', 'd/2.slot', 2, 'kitchen');

select is(
  (public.publish_listing('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01') ->> 'ok'),
  'true',
  'the map listing can be published'
);

insert into public.property_private_details (
  property_id, address_line, landmark, latitude, longitude
) values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01',
  '12 Demo Cross, Koramangala',
  'Near the park',
  12.935812,
  77.625104
);

reset role;

insert into public.matches (id, participant_a, participant_b)
select
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb01',
  least(tests.get_supabase_uid('d_host'), tests.get_supabase_uid('d_tenant')),
  greatest(tests.get_supabase_uid('d_host'), tests.get_supabase_uid('d_tenant'));

insert into public.visit_requests (id, match_id, requester_id, proposed_slots)
values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccc01',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb01',
  tests.get_supabase_uid('d_tenant'),
  '[{"starts_at":"2026-11-02T10:00:00Z"}]'::jsonb
);

insert into public.staff_roles (user_id)
values (tests.get_supabase_uid('d_staff'));

select tests.authenticate_as('d_tenant');
set local role authenticated;

select is(
  (public.get_precise_address('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01') ->> 'revealed'),
  'false',
  'a tenant does not see the exact point before the visit is agreed'
);
select is(
  (public.get_precise_address('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01') ? 'latitude'),
  false,
  'the hidden payload does not include latitude'
);
select is(
  (public.get_precise_address('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01') ? 'longitude'),
  false,
  'the hidden payload does not include longitude'
);

select throws_ok(
  $$insert into public.payments (user_id, amount_inr)
    values (auth.uid(), 100)$$,
  '42501',
  NULL,
  'a client still cannot insert a payment'
);

select is(
  (
    public.create_demo_payment(
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb01',
      'rent',
      22000,
      'October 2026'
    ) -> 'payment' ->> 'status'
  ),
  'pending',
  'a demo payment starts pending'
);

select is(
  (
    public.complete_demo_payment(
      (
        select id from public.payments
        where user_id = tests.get_supabase_uid('d_tenant')
        order by created_at desc
        limit 1
      ),
      true
    ) -> 'payment' ->> 'status'
  ),
  'succeeded',
  'a demo payment can be marked succeeded'
);

select tests.authenticate_as('d_stranger');
set local role authenticated;

select is(
  (
    public.create_demo_payment(
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb01',
      'rent',
      1000,
      null
    ) ->> 'error'
  ),
  'not_participant',
  'a stranger cannot pay on someone else''s match'
);

select is(
  (select count(*) from public.payments),
  0::bigint,
  'a stranger cannot read the payment'
);

reset role;
update public.visit_requests
set status = 'accepted'
where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccc01';

select tests.authenticate_as('d_tenant');
set local role authenticated;

select is(
  (public.get_precise_address('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01') ->> 'revealed'),
  'true',
  'an agreed visit reveals the street line'
);
select ok(
  (public.get_precise_address('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01') ->> 'latitude')
    like '12.935%',
  'an agreed visit includes the exact latitude'
);
select is(
  (public.get_precise_address('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01') ? 'phone'),
  false,
  'the revealed address still has no phone'
);

select is(
  (public.record_kyc_consent('pan') -> 'verification' ->> 'verification_status'),
  'consent_given',
  'consent is recorded without marking the user verified'
);

select throws_ok(
  $$select public.apply_verification_result(
      auth.uid(), 'verified', 'demo', 'demo-kyc', '4821', 'pan'
    )$$,
  '42501',
  NULL,
  'a signed-in user cannot mark a verification verified'
);

update public.identity_verifications
set verification_status = 'verified', masked_last4 = '4821'
where user_id = auth.uid();

select is(
  (
    select verification_status
    from public.identity_verifications
    where user_id = tests.get_supabase_uid('d_tenant')
  ),
  'consent_given',
  'a direct client update does not verify the row'
);

reset role;

select throws_ok(
  $$select public.apply_verification_result(
      tests.get_supabase_uid('d_tenant'),
      'verified',
      'demo',
      '123456789012',
      '9012',
      'pan'
    )$$,
  '22023',
  NULL,
  'a 12-digit reference is refused'
);

select is(
  (
    public.apply_verification_result(
      tests.get_supabase_uid('d_tenant'),
      'verified',
      'demo',
      'demo-kyc',
      '4821',
      'pan'
    ) -> 'verification' ->> 'verification_status'
  ),
  'verified',
  'the server role can record a verified sandbox result'
);

select is(
  public.push_allowed(tests.get_supabase_uid('d_tenant'), 'match'),
  true,
  'a match may be pushed when no preference row exists'
);
select is(
  public.push_allowed(tests.get_supabase_uid('d_tenant'), 'billing'),
  false,
  'an unknown notification type is not pushed'
);

insert into public.notification_preferences (user_id, matches, visits, chat)
values (tests.get_supabase_uid('d_tenant'), false, true, true);

select is(
  public.push_allowed(tests.get_supabase_uid('d_tenant'), 'match'),
  false,
  'a turned-off matches preference blocks push'
);
select is(
  public.push_allowed(tests.get_supabase_uid('d_tenant'), 'message'),
  true,
  'chat stays pushable when that switch is on'
);

select tests.authenticate_as('d_tenant');
set local role authenticated;

insert into public.service_leads (
  user_id, service_kind, from_locality, city, requested_on, contact_consent, notes
) values (
  auth.uid(),
  'cleaning',
  'Koramangala',
  'Bengaluru',
  date '2026-11-20',
  true,
  'After 10 in the morning'
);

select throws_ok(
  $$insert into public.service_leads (
      user_id, service_kind, from_locality, city, requested_on, contact_consent, notes
    ) values (
      auth.uid(), 'plumbing', 'Koramangala', 'Bengaluru', date '2026-11-21', true,
      'Call 9876543210'
    )$$,
  '23514',
  NULL,
  'a lead note cannot contain a 10-digit number'
);

select tests.authenticate_as('d_stranger');
set local role authenticated;

select is(
  (select count(*) from public.service_leads),
  0::bigint,
  'another user cannot read the lead'
);

select tests.authenticate_as('d_staff');
set local role authenticated;

select is(
  (select count(*) from public.service_leads),
  1::bigint,
  'staff can read the lead'
);

update public.service_leads set status = 'contacted';

select tests.authenticate_as('d_tenant');
set local role authenticated;

select is(
  (select status from public.service_leads),
  'contacted',
  'the requester can see the staff status'
);

select is(
  (
    public.create_agreement(
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb01',
      'Koramangala leave and licence',
      'Rent is described in the draft. No identity number is included.',
      500,
      null
    ) -> 'agreement' ->> 'status'
  ),
  'draft',
  'a match participant can draft an agreement'
);

select is(
  (
    public.demo_sign_agreement(
      (
        select id from public.agreements
        where created_by = tests.get_supabase_uid('d_tenant')
        limit 1
      ),
      'tenant'
    ) ->> 'error'
  ),
  'status',
  'a demo signature waits until the draft is sent'
);

select * from finish();
rollback;
