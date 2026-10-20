-- Staging fresh testers. The migration leaves the flag off.
-- Anon may create a qa+ or test<N> mailbox only after the flag is on
-- and private.staging_secrets.test_password has been set by hand.
begin;
select no_plan();

select is(
  (
    select count(*)::int
    from public.staging_flags
    where key = 'test_accounts_enabled'
  ),
  0,
  'the migration does not enable test accounts'
);

select ok(
  has_function_privilege(
    'anon',
    'public.staging_create_test_user(text)',
    'execute'
  ),
  'anon can call staging_create_test_user'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.staging_create_test_user(text)',
    'execute'
  ),
  'authenticated cannot call staging_create_test_user'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.staging_purge_test_users(interval)',
    'execute'
  ),
  'anon cannot purge test users'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.staging_purge_test_users(interval)',
    'execute'
  ),
  'authenticated cannot purge test users'
);

select throws_ok(
  $$select public.staging_purge_test_users(interval '1 day')$$,
  '42501',
  'Staging test accounts are off.',
  'purge refuses while the flag is absent'
);

set local role anon;

select throws_ok(
  $$select * from public.staging_flags$$,
  '42501'
);

select throws_ok(
  $$select public.staging_create_test_user('qa+fresh@homizi.in')$$,
  '42501',
  'Staging test accounts are off.',
  'flag off rejects a valid qa mailbox'
);

select throws_ok(
  $$select public.staging_create_test_user('person@example.test')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'a normal email is refused while test accounts are off'
);

select throws_ok(
  $$select public.staging_create_test_user(null)$$,
  '22023',
  'That email is not a staging test mailbox.',
  'a null email is refused'
);

select throws_ok(
  $$select public.staging_purge_test_users(interval '1 day')$$,
  '42501'
);

reset role;

insert into public.staging_flags (key, enabled)
values ('test_accounts_enabled', false);

set local role anon;
select throws_ok(
  $$select public.staging_create_test_user('qa+fresh@homizi.in')$$,
  '42501',
  'Staging test accounts are off.',
  'a false flag rejects a valid qa mailbox'
);
reset role;

update public.staging_flags
set enabled = true
where key = 'test_accounts_enabled';

set local role anon;

select throws_ok(
  $$select public.staging_create_test_user('qa+@homizi.in')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'an empty suffix is refused'
);
select throws_ok(
  $$select public.staging_create_test_user('qa+bad_email@homizi.in')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'an underscore suffix is refused'
);
select throws_ok(
  $$select public.staging_create_test_user('qa+foo@homizi.com')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'a different domain is refused'
);
select throws_ok(
  $$select public.staging_create_test_user('test@homizi.in')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'the shared staging mailbox is not a fresh tester'
);
select throws_ok(
  $$select public.staging_create_test_user('qa+foo+bar@homizi.in')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'a second plus is refused'
);
select throws_ok(
  $$select public.staging_create_test_user('qa+' || repeat('a', 33) || '@homizi.in')$$,
  '22023',
  'That email is not a staging test mailbox.',
  'a 33 character suffix is refused'
);

select throws_ok(
  $$select public.staging_create_test_user('qa+missing-secret@homizi.in')$$,
  '42501',
  'The staging test password has not been set.',
  'a new mailbox waits until the password is set by hand'
);

select throws_ok(
  $$select * from private.staging_secrets$$,
  '42501'
);

reset role;

select ok(
  not has_table_privilege('anon', 'private.staging_secrets', 'select'),
  'anon cannot read staging secrets'
);
select ok(
  not has_table_privilege('authenticated', 'private.staging_secrets', 'select'),
  'authenticated cannot read staging secrets'
);
select ok(
  not has_table_privilege('anon', 'private.staging_secrets', 'insert'),
  'anon cannot insert a staging secret'
);
select ok(
  has_table_privilege('service_role', 'private.staging_secrets', 'select'),
  'service_role can read staging secrets'
);
select ok(
  has_table_privilege('service_role', 'private.staging_secrets', 'insert'),
  'service_role can insert a staging secret'
);
select ok(
  not has_table_privilege('service_role', 'private.staging_secrets', 'update'),
  'service_role cannot replace a staging secret'
);
select ok(
  position(
    'REDACTED_STAGING_PASSWORD' in pg_get_functiondef(
      'public.staging_create_test_user(text)'::regprocedure
    )
  ) = 0,
  'the create function does not store the password'
);

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

set local role service_role;
select is(
  (select value from private.staging_secrets where key = 'test_password'),
  'REDACTED_STAGING_PASSWORD',
  'service_role reads the hand-set password'
);
reset role;

set local role anon;

select lives_ok(
  $$select public.staging_create_test_user('QA+Build-1019@Homizi.in')$$,
  'anon creates a mixed-case qa mailbox'
);
select lives_ok(
  $$select public.staging_create_test_user('qa+build-1019@homizi.in')$$,
  'anon can call again for an existing qa mailbox'
);

reset role;

delete from private.staging_secrets where key = 'test_password';

set local role anon;
select lives_ok(
  $$select public.staging_create_test_user('qa+build-1019@homizi.in')$$,
  'an existing mailbox does not need the password row'
);
reset role;

insert into private.staging_secrets (key, value)
values ('test_password', 'REDACTED_STAGING_PASSWORD')
on conflict (key) do nothing;

reset role;

select is(
  (select count(*)::int from auth.users where email = 'qa+build-1019@homizi.in'),
  1,
  'the second call does not insert another user'
);
select is(
  (select email from auth.users where lower(email) = 'qa+build-1019@homizi.in'),
  'qa+build-1019@homizi.in',
  'the stored mailbox is lowercase'
);
select ok(
  (
    select u.email_confirmed_at is not null
      and u.aud = 'authenticated'
      and u.role = 'authenticated'
      and u.instance_id is not null
      and u.raw_app_meta_data ->> 'provider' = 'email'
      and u.raw_app_meta_data -> 'providers' = '["email"]'::jsonb
      and u.encrypted_password = extensions.crypt(
        'REDACTED_STAGING_PASSWORD',
        u.encrypted_password
      )
    from auth.users u
    where u.email = 'qa+build-1019@homizi.in'
  ),
  'the qa user is confirmed and uses the throwaway password'
);
select is(
  (
    select primary_role::text
    from public.users p
    join auth.users u on u.id = p.id
    where u.email = 'qa+build-1019@homizi.in'
  ),
  'unset',
  'the qa user has no role yet'
);
select is(
  (
    select display_name
    from public.profiles p
    join auth.users u on u.id = p.user_id
    where u.email = 'qa+build-1019@homizi.in'
  ),
  '',
  'onboarding has not filled a name'
);
select ok(
  (
    select p.primary_role is null
    from public.profiles p
    join auth.users u on u.id = p.user_id
    where u.email = 'qa+build-1019@homizi.in'
  ),
  'profiles.primary_role stays empty so the role picker runs'
);
select is(
  (
    select i.provider = 'email'
      and i.provider_id = u.id::text
      and i.identity_data ->> 'sub' = u.id::text
      and i.identity_data ->> 'email' = u.email
    from auth.identities i
    join auth.users u on u.id = i.user_id
    where u.email = 'qa+build-1019@homizi.in'
  ),
  true,
  'the email identity stores sub, email, and provider_id'
);

select tests.create_supabase_user(
  'staging_real',
  'staging-real@example.test'
);
update auth.users
set created_at = now() - interval '30 days'
where email = 'staging-real@example.test';
update auth.users
set created_at = now() - interval '3 days'
where email = 'qa+build-1019@homizi.in';

select is(
  public.staging_purge_test_users(interval '1 day'),
  1,
  'an old qa mailbox is removed'
);
select is(
  (select count(*)::int from auth.users where email = 'qa+build-1019@homizi.in'),
  0,
  'the purged auth user is gone'
);
select is(
  (select count(*)::int from auth.users where email = 'staging-real@example.test'),
  1,
  'purge leaves a normal mailbox in place'
);

select throws_ok(
  $$select public.staging_purge_test_users(interval '0')$$,
  '22023',
  'Choose an age greater than zero.',
  'purge requires a positive age'
);

set local role anon;
select lives_ok(
  $$select public.staging_create_test_user('qa+kept@homizi.in')$$,
  'a fresh qa mailbox is created for the rate limit'
);
reset role;

select is(
  public.staging_purge_test_users(interval '1 day'),
  0,
  'a mailbox created just now is kept'
);

reset role;

do $$
declare
  i integer;
begin
  for i in 1..49 loop
    perform public.staging_create_test_user('qa+n' || i || '@homizi.in');
  end loop;
end
$$;

select throws_ok(
  $$select public.staging_create_test_user('qa+overflow@homizi.in')$$,
  '54000',
  'The daily staging test account limit was reached.',
  'the fifty-first mailbox of the UTC day is refused'
);

select is(
  (
    select count(*)::int
    from auth.users
    where email ~ '^qa\+[a-z0-9-]{1,32}@homizi\.in$'
  ),
  50,
  'fifty qa mailboxes exist after the limit is hit'
);

select * from finish();
rollback;
