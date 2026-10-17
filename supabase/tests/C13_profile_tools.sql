-- Slice C: notification preferences, rent tools, checklist share, support tickets.
begin;
select no_plan();

select is(
  public.notification_payload_ok(
    '{"deposit_id":"c13c13c1-c13c-413c-813c-c13c13c13c13"}'::jsonb
  ),
  true,
  'a deposit id is a valid payload'
);
select is(
  public.notification_payload_ok(
    '{"deposit_id":"c13c13c1-c13c-413c-813c-c13c13c13c13","phone":"9876543210"}'::jsonb
  ),
  false,
  'a deposit payload cannot carry a phone'
);
select is(
  public.notification_payload_ok(
    '{"match_id":"c13c13c1-c13c-413c-813c-c13c13c13c13","address_line":"12 MG Road"}'::jsonb
  ),
  false,
  'a street address is still not a valid payload'
);

select tests.create_supabase_user(
  'tools_a',
  'tools_a@example.test',
  '+910000000171'
);
select tests.create_supabase_user(
  'tools_b',
  'tools_b@example.test',
  '+910000000172'
);
select tests.create_supabase_user(
  'tools_staff',
  'tools_staff@example.test',
  '+910000000173'
);
select tests.create_supabase_user(
  'tools_out',
  'tools_out@example.test',
  '+910000000174'
);

insert into public.staff_roles (user_id)
select tests.get_supabase_uid('tools_staff');

insert into public.notification_preferences (user_id, matches, system)
select tests.get_supabase_uid('tools_a'), false, true;

select is(
  public.notification_allowed(tests.get_supabase_uid('tools_a'), 'match'),
  false,
  'matches can be turned off'
);
select is(
  public.notification_allowed(tests.get_supabase_uid('tools_a'), 'message'),
  true,
  'chat stays on when only matches are off'
);
select is(
  public.notification_allowed(tests.get_supabase_uid('tools_b'), 'match'),
  true,
  'a missing preferences row leaves categories on'
);

insert into public.matches (id, participant_a, participant_b)
select
  'c13c13c1-c13c-413c-813c-c13c13c13c13',
  least(tests.get_supabase_uid('tools_a'), tests.get_supabase_uid('tools_b')),
  greatest(tests.get_supabase_uid('tools_a'), tests.get_supabase_uid('tools_b'));

select is(
  (
    select count(*)::int
    from public.notifications
    where type = 'match'
      and user_id = tests.get_supabase_uid('tools_a')
      and payload_minimal ->> 'match_id' = 'c13c13c1-c13c-413c-813c-c13c13c13c13'
  ),
  0,
  'a match notification is skipped when that category is off'
);
select is(
  (
    select count(*)::int
    from public.notifications
    where type = 'match'
      and user_id = tests.get_supabase_uid('tools_b')
      and payload_minimal ->> 'match_id' = 'c13c13c1-c13c-413c-813c-c13c13c13c13'
  ),
  1,
  'the other person still gets the match notification'
);

select tests.authenticate_as('tools_a');
set local role authenticated;

select throws_ok(
  $$insert into public.notifications (user_id, type, payload_minimal)
    values (
      auth.uid(),
      'deposit_reminder',
      '{"deposit_id":"c13c13c1-c13c-413c-813c-c13c13c13c21"}'::jsonb
    )$$,
  '42501',
  'permission denied for table notifications',
  'clients still cannot insert a notification'
);

insert into public.rent_receipts (
  id,
  user_id,
  tenant_name,
  owner_name,
  property_address,
  monthly_rent_inr,
  period_start,
  period_end,
  owner_pan,
  payment_mode
) values (
  'c13c13c1-c13c-413c-813c-c13c13c13c31',
  auth.uid(),
  'Ananya Iyer',
  'Rohan Mehta',
  '18, 4th Cross, Koramangala 5th Block, Bengaluru',
  28000,
  '2026-04-01',
  '2026-06-01',
  'ABCDE1234F',
  'upi'
);

select throws_ok(
  $$insert into public.rent_receipts (
    user_id, tenant_name, owner_name, property_address,
    monthly_rent_inr, period_start, period_end, owner_pan, payment_mode
  ) values (
    auth.uid(), 'Ananya Iyer', 'Rohan Mehta',
    '18, 4th Cross, Koramangala 5th Block, Bengaluru',
    28000, '2026-04-01', '2026-06-01', 'not-a-pan', 'upi'
  )$$,
  '23514',
  'a receipt rejects a PAN that is not in the standard shape'
);

insert into public.rent_agreement_drafts (
  user_id,
  licensor_name,
  licensee_name,
  property_address,
  city,
  monthly_rent_inr,
  deposit_inr,
  maintenance_inr,
  start_date
) values (
  auth.uid(),
  'Rohan Mehta',
  'Ananya Iyer',
  '18, 4th Cross, Koramangala 5th Block, Bengaluru',
  'Bengaluru',
  28000,
  84000,
  2000,
  '2026-11-01'
);

select is(
  (
    select term_months
    from public.rent_agreement_drafts
    where user_id = auth.uid()
  ),
  11,
  'an agreement draft is locked to 11 months'
);

insert into public.move_in_checklists (id, user_id, match_id, title)
values (
  'c13c13c1-c13c-413c-813c-c13c13c13c41',
  auth.uid(),
  'c13c13c1-c13c-413c-813c-c13c13c13c13',
  'Koramangala move-in'
);

insert into public.move_in_items (
  id, checklist_id, room, item_name, condition, notes
) values (
  'c13c13c1-c13c-413c-813c-c13c13c13c42',
  'c13c13c1-c13c-413c-813c-c13c13c13c41',
  'Living room',
  'Sofa',
  'good',
  'No stains on the seat'
);

insert into public.deposit_trackers (
  id, user_id, property_label, deposit_paid_inr, refund_due_on
) values (
  'c13c13c1-c13c-413c-813c-c13c13c13c21',
  auth.uid(),
  'Koramangala 5th Block',
  84000,
  '2026-12-01'
);

insert into public.deposit_deductions (tracker_id, label, amount_inr)
values (
  'c13c13c1-c13c-413c-813c-c13c13c13c21',
  'Painting',
  8000
);

select is(
  public.remind_own_deposit('c13c13c1-c13c-413c-813c-c13c13c13c21'),
  true,
  'the owner can add an in-app deposit reminder'
);
select is(
  (
    select (payload_minimal - 'deposit_id') = '{}'::jsonb
    from public.notifications
    where user_id = auth.uid()
      and type = 'deposit_reminder'
  ),
  true,
  'a deposit reminder stores only the tracker id'
);

insert into public.support_tickets (user_id, topic, message)
values (
  auth.uid(),
  'renting',
  'Need help understanding a visit for a Koramangala flat.'
);

select ok(
  (public.profile_activity() ->> 'saved_count')::int >= 0,
  'profile activity returns a saved count'
);
select ok(
  public.profile_activity() ? 'viewed_available',
  'profile activity says whether recently viewed exists'
);

reset role;
select tests.authenticate_as('tools_b');
set local role authenticated;

select is(
  (select count(*) from public.rent_receipts),
  0::bigint,
  'another person cannot read a rent receipt'
);
select is(
  (select count(*) from public.rent_agreement_drafts),
  0::bigint,
  'another person cannot read an agreement draft'
);
select is(
  (select count(*) from public.deposit_trackers),
  0::bigint,
  'another person cannot read a deposit tracker'
);
select is(
  (
    select count(*)
    from public.move_in_checklists
    where id = 'c13c13c1-c13c-413c-813c-c13c13c13c41'
  ),
  1::bigint,
  'the other match participant can read the checklist'
);
select is(
  (
    select notes
    from public.move_in_items
    where id = 'c13c13c1-c13c-413c-813c-c13c13c13c42'
  ),
  'No stains on the seat',
  'the other match participant can read an item'
);

update public.move_in_items
set notes = 'Changed by the other person'
where id = 'c13c13c1-c13c-413c-813c-c13c13c13c42';

select is(
  (
    select notes
    from public.move_in_items
    where id = 'c13c13c1-c13c-413c-813c-c13c13c13c42'
  ),
  'No stains on the seat',
  'the other match participant cannot edit the checklist'
);

select throws_ok(
  $$select public.remind_own_deposit('c13c13c1-c13c-413c-813c-c13c13c13c21')$$,
  'P0001',
  'That deposit record is not yours.',
  'another person cannot set the deposit reminder'
);

select is(
  (select count(*) from public.support_tickets),
  0::bigint,
  'another person cannot read a support ticket'
);

reset role;
select tests.authenticate_as('tools_out');
set local role authenticated;

select is(
  (
    select count(*)
    from public.move_in_checklists
    where id = 'c13c13c1-c13c-413c-813c-c13c13c13c41'
  ),
  0::bigint,
  'someone outside the match cannot read the checklist'
);

reset role;
select tests.authenticate_as('tools_staff');
set local role authenticated;

select is(
  (select count(*) from public.support_tickets where topic = 'renting'),
  1::bigint,
  'staff can read a support ticket'
);
select is(
  (select count(*) from public.rent_receipts),
  0::bigint,
  'staff cannot read another person''s rent receipt'
);

select * from finish();
rollback;
