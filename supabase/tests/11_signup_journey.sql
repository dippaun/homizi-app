-- R-050. Synthetic signup through profile, listing, discovery, match,
-- contact consent, and the denied cases around that path.
-- Visit times, address-after-accept, the interest rate limit, and
-- delete_own_account (auth, rows, listing-photos) are included.
begin;
select no_plan();

select tests.create_supabase_user(
  'journey_tenant',
  'journey_tenant@example.test'
);
select tests.create_supabase_user(
  'journey_host',
  'journey_host@example.test'
);
select tests.create_supabase_user(
  'journey_stranger',
  'journey_stranger@example.test'
);
select tests.create_supabase_user(
  'journey_limited',
  'journey_limited@example.test'
);

select tests.authenticate_as('journey_tenant');
set local role authenticated;

update public.profiles
set display_name = 'Journey Tenant',
    occupation = 'Designer',
    public_bio = 'Synthetic profile.'
where user_id = auth.uid();

update public.users
set primary_role = 'tenant'
where id = auth.uid();

insert into public.consent_records (user_id, policy_type, policy_version)
values
  (auth.uid(), 'terms', '2026-10-11-draft'),
  (auth.uid(), 'privacy', '2026-10-11-draft');

select is(
  public.request_mock_verification()::text,
  'mock_pending',
  'verification stays at the test-only mock_pending state'
);

select throws_ok(
  $$update public.profiles set verification_status = 'mock_verified' where user_id = auth.uid()$$,
  '42501',
  'permission denied for table profiles',
  'the client cannot mark a profile verified'
);

select is(
  (select count(*)::int from public.consent_records where user_id = auth.uid()),
  2,
  'terms and privacy consent are stored'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_host');
set local role authenticated;

update public.users set primary_role = 'host' where id = auth.uid();
insert into public.host_profiles (user_id, host_category, company_name)
values (auth.uid(), 'owner', 'Synthetic Homes');

update public.private_contacts
set phone = '+910000000061',
    email = 'journey_host@example.test'
where user_id = auth.uid();

insert into public.properties (
  id, host_user_id, title, locality, city, address_visibility,
  property_type, furnishing, rent_inr
) values (
  '66666666-6666-4666-8666-666666666601',
  auth.uid(),
  'Journey flat',
  'Koramangala',
  'Bengaluru',
  'after_visit_accept',
  'apartment',
  'furnished',
  22000
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr
) values (
  '66666666-6666-4666-8666-666666666602',
  auth.uid(),
  'Journey draft',
  'Indiranagar',
  'Bengaluru',
  'studio',
  'furnished',
  18000
);

insert into public.property_private_details (property_id, address_line)
values (
  '66666666-6666-4666-8666-666666666601',
  '99 Fictional Cross'
);

insert into public.property_photos (property_id, storage_path, sort_order)
values
  ('66666666-6666-4666-8666-666666666601', 'journey/1.jpg', 0),
  ('66666666-6666-4666-8666-666666666601', 'journey/2.jpg', 1),
  ('66666666-6666-4666-8666-666666666601', 'journey/3.jpg', 2);

select ok(
  (public.publish_listing('66666666-6666-4666-8666-666666666601'::uuid) ->> 'ok')::boolean,
  'the host can publish a complete listing'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_stranger');
set local role authenticated;

select is(
  (public.publish_listing('66666666-6666-4666-8666-666666666601'::uuid) ->> 'error'),
  'not_owner',
  'a stranger cannot publish the host listing'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_tenant');
set local role authenticated;

select is(
  (
    select title
    from public.properties
    where id = '66666666-6666-4666-8666-666666666601'
  ),
  'Journey flat',
  'discovery returns the published listing'
);

select is(
  (
    select count(*)::int
    from public.properties
    where id = '66666666-6666-4666-8666-666666666602'
  ),
  0,
  'discovery hides the draft listing'
);

select ok(
  not exists (
    select 1
    from public.properties p
    where p.id = '66666666-6666-4666-8666-666666666601'
      and (
        to_jsonb(p) ? 'phone'
        or to_jsonb(p) ? 'email'
        or to_jsonb(p) ? 'address_line'
      )
  )
  and exists (
    select 1
    from public.properties p
    where p.id = '66666666-6666-4666-8666-666666666601'
  ),
  'a discovery row is visible and has no contact or street fields'
);

select is(
  (
    select count(*)::int
    from public.property_private_details
    where property_id = '66666666-6666-4666-8666-666666666601'
  ),
  0,
  'the street address table is not readable before a visit is accepted'
);

select is(
  (
    public.create_interest(
      'property',
      '66666666-6666-4666-8666-666666666601',
      'like'
    ) -> 'match' ->> 'error'
  ),
  'no_reciprocal',
  'one like does not open contact'
);

select is(
  (
    public.get_contact_visibility('66666666-6666-4666-8666-666666666601'::uuid) ? 'phone'
  ),
  false,
  'contact phone is absent when there is no match'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_host');
set local role authenticated;

select ok(
  (
    public.create_interest('user', tests.get_supabase_uid('journey_tenant'), 'like')
      -> 'match' ->> 'match_id'
  ) is not null,
  'the reciprocal like creates one match'
);

select is(
  (
    public.create_interest('user', tests.get_supabase_uid('journey_tenant'), 'like')
      ->> 'idempotent'
  )::boolean,
  true,
  'repeating the like does not create a second match'
);

reset role;
create table tests.journey_ids (
  key text primary key,
  value uuid
);
grant select, insert on tests.journey_ids to authenticated;
insert into tests.journey_ids (key, value)
select 'match', id
from public.matches
where participant_a = least(
  tests.get_supabase_uid('journey_tenant'),
  tests.get_supabase_uid('journey_host')
)
and participant_b = greatest(
  tests.get_supabase_uid('journey_tenant'),
  tests.get_supabase_uid('journey_host')
);

select tests.authenticate_as('journey_tenant');
set local role authenticated;

select is(
  (public.get_contact_visibility((select value from tests.journey_ids where key = 'match')) ? 'phone'),
  false,
  'phone is absent before consent'
);
select is(
  (public.get_contact_visibility((select value from tests.journey_ids where key = 'match')) ? 'email'),
  false,
  'email is absent before consent'
);
select is(
  (public.get_contact_visibility((select value from tests.journey_ids where key = 'match')) ->> 'reason'),
  'consent_required',
  'the reason is consent_required'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_host');
set local role authenticated;

select ok(
  (
    public.grant_contact_consent(
      (select value from tests.journey_ids where key = 'match'),
      'phone'
    ) ->> 'ok'
  )::boolean,
  'the host records phone consent'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_tenant');
set local role authenticated;

select is(
  public.get_contact_visibility((select value from tests.journey_ids where key = 'match')) ->> 'phone',
  '+910000000061',
  'phone is returned only after consent'
);
select is(
  (public.get_contact_visibility((select value from tests.journey_ids where key = 'match')) ? 'email'),
  false,
  'email stays absent when the scope is phone'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_stranger');
set local role authenticated;

select is(
  (public.get_contact_visibility((select value from tests.journey_ids where key = 'match')) ? 'phone'),
  false,
  'a stranger does not receive the consented phone'
);
select is(
  (public.get_contact_visibility((select value from tests.journey_ids where key = 'match')) ->> 'reason'),
  'not_found',
  'a stranger is not told the match exists'
);
select is(
  (
    public.request_visit(
      (select value from tests.journey_ids where key = 'match'),
      '[{"starts_at":"2026-11-02T05:30:00Z"}]'::jsonb
    ) ->> 'error'
  ),
  'not_participant',
  'a visit request requires the match'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_host');
set local role authenticated;

select public.revoke_contact_consent((select value from tests.journey_ids where key = 'match'));

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_tenant');
set local role authenticated;

select is(
  (public.get_contact_visibility((select value from tests.journey_ids where key = 'match')) ? 'phone'),
  false,
  'revoked consent removes the phone key'
);

select is(
  (
    public.request_visit(
      (select value from tests.journey_ids where key = 'match'),
      '[{"starts_at":"2026-11-02T05:30:00Z"}]'::jsonb
    ) ->> 'status'
  ),
  'requested',
  'a participant can request a visit'
);

insert into tests.journey_ids (key, value)
select 'visit', id
from public.visit_requests
where match_id = (select value from tests.journey_ids where key = 'match')
order by created_at desc
limit 1;

select is(
  (public.get_visit_address((select value from tests.journey_ids where key = 'visit')) ? 'address_line'),
  false,
  'the street address is absent before acceptance'
);
select is(
  (public.get_visit_address((select value from tests.journey_ids where key = 'visit')) ? 'phone'),
  false,
  'a visit address lookup does not include a phone'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_host');
set local role authenticated;

select is(
  (
    public.propose_visit_time(
      (select value from tests.journey_ids where key = 'visit'),
      '[{"starts_at":"2026-11-03T06:30:00Z"}]'::jsonb
    ) ->> 'status'
  ),
  'rescheduled',
  'the other participant can propose a time'
);
select is(
  (
    public.propose_visit_time(
      (select value from tests.journey_ids where key = 'visit'),
      '[{"starts_at":"2026-11-03T06:30:00Z"}]'::jsonb
    ) ? 'address_line'
  ),
  false,
  'proposing a time does not return an address'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_tenant');
set local role authenticated;

select is(
  (
    public.respond_visit(
      (select value from tests.journey_ids where key = 'visit'),
      'accepted'
    ) ->> 'status'
  ),
  'accepted',
  'the requester can accept the proposed time'
);
select is(
  (
    public.respond_visit(
      (select value from tests.journey_ids where key = 'visit'),
      'accepted'
    ) ? 'address_line'
  ),
  false,
  'accepting a visit does not put the address in that response'
);

select is(
  public.get_visit_address((select value from tests.journey_ids where key = 'visit')) ->> 'address_line',
  '99 Fictional Cross',
  'the street address is returned only after acceptance'
);
select is(
  (public.get_visit_address((select value from tests.journey_ids where key = 'visit')) ? 'phone'),
  false,
  'the accepted address payload has no phone'
);
select is(
  (public.get_visit_address((select value from tests.journey_ids where key = 'visit')) ? 'email'),
  false,
  'the accepted address payload has no email'
);

select is(
  (
    public.respond_visit(
      (select value from tests.journey_ids where key = 'visit'),
      'completed'
    ) ->> 'status'
  ),
  'completed',
  'either participant can mark an accepted visit completed'
);

select is(
  public.get_visit_address((select value from tests.journey_ids where key = 'visit')) ->> 'address_line',
  '99 Fictional Cross',
  'the address remains available after the visit is completed'
);

select is(
  (
    public.request_visit(
      (select value from tests.journey_ids where key = 'match'),
      '[{"starts_at":"2026-11-04T05:30:00Z"}]'::jsonb
    ) ->> 'status'
  ),
  'requested',
  'a second visit can be requested'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_host');
set local role authenticated;

select is(
  (
    public.respond_visit(
      (
        select id from public.visit_requests
        where match_id = (select value from tests.journey_ids where key = 'match')
          and status = 'requested'
        limit 1
      ),
      'declined'
    ) ->> 'status'
  ),
  'declined',
  'the other participant can decline'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_tenant');
set local role authenticated;

select public.request_visit(
  (select value from tests.journey_ids where key = 'match'),
  '[{"starts_at":"2026-11-05T05:30:00Z"}]'::jsonb
);

select is(
  (
    public.respond_visit(
      (
        select id from public.visit_requests
        where match_id = (select value from tests.journey_ids where key = 'match')
          and status = 'requested'
        limit 1
      ),
      'cancelled'
    ) ->> 'status'
  ),
  'cancelled',
  'the requester can cancel'
);

reset role;
select tests.clear_authentication();

insert into public.interests (actor_user_id, target_type, target_id, action)
select
  tests.get_supabase_uid('journey_limited'),
  'user'::public.interest_target_type,
  gen_random_uuid(),
  'save'::public.interest_action
from generate_series(1, 200);

select tests.authenticate_as('journey_limited');
set local role authenticated;

select is(
  (
    public.create_interest(
      'property',
      '66666666-6666-4666-8666-666666666601',
      'like'
    ) ->> 'error'
  ),
  'rate_limited',
  'the server rate limit stops the 201st interest in an hour'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('journey_tenant');
set local role authenticated;

insert into public.blocks (blocker_id, blocked_user_id)
values (auth.uid(), tests.get_supabase_uid('journey_host'));

select is(
  public.get_contact_visibility((select value from tests.journey_ids where key = 'match')) ->> 'reason',
  'blocked',
  'a block hides contact after consent would have allowed it'
);
select is(
  (public.get_contact_visibility((select value from tests.journey_ids where key = 'match')) ? 'phone'),
  false,
  'a block omits the phone key'
);

reset role;
select tests.clear_authentication();

do $storage_probe$
begin
  if to_regclass('storage.buckets') is null
     or to_regclass('storage.objects') is null then
    return;
  end if;
  insert into storage.buckets (id, name, public)
  values ('listing-photos', 'listing-photos', false)
  on conflict (id) do nothing;
  insert into storage.objects (bucket_id, name)
  values (
    'listing-photos',
    tests.get_supabase_uid('journey_host')::text || '/home/photo.jpg'
  );
end
$storage_probe$;

select tests.authenticate_as('journey_host');
set local role authenticated;

select is(
  (
    select (body ->> 'ok') = 'true'
      and not (body ? 'phone')
      and not (body ? 'email')
      and not (body ? 'address_line')
    from (select public.delete_own_account() as body) as deleted
  ),
  true,
  'delete_own_account succeeds without contact fields'
);

reset role;
select tests.clear_authentication();

select is(
  (
    select count(*)::int
    from auth.users
    where id = tests.get_supabase_uid('journey_host')
  ),
  0,
  'account deletion removes the auth user'
);
select is(
  (
    select count(*)::int
    from public.private_contacts
    where user_id = tests.get_supabase_uid('journey_host')
  ),
  0,
  'account deletion removes the private contact row'
);
select is(
  (
    select count(*)::int
    from public.properties
    where host_user_id = tests.get_supabase_uid('journey_host')
  ),
  0,
  'account deletion removes the host listings'
);
select is(
  (
    select count(*)::int
    from public.users
    where id = tests.get_supabase_uid('journey_tenant')
  ),
  1,
  'the other account remains'
);

select case
  when to_regclass('storage.objects') is null then
    pass('storage.objects is not in this database')
  else
    is(
      (
        select count(*)::int
        from storage.objects
        where bucket_id = 'listing-photos'
          and split_part(name, '/', 1) = tests.get_supabase_uid('journey_host')::text
      ),
      0,
      'account deletion removes listing-photos objects for that user'
    )
end;

select * from finish();
rollback;
