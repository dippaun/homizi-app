-- Clients cannot mark Aadhaar or face checks verified.
begin;
select no_plan();

select tests.create_supabase_user('h_tenant', 'h_tenant@example.test');
select tests.create_supabase_user('h_other', 'h_other@example.test');

select tests.authenticate_as('h_other');
set local role authenticated;

select throws_ok(
  $$insert into public.identity_verifications (
      user_id, verification_status, aadhaar_status, face_status, masked_last4
    ) values (
      auth.uid(), 'verified', 'verified', 'verified', '4821'
    )$$,
  '42501',
  NULL,
  'a client cannot insert a verified identity row'
);

reset role;
select tests.authenticate_as('h_tenant');
set local role authenticated;

select is(
  (public.record_kyc_consent('digilocker') -> 'verification' ->> 'verification_status'),
  'consent_given',
  'consent is recorded without marking the user verified'
);
select is(
  (public.record_kyc_consent('digilocker') -> 'verification' ->> 'aadhaar_status'),
  'not_started',
  'consent does not verify Aadhaar'
);
select is(
  (public.record_kyc_consent('digilocker') -> 'verification' ->> 'face_status'),
  'not_started',
  'consent does not verify the face'
);

select throws_ok(
  $$select public.apply_kyc_checks(
      auth.uid(), 'verified', 'verified', 'KID-live', '4821', 'digilocker'
    )$$,
  '42501',
  NULL,
  'a signed-in user cannot mark Aadhaar or face verified'
);

select throws_ok(
  $$update public.identity_verifications
    set
      verification_status = 'verified',
      aadhaar_status = 'verified',
      face_status = 'verified',
      masked_last4 = '4821',
      provider_reference = 'KID-client'
    where user_id = auth.uid()$$,
  '42501',
  'permission denied for table identity_verifications',
  'a direct client update cannot verify Aadhaar or the face'
);

select is(
  (
    select aadhaar_status
    from public.identity_verifications
    where user_id = tests.get_supabase_uid('h_tenant')
  ),
  'not_started',
  'a direct client update does not verify Aadhaar'
);
select is(
  (
    select face_status
    from public.identity_verifications
    where user_id = tests.get_supabase_uid('h_tenant')
  ),
  'not_started',
  'a direct client update does not verify the face'
);
select is(
  (
    select masked_last4
    from public.identity_verifications
    where user_id = tests.get_supabase_uid('h_tenant')
  ),
  null,
  'a client cannot store a mask'
);

reset role;
select set_config('request.jwt.claim.role', '', true);
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  $$select public.apply_kyc_checks(
      tests.get_supabase_uid('h_tenant'),
      'verified',
      'verified',
      '123456789012',
      '9012',
      'digilocker'
    )$$,
  '22023',
  NULL,
  'a 12-digit request id is refused'
);

select throws_ok(
  $$select public.apply_kyc_checks(
      tests.get_supabase_uid('h_tenant'),
      'verified',
      'verified',
      'KID-live',
      '123456789012',
      'digilocker'
    )$$,
  '22023',
  NULL,
  'a full Aadhaar number is refused as a mask'
);

select is(
  (
    public.apply_kyc_checks(
      tests.get_supabase_uid('h_tenant'),
      'verified',
      'verified',
      'KID-live',
      '4821',
      'digilocker'
    ) -> 'verification' ->> 'aadhaar_status'
  ),
  'verified',
  'the server role can record an Aadhaar result'
);
select is(
  (
    select face_status
    from public.identity_verifications
    where user_id = tests.get_supabase_uid('h_tenant')
  ),
  'verified',
  'the server role can record a face result'
);
select is(
  (
    select aadhaar_verified and face_verified
    from public.user_badges
    where user_id = tests.get_supabase_uid('h_tenant')
  ),
  true,
  'badges follow the server result'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_badges'
      and column_name in ('masked_last4', 'provider_reference')
  ),
  'badges do not expose a mask or a request id'
);

select tests.authenticate_as('h_other');
set local role authenticated;

select is(
  (select count(*) from public.identity_verifications),
  0::bigint,
  'another person cannot read the verification row'
);
select is(
  (public.delete_my_verification() ->> 'ok')::boolean,
  true,
  'deleting your own empty record is allowed'
);

reset role;

select is(
  (
    select count(*)
    from public.identity_verifications
    where user_id = tests.get_supabase_uid('h_tenant')
  ),
  1::bigint,
  'deleting another account does not remove this verification'
);

select tests.authenticate_as('h_tenant');
set local role authenticated;

select is(
  (public.delete_my_verification() ->> 'ok')::boolean,
  true,
  'the person can delete their own verification data'
);
select is(
  (
    select count(*)
    from public.identity_verifications
    where user_id = tests.get_supabase_uid('h_tenant')
  ),
  0::bigint,
  'deletion removes the status, the request id, and the mask'
);

select * from finish();
rollback;
