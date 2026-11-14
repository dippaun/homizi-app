-- A rent split is visible only to the person who saved it.
begin;
select no_plan();

select tests.create_supabase_user('rs_owner', 'rs_owner@example.test');
select tests.create_supabase_user('rs_other', 'rs_other@example.test');

select tests.authenticate_as('rs_owner');
set local role authenticated;

select lives_ok(
  $$insert into public.rent_splits (property_label, locality, total_rent_inr, mode, rooms, shares, agreed)
    values ('3 BHK', 'Andheri East, Mumbai', 30000, 'smart',
      '[{"size":"large","attached_bath":true,"occupants":["You"]}]',
      '[{"name":"You","room":0,"rent_inr":13500,"bills_inr":0},{"name":"Amit","room":1,"rent_inr":8250,"bills_inr":0},{"name":"Rahul","room":2,"rent_inr":8250,"bills_inr":0}]',
      '["You","Amit","Rahul"]')$$,
  'the owner can save a split'
);
select is(
  (select count(*) from public.rent_splits),
  1::bigint,
  'the owner reads their split'
);
select throws_ok(
  $$insert into public.rent_splits (owner_id, property_label, locality, total_rent_inr, mode, shares)
    values (tests.get_supabase_uid('rs_other'), '2 BHK', 'Baner, Pune', 20000, 'equal',
      '[{"name":"A","room":0,"rent_inr":20000,"bills_inr":0}]')$$,
  '42501',
  NULL,
  'nobody can save a split for someone else'
);
select throws_ok(
  $$insert into public.rent_splits (property_label, locality, total_rent_inr, mode, shares)
    values ('2 BHK', 'Baner, Pune', 20000, 'equal',
      '[{"name":"amit@example.in","room":0,"rent_inr":20000,"bills_inr":0}]')$$,
  '23514',
  NULL,
  'contact details are refused'
);

reset role;
select tests.authenticate_as('rs_other');
set local role authenticated;

select is(
  (select count(*) from public.rent_splits),
  0::bigint,
  'another person cannot read the split'
);

select * from finish();
rollback;
