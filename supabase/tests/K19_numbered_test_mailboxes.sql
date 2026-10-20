-- Numbered staging testers. The flag starts off; this test turns it on.
-- test<N>@homizi.in for N = 1..9999 uses the qa+ create path.
-- test@homizi.in stays out of that path.
begin;
select no_plan();

insert into public.staging_flags (key, enabled)
values ('test_accounts_enabled', true);

insert into private.staging_secrets (key, value)
values ('test_password', 'REDACTED_STAGING_PASSWORD')
on conflict (key) do nothing;

insert into private.staging_secrets (key, value)
values ('test_password', 'should-not-replace')
on conflict (key) do nothing;

select is(
  (select value from private.staging_secrets where key = 'test_password'),
  'REDACTED_STAGING_PASSWORD',
  'a second insert does not replace the staging test password'
);

set local role anon;

select throws_ok(
  $$select public.staging_create_test_user('test@homizi.in')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'the shared mailbox is not created as a fresh tester'
);
select throws_ok(
  $$select public.staging_create_test_user('test0@homizi.in')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'zero is outside 1..9999'
);
select throws_ok(
  $$select public.staging_create_test_user('test01@homizi.in')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'a leading zero is refused'
);
select throws_ok(
  $$select public.staging_create_test_user('test10000@homizi.in')$$,
  '22023',
  'That email is not a staging test mailbox.',
  '10000 is outside 1..9999'
);
select throws_ok(
  $$select public.staging_create_test_user('test1@gmail.com')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'a numbered mailbox on another domain is refused'
);

select lives_ok(
  $$select public.staging_create_test_user('Test1@Homizi.in')$$,
  'anon creates test1'
);
select lives_ok(
  $$select public.staging_create_test_user('test1@homizi.in')$$,
  'a second call returns the same mailbox'
);
select lives_ok(
  $$select public.staging_create_test_user('test9999@homizi.in')$$,
  'anon creates test9999'
);
select lives_ok(
  $$select public.staging_create_test_user('qa+still-works@homizi.in')$$,
  'a qa mailbox still creates an account'
);

reset role;

select is(
  (select count(*)::int from auth.users where email = 'test1@homizi.in'),
  1,
  'the second call does not insert another user'
);
select is(
  (select email from auth.users where lower(email) = 'test1@homizi.in'),
  'test1@homizi.in',
  'the stored numbered mailbox is lowercase'
);
select ok(
  (
    select u.email_confirmed_at is not null
      and u.encrypted_password = extensions.crypt(
        'REDACTED_STAGING_PASSWORD',
        u.encrypted_password
      )
    from auth.users u
    where u.email = 'test1@homizi.in'
  ),
  'the numbered user is confirmed and uses the throwaway password'
);
select is(
  (
    select primary_role::text
    from public.users p
    join auth.users u on u.id = p.id
    where u.email = 'test1@homizi.in'
  ),
  'unset',
  'the numbered user has no role yet'
);

-- Roommate matching already seeds test@homizi.in. Create it only when that row is absent.
do $$
begin
  if not exists (
    select 1 from auth.users where email = 'test@homizi.in'
  ) then
    perform tests.create_supabase_user('shared_tester', 'test@homizi.in');
  end if;
end $$;
update auth.users
set created_at = now() - interval '30 days'
where email in ('test@homizi.in', 'test1@homizi.in');
update auth.users
set created_at = now() - interval '1 hour'
where email = 'test9999@homizi.in';

select is(
  public.staging_purge_test_users(interval '7 days'),
  1,
  'purge removes an old numbered mailbox'
);
select is(
  (select count(*)::int from auth.users where email = 'test1@homizi.in'),
  0,
  'the old numbered mailbox is gone'
);
select is(
  (select count(*)::int from auth.users where email = 'test9999@homizi.in'),
  1,
  'a recent numbered mailbox stays'
);
select is(
  (select count(*)::int from auth.users where email = 'test@homizi.in'),
  1,
  'purge leaves the shared test mailbox in place'
);
select is(
  (select count(*)::int from auth.users where email = 'qa+still-works@homizi.in'),
  1,
  'purge leaves a recent qa mailbox in place'
);

select * from finish();
rollback;
