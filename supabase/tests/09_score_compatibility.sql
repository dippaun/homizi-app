-- Server score matches PD-06 and stays closed to anonymous clients.
begin;
select no_plan();

set local role anon;
select throws_ok(
  $$select public.score_compatibility(
    22000, 'Bengaluru', 'Koramangala', 'furnished', 'apartment',
    15000, 25000, 'Bengaluru', 'Koramangala', 'furnished', 'apartment'
  )$$,
  '42501',
  'permission denied for function score_compatibility',
  'anonymous clients cannot score'
);
reset role;

select tests.create_supabase_user('score_tenant', 'score_tenant@example.test');
select tests.authenticate_as('score_tenant');
set local role authenticated;

select is(
  (public.score_compatibility(
    22000, 'Bengaluru', 'Koramangala', 'furnished', 'apartment',
    15000, 25000, 'Bengaluru', 'Koramangala', 'furnished', 'apartment'
  ) ->> 'score')::integer,
  100,
  'a matching home scores 100'
);

select ok(
  (
    public.score_compatibility(
      22000, 'Bengaluru', 'Koramangala', 'furnished', 'apartment',
      15000, 25000, 'Bengaluru', 'Koramangala', 'furnished', 'apartment'
    ) -> 'reasons'
  ) ? 'Rent sits inside your budget.',
  'inside-budget reason is present'
);

select is(
  (public.score_compatibility(
    9000, 'Pune', 'Kothrud', 'unfurnished', 'shared_room',
    15000, 25000, 'Bengaluru', 'Koramangala', 'furnished', 'apartment'
  ) ->> 'score')::integer,
  0,
  'a different city and type scores 0'
);

select is(
  (public.score_compatibility(
    28000, 'Bengaluru', 'Indiranagar', 'furnished', 'studio',
    15000, 25000, 'Bengaluru', 'Koramangala', 'furnished', 'apartment'
  ) ->> 'score')::integer,
  50,
  'rent just outside the budget is a partial score'
);

select ok(
  position('religion' in public.score_compatibility(
    9000, 'Pune', 'Kothrud', 'unfurnished', 'shared_room',
    15000, 25000, 'Bengaluru', 'Koramangala', 'furnished', 'apartment'
  )::text) = 0,
  'the score payload does not mention religion'
);

select finish();
rollback;
