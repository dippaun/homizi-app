-- Own profile, both roles, consent, and mock verification.
-- Another user cannot read the private phone or rename the profile.
begin;
select no_plan();

select hasnt_column(
  'public',
  'profiles',
  'phone',
  'public profiles have no phone column'
);
select hasnt_column(
  'public',
  'profiles',
  'email',
  'public profiles have no email column'
);

select tests.create_supabase_user(
  'tenant_a',
  'profile_tenant@example.test',
  '+910000000041'
);
select tests.create_supabase_user(
  'host_b',
  'profile_host@example.test',
  '+910000000042'
);

select tests.authenticate_as('tenant_a');
set local role authenticated;

update public.profiles
set display_name = 'A Tenant',
    occupation = 'Designer',
    public_bio = 'Koramangala.'
where user_id = auth.uid();

select is(
  (select display_name from public.profiles where user_id = auth.uid()),
  'A Tenant',
  'a user can rename their own profile'
);

update public.users set primary_role = 'both' where id = auth.uid();

select is(
  (select primary_role::text from public.users where id = auth.uid()),
  'both',
  'one account can record both roles'
);

insert into public.consent_records (user_id, policy_type, policy_version)
values
  (auth.uid(), 'terms', '2026-10-11-draft'),
  (auth.uid(), 'privacy', '2026-10-11-draft');

select is(
  (select count(*) from public.consent_records where user_id = auth.uid()),
  2::bigint,
  'terms and privacy consent are stored for the signed-in user'
);

select is(
  public.request_mock_verification()::text,
  'mock_pending',
  'mock verification stops at mock_pending'
);

insert into public.host_profiles (user_id, host_category, company_name)
values (auth.uid(), 'owner', 'Demo Homes');

select is(
  (select host_category::text from public.host_profiles where user_id = auth.uid()),
  'owner',
  'the same account can save a host profile'
);

update public.private_contacts
set phone = '+919876543210'
where user_id = auth.uid();

select is(
  (select phone from public.private_contacts where user_id = auth.uid()),
  '+919876543210',
  'the owner can store their own phone'
);

reset role;
select tests.authenticate_as('host_b');
set local role authenticated;

select is(
  (
    select count(*)
    from public.private_contacts
    where user_id = tests.get_supabase_uid('tenant_a')
  ),
  0::bigint,
  'another user cannot read the private phone'
);

update public.profiles
set display_name = 'hacked'
where user_id = tests.get_supabase_uid('tenant_a');

reset role;

select is(
  (
    select display_name
    from public.profiles
    where user_id = tests.get_supabase_uid('tenant_a')
  ),
  'A Tenant',
  'another user cannot rename the profile'
);

select * from finish();
rollback;
