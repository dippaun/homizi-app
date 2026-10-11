-- In-app notifications. Payloads are ids. Clients cannot insert or rewrite them.
begin;
select no_plan();

select is(
  public.notification_payload_ok(
    '{"match_id":"88888888-8888-4888-8888-888888888801"}'::jsonb
  ),
  true,
  'a match id is a valid payload'
);
select is(
  public.notification_payload_ok(
    '{"match_id":"88888888-8888-4888-8888-888888888801","phone":"9876543210"}'::jsonb
  ),
  false,
  'a phone key is not a valid payload'
);
select is(
  public.notification_payload_ok(
    '{"match_id":"88888888-8888-4888-8888-888888888801","address_line":"12 MG Road"}'::jsonb
  ),
  false,
  'a street address key is not a valid payload'
);
select is(
  public.notification_payload_ok(
    '{"match_id":"ada@example.test"}'::jsonb
  ),
  false,
  'an email value is not a valid payload'
);
select is(
  public.notification_payload_ok(
    '{"match_id":"88888888-8888-4888-8888-888888888801","title":"home"}'::jsonb
  ),
  false,
  'an extra key is not a valid payload'
);

select tests.create_supabase_user(
  'note_a',
  'note_a@example.test',
  '+910000000094'
);
select tests.create_supabase_user(
  'note_b',
  'note_b@example.test',
  '+910000000095'
);
select tests.create_supabase_user(
  'note_c',
  'note_c@example.test',
  '+910000000096'
);

select throws_ok(
  $$insert into public.notifications (user_id, type, payload_minimal)
    values (
      tests.get_supabase_uid('note_a'),
      'match',
      '{"phone":"9876543210"}'::jsonb
    )$$,
  '23514',
  'new row for relation "notifications" violates check constraint "notifications_payload"',
  'a notification cannot store a phone'
);
select throws_ok(
  $$insert into public.notifications (user_id, type, payload_minimal)
    values (
      tests.get_supabase_uid('note_a'),
      'match',
      '{"match_id":"88888888-8888-4888-8888-888888888801","address_line":"12 MG Road"}'::jsonb
    )$$,
  '23514',
  'new row for relation "notifications" violates check constraint "notifications_payload"',
  'a notification cannot store a street address'
);

insert into public.matches (id, participant_a, participant_b)
select
  '88888888-8888-4888-8888-888888888801',
  least(tests.get_supabase_uid('note_a'), tests.get_supabase_uid('note_b')),
  greatest(tests.get_supabase_uid('note_a'), tests.get_supabase_uid('note_b'));

select is(
  (
    select count(*)::int
    from public.notifications
    where type = 'match'
      and payload_minimal ->> 'match_id' = '88888888-8888-4888-8888-888888888801'
  ),
  2,
  'a new match notifies both participants'
);

select tests.authenticate_as('note_a');
set local role authenticated;

select throws_ok(
  $$insert into public.notifications (user_id, type, payload_minimal)
    values (
      auth.uid(),
      'match',
      '{"match_id":"88888888-8888-4888-8888-888888888801"}'::jsonb
    )$$,
  '42501',
  'permission denied for table notifications',
  'clients cannot insert a notification'
);
select throws_ok(
  $$select public.enqueue_notification(
    auth.uid(),
    'match',
    '{"match_id":"88888888-8888-4888-8888-888888888801"}'::jsonb
  )$$,
  '42501',
  'permission denied for function enqueue_notification',
  'clients cannot enqueue a notification'
);

update public.notifications
set read_at = now()
where type = 'match'
  and user_id = auth.uid();

select is(
  (
    select read_at is not null
    from public.notifications
    where type = 'match'
      and user_id = auth.uid()
  ),
  true,
  'the recipient can mark their notification read'
);

select throws_ok(
  $$update public.notifications
    set type = 'message'
    where user_id = auth.uid()$$,
  '42501',
  'permission denied for table notifications',
  'the recipient cannot change the type'
);
select throws_ok(
  $$update public.notifications
    set payload_minimal = '{"match_id":"88888888-8888-4888-8888-888888888801"}'::jsonb
    where user_id = auth.uid()$$,
  '42501',
  'permission denied for table notifications',
  'the recipient cannot change the payload'
);

select is(
  (
    public.send_message(
      (
        select id from public.conversations
        where match_id = '88888888-8888-4888-8888-888888888801'
      ),
      'See you at 11'
    ) ->> 'ok'
  ),
  'true',
  'a message still sends'
);
select is(
  (
    public.request_visit(
      '88888888-8888-4888-8888-888888888801',
      '[{"starts_at":"2026-11-02T05:30:00Z"}]'::jsonb
    ) ->> 'status'
  ),
  'requested',
  'a visit still starts as requested'
);
select is(
  (
    select count(*)::int
    from public.notifications
    where type = 'message'
  ),
  0,
  'the sender is not notified of their own message'
);
select is(
  (
    select count(*)::int
    from public.notifications
    where type = 'visit_requested'
  ),
  0,
  'the requester is not notified of their own visit'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('note_b');
set local role authenticated;

select is(
  (
    select count(*)::int
    from public.notifications
    where type = 'message'
      and payload_minimal ? 'conversation_id'
      and payload_minimal ? 'match_id'
      and not (payload_minimal ? 'body')
      and not (payload_minimal ? 'phone')
      and not (payload_minimal ? 'email')
      and not (payload_minimal ? 'address_line')
  ),
  1,
  'the other person gets a message id, not the body or contact fields'
);
select is(
  (
    select count(*)::int
    from public.notifications
    where type = 'visit_requested'
      and payload_minimal ? 'visit_id'
      and not (payload_minimal ? 'address_line')
  ),
  1,
  'the other person is notified of the visit request'
);

select is(
  (
    public.respond_visit(
      (
        select id from public.visit_requests
        where match_id = '88888888-8888-4888-8888-888888888801'
          and status = 'requested'
      ),
      'accepted'
    ) ->> 'ok'
  ),
  'true',
  'the other participant can accept the visit'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('note_a');
set local role authenticated;

select is(
  (
    select count(*)::int
    from public.notifications
    where type = 'visit_accepted'
      and payload_minimal ? 'visit_id'
      and not (payload_minimal ? 'address_line')
      and not (payload_minimal ? 'phone')
      and not (payload_minimal ? 'email')
  ),
  1,
  'the requester is notified when the visit is accepted'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('note_c');
set local role authenticated;

select is(
  (select count(*)::int from public.notifications),
  0,
  'a stranger cannot read notifications'
);
update public.notifications
set read_at = now()
where type = 'message';

select is(
  (select count(*)::int from public.notifications),
  0,
  'a stranger cannot mark a notification read'
);

reset role;
select tests.clear_authentication();

select is(
  (
    select bool_and(read_at is null)
    from public.notifications
    where type = 'message'
      and payload_minimal ->> 'match_id' = '88888888-8888-4888-8888-888888888801'
  ),
  true,
  'the message notification stayed unread'
);
select is(
  (
    select bool_and(
      public.notification_payload_ok(payload_minimal)
      and not (
        payload_minimal ?| array[
          'phone',
          'email',
          'address_line',
          'landmark',
          'latitude',
          'longitude',
          'street_address',
          'aadhaar',
          'body'
        ]
      )
    )
    from public.notifications
  ),
  true,
  'every stored payload is ids only'
);

select * from finish();
rollback;
