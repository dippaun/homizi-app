-- Re-run the K listing seed after furnishing is a text array, and replace
-- the test-account functions without writing a password.
begin;
select no_plan();

select is(
  (
    select data_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'listing_requirements'
      and column_name = 'furnishing'
  ),
  'ARRAY',
  'listing requirement furnishing is an array after M'
);

\ir ../migrations/20261018130100_listing_match_seed.sql

select is(
  (
    select furnishing
    from public.listing_requirements
    where id = 'a1019100-0000-4000-8000-0000000000aa'
  ),
  array['furnished']::text[],
  'the K seed still writes furnishing after it became an array'
);

\ir ../migrations/20261020102000_staging_test_password.sql

select is(
  (select count(*)::int from private.staging_secrets),
  0,
  'replacing the functions does not insert a password'
);

select * from finish();
rollback;
