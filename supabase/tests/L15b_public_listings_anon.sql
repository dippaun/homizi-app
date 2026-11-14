-- Anon and a signed-in person can call public_listings without schema private.
begin;
select no_plan();

select ok(
  (
    select p.prosecdef
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'public_listings'
  ),
  'public_listings is security definer'
);

select ok(
  position(
    'phone' in pg_get_function_result('public.public_listings()'::regprocedure)
  ) = 0
  and position(
    'email' in pg_get_function_result('public.public_listings()'::regprocedure)
  ) = 0,
  'public_listings does not return contact columns'
);

select ok(
  not has_schema_privilege('anon', 'private', 'usage'),
  'anon is not granted usage on schema private'
);

select ok(
  not has_schema_privilege('authenticated', 'private', 'usage'),
  'authenticated is not granted usage on schema private'
);

select tests.clear_authentication();
set local role anon;

select lives_ok(
  $$select * from public.public_listings()$$,
  'anon can call public_listings'
);

select cmp_ok(
  (select count(*) from public.public_listings()),
  '>',
  0::bigint,
  'anon receives at least one published listing'
);

select is(
  (
    select count(*)::int
    from public.public_listings()
    where id = '22222222-2222-4222-8222-222222222202'
  ),
  0,
  'anon does not receive the seeded draft'
);

reset role;
select tests.authenticate_as('ananya');
set local role authenticated;

select lives_ok(
  $$select * from public.public_listings()$$,
  'a signed-in person can call public_listings'
);

select * from finish();
rollback;
