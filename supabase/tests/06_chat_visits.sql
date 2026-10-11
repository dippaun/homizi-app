-- Chat and visit requests. Contact details stay out of messages and visit slots.
begin;
select no_plan();

select is(
  public.contains_contact_text('See you at 11'),
  false,
  'a short time is not contact data'
);
select is(
  public.contains_contact_text('Rent is 18000'),
  false,
  'a rent amount is not contact data'
);
select is(
  public.contains_contact_text('call 9876543210'),
  true,
  'a mobile number is contact data'
);
select is(
  public.contains_contact_text('call +91 98765 43210'),
  true,
  'a spaced mobile number is contact data'
);
select is(
  public.contains_contact_text('write ada@example.test'),
  true,
  'an email address is contact data'
);

select tests.create_supabase_user(
  'chat_a',
  'chat_a@example.test',
  '+910000000091'
);
select tests.create_supabase_user(
  'chat_b',
  'chat_b@example.test',
  '+910000000092'
);
select tests.create_supabase_user(
  'chat_c',
  'chat_c@example.test',
  '+910000000093'
);

insert into public.matches (id, participant_a, participant_b)
select
  '77777777-7777-4777-8777-777777777701',
  least(tests.get_supabase_uid('chat_a'), tests.get_supabase_uid('chat_b')),
  greatest(tests.get_supabase_uid('chat_a'), tests.get_supabase_uid('chat_b'));

select is(
  (
    select count(*)::int
    from public.conversations
    where match_id = '77777777-7777-4777-8777-777777777701'
  ),
  1,
  'a match opens one conversation'
);

select tests.authenticate_as('chat_a');
set local role authenticated;

select is(
  (
    public.open_conversation('77777777-7777-4777-8777-777777777701') ->> 'ok'
  ),
  'true',
  'a participant can open the conversation'
);
select is(
  (
    public.open_conversation('77777777-7777-4777-8777-777777777701') ? 'phone'
  ),
  false,
  'open_conversation does not return a phone'
);
select is(
  (
    public.open_conversation('77777777-7777-4777-8777-777777777701') ? 'email'
  ),
  false,
  'open_conversation does not return an email'
);

select is(
  (
    public.send_message(
      (
        select id from public.conversations
        where match_id = '77777777-7777-4777-8777-777777777701'
      ),
      'See you at 11'
    ) ->> 'ok'
  ),
  'true',
  'a plain message is stored'
);
select is(
  (
    public.send_message(
      (
        select id from public.conversations
        where match_id = '77777777-7777-4777-8777-777777777701'
      ),
      'Rent is 18000'
    ) ? 'phone'
  ),
  false,
  'send_message does not return a phone'
);
select is(
  (
    public.send_message(
      (
        select id from public.conversations
        where match_id = '77777777-7777-4777-8777-777777777701'
      ),
      'write ada@example.test'
    ) ->> 'error'
  ),
  'contact',
  'an email is refused'
);
select is(
  (
    public.send_message(
      (
        select id from public.conversations
        where match_id = '77777777-7777-4777-8777-777777777701'
      ),
      'call 9876543210'
    ) ->> 'error'
  ),
  'contact',
  'a phone number is refused'
);
select is(
  (
    select count(*)::int
    from public.messages
    where body like '%9876543210%' or body like '%@%'
  ),
  0,
  'refused contact text is not stored'
);

select throws_ok(
  $$insert into public.messages (conversation_id, sender_id, body)
    values (
      (select id from public.conversations
        where match_id = '77777777-7777-4777-8777-777777777701'),
      auth.uid(),
      'call 9876543210'
    )$$,
  '23514',
  'new row for relation "messages" violates check constraint "messages_no_contact"',
  'a direct insert cannot bypass the contact check'
);

select throws_ok(
  $$insert into public.messages (conversation_id, sender_id, body, status)
    values (
      (select id from public.conversations
        where match_id = '77777777-7777-4777-8777-777777777701'),
      auth.uid(),
      'hello there',
      'hidden'
    )$$,
  '42501',
  'permission denied for table messages',
  'clients cannot set message status'
);

select is(
  (
    public.request_visit(
      '77777777-7777-4777-8777-777777777701',
      '[{"starts_at":"2026-11-02T05:30:00Z"}]'::jsonb
    ) ->> 'status'
  ),
  'requested',
  'a visit starts as requested'
);
select is(
  (
    public.request_visit(
      '77777777-7777-4777-8777-777777777701',
      '[{"starts_at":"2026-11-02T05:30:00Z","phone":"9876543210"}]'::jsonb
    ) ->> 'error'
  ),
  'slots',
  'a visit slot cannot carry a phone'
);
select is(
  (
    public.respond_visit(
      (
        select id from public.visit_requests
        where match_id = '77777777-7777-4777-8777-777777777701'
        order by created_at desc
        limit 1
      ),
      'accepted'
    ) ->> 'error'
  ),
  'not_allowed',
  'the requester cannot accept their own visit'
);

select throws_ok(
  $$update public.visit_requests
    set status = 'accepted'
    where match_id = '77777777-7777-4777-8777-777777777701'$$,
  '42501',
  'permission denied for table visit_requests',
  'clients cannot set visit status directly'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('chat_b');
set local role authenticated;

select is(
  (
    select count(*)::int
    from public.messages
    where body = 'See you at 11'
  ),
  1,
  'the other participant can read the message'
);
select is(
  (
    public.respond_visit(
      (
        select id from public.visit_requests
        where match_id = '77777777-7777-4777-8777-777777777701'
          and status = 'requested'
        limit 1
      ),
      'accepted'
    ) ->> 'ok'
  ),
  'true',
  'the other participant can accept the visit'
);
select is(
  (
    public.respond_visit(
      (
        select id from public.visit_requests
        where match_id = '77777777-7777-4777-8777-777777777701'
        limit 1
      ),
      'accepted'
    ) ? 'address_line'
  ),
  false,
  'accepting a visit does not return a street address'
);
select is(
  (
    select status::text
    from public.visit_requests
    where match_id = '77777777-7777-4777-8777-777777777701'
      and status = 'accepted'
  ),
  'accepted',
  'the visit is accepted without an address column'
);

reset role;
select tests.clear_authentication();
select tests.authenticate_as('chat_c');
set local role authenticated;

select is(
  (
    select count(*)::int from public.messages
  ),
  0,
  'a stranger cannot read the thread'
);
select is(
  (
    public.send_message(
      (
        select id from public.conversations
        where match_id = '77777777-7777-4777-8777-777777777701'
      ),
      'hello'
    ) ->> 'error'
  ),
  'not_participant',
  'a stranger cannot send into the thread'
);
select is(
  (
    select count(*)::int from public.visit_requests
  ),
  0,
  'a stranger cannot read visit requests'
);

select * from finish();
rollback;
