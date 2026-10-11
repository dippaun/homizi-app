-- Reports, blocks, and local account deletion.
begin;
select no_plan();

set local role anon;
select throws_ok(
  $$select public.delete_own_account()$$,
  '42501',
  'permission denied for function delete_own_account',
  'anonymous clients cannot delete an account'
);
reset role;

select tests.create_supabase_user(
  'safe_a',
  'safe_a@example.test',
  '+910000000097'
);
select tests.create_supabase_user(
  'safe_b',
  'safe_b@example.test',
  '+910000000098'
);
select tests.create_supabase_user(
  'safe_c',
  'safe_c@example.test',
  '+910000000099'
);
select set_config('homizi.safe_a', tests.get_supabase_uid('safe_a')::text, true);
select set_config('homizi.safe_b', tests.get_supabase_uid('safe_b')::text, true);

select throws_ok(
  $$insert into public.reports (reporter_id, target_type, target_id, reason, details)
    values (
      tests.get_supabase_uid('safe_a'),
      'user',
      tests.get_supabase_uid('safe_b'),
      'spam',
      'call 9876543210'
    )$$,
  '23514',
  'new row for relation "reports" violates check constraint "reports_details_no_contact"',
  'a report cannot store a phone number'
);

insert into public.matches (id, participant_a, participant_b)
select
  '99999999-9999-4999-8999-999999999901',
  least(tests.get_supabase_uid('safe_a'), tests.get_supabase_uid('safe_b')),
  greatest(tests.get_supabase_uid('safe_a'), tests.get_supabase_uid('safe_b'));

select tests.authenticate_as('safe_a');
set local role authenticated;

insert into public.reports (reporter_id, target_type, target_id, reason, details)
select auth.uid(), 'user', current_setting('homizi.safe_b')::uuid, 'spam', 'unwanted messages';

select is(
  (select count(*)::int from public.reports),
  1,
  'the reporter can read their own report'
);
select is(
  (
    select details like '%@%' or details like '%9876543210%'
    from public.reports
  ),
  false,
  'the stored report has no contact text'
);

select throws_ok(
  $$insert into public.reports (reporter_id, target_type, target_id, reason, status)
    select auth.uid(), 'user', current_setting('homizi.safe_b')::uuid, 'spam', 'reviewing'$$,
  '42501',
  'new row violates row-level security policy for table "reports"',
  'a reporter cannot set a review status'
);
select throws_ok(
  $$update public.reports set status = 'resolved'$$,
  '42501',
  'permission denied for table reports',
  'a reporter cannot resolve a report'
);
select throws_ok(
  $$insert into public.blocks (blocker_id, blocked_user_id)
    values (auth.uid(), auth.uid())$$,
  '23514',
  'new row for relation "blocks" violates check constraint "blocks_no_self"',
  'a person cannot block themselves'
);

select is(
  (
    public.send_message(
      (
        select id from public.conversations
        where match_id = '99999999-9999-4999-8999-999999999901'
      ),
      'See you at 11'
    ) ->> 'ok'
  ),
  'true',
  'a message sends before the block'
);

insert into public.blocks (blocker_id, blocked_user_id)
select auth.uid(), current_setting('homizi.safe_b')::uuid;

select is(
  (
    public.send_message(
      (
        select id from public.conversations
        where match_id = '99999999-9999-4999-8999-999999999901'
      ),
      'One more note'
    ) ->> 'error'
  ),
  'blocked',
  'a block stops a new message'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('safe_b');
set local role authenticated;

select is(
  (select count(*)::int from public.reports),
  0,
  'the reported person cannot read the report'
);
select is(
  (
    public.send_message(
      (
        select id from public.conversations
        where match_id = '99999999-9999-4999-8999-999999999901'
      ),
      'hello'
    ) ->> 'error'
  ),
  'blocked',
  'the block works in both directions'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('safe_c');
set local role authenticated;

select is(
  (select count(*)::int from public.reports),
  0,
  'a stranger cannot read the report'
);
select throws_ok(
  $$insert into public.reports (reporter_id, target_type, target_id, reason)
    select current_setting('homizi.safe_a')::uuid, 'user', auth.uid(), 'spam'$$,
  '42501',
  'new row violates row-level security policy for table "reports"',
  'a stranger cannot file a report as someone else'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('safe_a');
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
  'account deletion succeeds and returns no contact fields'
);

reset role;
select tests.clear_authentication();

select is(
  (
    select count(*)::int
    from auth.users
    where id = tests.get_supabase_uid('safe_a')
  ),
  0,
  'the auth user is deleted'
);
select is(
  (
    select count(*)::int
    from public.private_contacts
    where user_id = tests.get_supabase_uid('safe_a')
  ),
  0,
  'the private contact row is deleted'
);
select is(
  (
    select count(*)::int
    from public.users
    where id = tests.get_supabase_uid('safe_b')
  ),
  1,
  'the other account remains'
);
select is(
  (
    select count(*)::int
    from public.reports
    where reporter_id = tests.get_supabase_uid('safe_a')
  ),
  0,
  'the deleted person''s report is removed'
);

select * from finish();
rollback;
