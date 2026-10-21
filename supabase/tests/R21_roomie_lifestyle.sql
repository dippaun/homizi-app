-- Lifestyle rows are visible to the owner, or to a verified premium viewer.
begin;
select no_plan();

select tests.create_supabase_user('life_owner', 'life-owner@example.test');
select tests.create_supabase_user('life_viewer', 'life-viewer@example.test');

insert into public.roommate_lifestyle (
  user_id, smoking, drinking, food, guests, cooking, note
) values (
  tests.get_supabase_uid('life_owner'),
  'no', 'no', 'vegetarian', 'rarely', 'cook_myself',
  'Quiet kitchen and early nights.'
);

select throws_ok(
  'insert into public.roommate_lifestyle (user_id, smoking) values ('
    || quote_literal(tests.get_supabase_uid('life_viewer'))
    || '::uuid, ''maybe'')',
  '23514',
  null,
  'smoking must be yes, no, or undisclosed'
);
select throws_ok(
  'insert into public.roommate_lifestyle (user_id, note) values ('
    || quote_literal(tests.get_supabase_uid('life_viewer'))
    || '::uuid, ' || quote_literal(repeat('n', 201)) || ')',
  '23514',
  null,
  'the lifestyle note stops at 200 characters'
);

set local role anon;
select throws_ok(
  'select public.roommate_lifestyle('
    || quote_literal(tests.get_supabase_uid('life_owner'))
    || '::uuid)',
  '42501',
  null,
  'anonymous clients cannot read lifestyle details'
);
select throws_ok(
  'select food from public.roommate_lifestyle',
  '42501',
  null,
  'anonymous clients cannot select lifestyle rows'
);
reset role;

select tests.authenticate_as('life_viewer');
set local role authenticated;
select throws_ok(
  $$update public.profiles set is_premium = true where user_id = auth.uid()$$,
  '42501',
  null,
  'clients cannot grant themselves premium'
);
select throws_ok(
  'insert into public.roommate_lifestyle (user_id, smoking) values ('
    || quote_literal(tests.get_supabase_uid('life_owner'))
    || '::uuid, ''yes'')',
  '42501',
  null,
  'you cannot write someone else''s lifestyle'
);
select is(
  (select count(*)::bigint from public.roommate_lifestyle),
  0::bigint,
  'an unverified viewer cannot see lifestyle rows'
);
select is(
  (
    select public.roommate_lifestyle(tests.get_supabase_uid('life_owner'))
      ->> 'visible'
  ),
  'false',
  'an unverified viewer cannot see lifestyle details'
);
select is(
  (
    select public.roommate_lifestyle(tests.get_supabase_uid('life_owner'))
      ->> 'food'
  ),
  null,
  'hidden lifestyle fields are null'
);

reset role;
update public.profiles
set is_premium = true, verification_status = 'not_started'
where user_id = tests.get_supabase_uid('life_viewer');
select tests.authenticate_as('life_viewer');
set local role authenticated;
select is(
  (select count(*)::bigint from public.roommate_lifestyle),
  0::bigint,
  'premium without verification stays hidden'
);
select is(
  (
    select public.roommate_lifestyle(tests.get_supabase_uid('life_owner'))
      ->> 'visible'
  ),
  'false',
  'premium without verification cannot see lifestyle details'
);

reset role;
update public.profiles
set is_premium = false, verification_status = 'mock_verified'
where user_id = tests.get_supabase_uid('life_viewer');
select tests.authenticate_as('life_viewer');
set local role authenticated;
select is(
  (select count(*)::bigint from public.roommate_lifestyle),
  0::bigint,
  'verification without premium stays hidden'
);
select is(
  (
    select public.roommate_lifestyle(tests.get_supabase_uid('life_owner'))
      ->> 'visible'
  ),
  'false',
  'verification without premium cannot see lifestyle details'
);

reset role;
update public.profiles
set is_premium = true, verification_status = 'mock_verified'
where user_id = tests.get_supabase_uid('life_viewer');
select tests.authenticate_as('life_viewer');
set local role authenticated;
select is(
  (select count(*)::bigint from public.roommate_lifestyle),
  1::bigint,
  'a verified premium viewer can read the lifestyle row'
);
select is(
  (select food from public.roommate_lifestyle),
  'vegetarian',
  'the food preference is on the row'
);
select is(
  (
    select public.roommate_lifestyle(tests.get_supabase_uid('life_owner'))
      ->> 'visible'
  ),
  'true',
  'a verified premium viewer can see lifestyle details'
);
select is(
  (
    select public.roommate_lifestyle(tests.get_supabase_uid('life_owner'))
      ->> 'food'
  ),
  'vegetarian',
  'the food preference is returned'
);
select is(
  (
    select public.roommate_lifestyle(tests.get_supabase_uid('life_owner'))
      ->> 'note'
  ),
  'Quiet kitchen and early nights.',
  'the lifestyle note is returned'
);

reset role;
update public.profiles
set is_premium = false, verification_status = 'not_started'
where user_id = tests.get_supabase_uid('life_owner');
select tests.authenticate_as('life_owner');
set local role authenticated;
select is(
  (select note from public.roommate_lifestyle),
  'Quiet kitchen and early nights.',
  'you can read your own lifestyle note'
);
select is(
  (select public.roommate_lifestyle(auth.uid()) ->> 'note'),
  'Quiet kitchen and early nights.',
  'you can read your own lifestyle note from the function'
);

select finish();
rollback;
