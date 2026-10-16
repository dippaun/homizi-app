-- Realtime publication, staff queue, and analytics funnel.
-- A member cannot review, hide, suspend, or read someone else's events.
begin;
select no_plan();

select ok(
  (
    select relreplident = 'f'
    from pg_class
    where oid = 'public.messages'::regclass
  ),
  'messages use full replica identity so realtime can filter a conversation'
);

select ok(
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ),
  'messages are in the supabase_realtime publication'
);

select tests.create_supabase_user(
  'mod_host',
  'mod_host@example.test',
  '+910000000071'
);
select tests.create_supabase_user(
  'mod_member',
  'mod_member@example.test',
  '+910000000072'
);
select tests.create_supabase_user(
  'mod_staff',
  'mod_staff@example.test',
  '+910000000073'
);

insert into public.staff_roles (user_id)
select tests.get_supabase_uid('mod_staff');

select tests.authenticate_as('mod_host');
set local role authenticated;

insert into public.properties (
  id,
  host_user_id,
  title,
  locality,
  city,
  property_type,
  furnishing,
  rent_inr
) values (
  '12121212-1212-4121-8121-121212121212',
  auth.uid(),
  'Queue flat',
  'Koramangala',
  'Bengaluru',
  'apartment',
  'furnished',
  20000
);

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('12121212-1212-4121-8121-121212121212', 'queue/0.slot', 0, 'living'),
  ('12121212-1212-4121-8121-121212121212', 'queue/1.slot', 1, 'bedroom'),
  ('12121212-1212-4121-8121-121212121212', 'queue/2.slot', 2, 'kitchen');

select is(
  (public.publish_listing('12121212-1212-4121-8121-121212121212'::uuid) ->> 'ok'),
  'true',
  'the host can publish the listing the queue will hide'
);

insert into public.properties (
  id,
  host_user_id,
  title,
  locality,
  city,
  property_type,
  furnishing,
  rent_inr
) values (
  '12121212-1212-4121-8121-121212121213',
  auth.uid(),
  'Second queue flat',
  'Indiranagar',
  'Bengaluru',
  'apartment',
  'furnished',
  22000
);

insert into public.property_photos (property_id, storage_path, sort_order, photo_type)
values
  ('12121212-1212-4121-8121-121212121213', 'queue/3.slot', 0, 'living'),
  ('12121212-1212-4121-8121-121212121213', 'queue/4.slot', 1, 'bedroom'),
  ('12121212-1212-4121-8121-121212121213', 'queue/5.slot', 2, 'kitchen');

select is(
  (public.publish_listing('12121212-1212-4121-8121-121212121213'::uuid) ->> 'ok'),
  'true',
  'the host can publish a second listing that suspend will hide'
);

reset role;

insert into public.matches (id, participant_a, participant_b)
select
  '13131313-1313-4131-8131-131313131313',
  least(tests.get_supabase_uid('mod_host'), tests.get_supabase_uid('mod_member')),
  greatest(tests.get_supabase_uid('mod_host'), tests.get_supabase_uid('mod_member'));

select tests.authenticate_as('mod_member');
set local role authenticated;

insert into public.reports (reporter_id, target_type, target_id, reason, details)
values (
  auth.uid(),
  'property',
  '12121212-1212-4121-8121-121212121212',
  'fake_listing',
  'Photos look copied.'
);

select set_config(
  'homizi.report_id',
  (
    select id::text
    from public.reports
    where reporter_id = auth.uid()
    limit 1
  ),
  true
);

select is(
  (public.staff_list_reports() ->> 'error'),
  'not_staff',
  'a member cannot open the moderation queue'
);
select is(
  (
    public.staff_review_report(
      current_setting('homizi.report_id')::uuid,
      'resolved'
    ) ->> 'error'
  ),
  'not_staff',
  'a member cannot resolve a report'
);
select is(
  (
    public.staff_hide_listing('12121212-1212-4121-8121-121212121212'::uuid) ->> 'error'
  ),
  'not_staff',
  'a member cannot hide a listing'
);
select is(
  (
    public.staff_suspend_user(tests.get_supabase_uid('mod_host')) ->> 'error'
  ),
  'not_staff',
  'a member cannot suspend an account'
);

insert into public.analytics_events (user_id, name, properties)
values
  (auth.uid(), 'app_open', '{}'),
  (auth.uid(), 'listing_view', '{"listing_id":"12121212-1212-4121-8121-121212121212"}'),
  (auth.uid(), 'interest_sent', '{"listing_id":"12121212-1212-4121-8121-121212121212"}'),
  (auth.uid(), 'match_opened', '{"match_id":"13131313-1313-4131-8131-131313131313"}'),
  (auth.uid(), 'message_sent', '{"match_id":"13131313-1313-4131-8131-131313131313"}');

select throws_ok(
  $$insert into public.analytics_events (user_id, name, properties)
    values (auth.uid(), 'app_open', '{"phone":"+910000000071"}')$$,
  '23514',
  'new row for relation "analytics_events" violates check constraint "analytics_events_properties"',
  'analytics properties cannot carry a phone'
);
select throws_ok(
  $$insert into public.analytics_events (user_id, name, properties)
    values (auth.uid(), 'listing_view', '{"listing_id":"ada@example.test"}')$$,
  '23514',
  'new row for relation "analytics_events" violates check constraint "analytics_events_properties"',
  'analytics properties cannot carry an email'
);
select throws_ok(
  $$insert into public.analytics_events (user_id, name)
    values (tests.get_supabase_uid('mod_host'), 'app_open')$$,
  '42501',
  'new row violates row-level security policy for table "analytics_events"',
  'a member cannot write an event for someone else'
);
select is(
  (select count(*)::int from public.analytics_events),
  0,
  'a member cannot read analytics events'
);
select is(
  (select app_open::int from public.analytics_funnel),
  0,
  'the funnel counts are empty for a member'
);
select is(
  (select count(*)::int from public.analytics_funnel_steps),
  0,
  'a member sees no funnel steps'
);

reset role;
set local role anon;

select throws_ok(
  $$select public.staff_list_reports()$$,
  '42501',
  'permission denied for function staff_list_reports',
  'anonymous clients cannot open the queue'
);

reset role;
select tests.authenticate_as('mod_staff');
set local role authenticated;

select is(
  (public.staff_list_reports() ->> 'ok'),
  'true',
  'staff can list open reports'
);
select ok(
  position('phone' in public.staff_list_reports()::text) = 0
    and position('email' in public.staff_list_reports()::text) = 0
    and position('@' in public.staff_list_reports()::text) = 0,
  'the queue payload has no contact fields'
);
select is(
  (
    select count(*)::int
    from public.private_contacts
    where user_id = tests.get_supabase_uid('mod_host')
  ),
  0,
  'staff cannot read a private contact row'
);
select is(
  (
    public.staff_review_report(
      current_setting('homizi.report_id')::uuid,
      'resolved'
    ) ->> 'status'
  ),
  'resolved',
  'staff can resolve a report'
);
select is(
  (public.staff_list_reports() -> 'reports'),
  '[]'::jsonb,
  'a resolved report leaves the open queue'
);
select throws_ok(
  $$update public.reports set status = 'dismissed'$$,
  '42501',
  'permission denied for table reports',
  'staff cannot update report status except through the function'
);
select is(
  (
    public.staff_hide_listing('12121212-1212-4121-8121-121212121212'::uuid) ->> 'status'
  ),
  'paused',
  'staff can hide a published listing'
);
select throws_ok(
  $$update public.properties
    set status = 'published'
    where id = '12121212-1212-4121-8121-121212121213'$$,
  '42501',
  'permission denied for table properties',
  'staff cannot set listing status except through the function'
);
select is(
  (
    public.staff_suspend_user(tests.get_supabase_uid('mod_host')) ->> 'status'
  ),
  'suspended',
  'staff can suspend another account'
);
select is(
  (public.staff_suspend_user(auth.uid()) ->> 'error'),
  'not_allowed',
  'staff cannot suspend their own account'
);
select is(
  (select app_open::int from public.analytics_funnel),
  1,
  'staff can read the app open step'
);
select is(
  (select listing_view::int from public.analytics_funnel),
  1,
  'staff can read the listing view step'
);
select is(
  (select interest_sent::int from public.analytics_funnel),
  1,
  'staff can read the interest step'
);
select is(
  (select match_opened::int from public.analytics_funnel),
  1,
  'staff can read the match step'
);
select is(
  (select message_sent::int from public.analytics_funnel),
  1,
  'staff can read the message step'
);
select is(
  (
    select people::int
    from public.analytics_funnel_steps
    where name = 'message_sent'
  ),
  1,
  'the step view counts one person at message sent'
);
select ok(
  (
    select count(*) > 0
    from public.analytics_funnel_daily
    where name = 'app_open'
  ),
  'the daily view has an app open row for staff'
);

reset role;

select is(
  (
    select status::text
    from public.properties
    where id = '12121212-1212-4121-8121-121212121212'
  ),
  'paused',
  'the hidden listing is paused'
);
select is(
  (
    select status::text
    from public.properties
    where id = '12121212-1212-4121-8121-121212121213'
  ),
  'paused',
  'suspending a host pauses their published listings'
);
select is(
  (
    select status::text
    from public.users
    where id = tests.get_supabase_uid('mod_host')
  ),
  'suspended',
  'the account status is suspended'
);
select is(
  (
    select count(*)::int
    from public.audit_events
    where action in ('review_report', 'hide_listing', 'suspend_user')
      and (
        metadata_minimal ? 'phone'
        or metadata_minimal ? 'email'
        or metadata_minimal ? 'aadhaar'
      )
  ),
  0,
  'moderation audit rows have no contact keys'
);

select tests.authenticate_as('mod_member');
set local role authenticated;

select is(
  (
    select count(*)::int
    from public.properties
    where id = '12121212-1212-4121-8121-121212121212'
  ),
  0,
  'a hidden listing is not in another person''s feed'
);

reset role;
select tests.authenticate_as('mod_host');
set local role authenticated;

select throws_ok(
  $$select public.send_message(
    (select id from public.conversations
      where match_id = '13131313-1313-4131-8131-131313131313'),
    'Still here'
  )$$,
  '42501',
  'account is suspended',
  'a suspended account cannot send a message'
);
select throws_ok(
  $$insert into public.messages (conversation_id, sender_id, body)
    select id, auth.uid(), 'Bypass'
    from public.conversations
    where match_id = '13131313-1313-4131-8131-131313131313'$$,
  '42501',
  'account is suspended',
  'a suspended account cannot insert a message directly'
);

select * from finish();
rollback;
