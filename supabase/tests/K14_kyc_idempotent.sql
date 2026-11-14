-- A replayed or late Digio event never downgrades a result.
begin;
select no_plan();

select tests.create_supabase_user('k_tenant', 'k_tenant@example.test');

reset role;
select set_config('request.jwt.claim.role', '', true);
select set_config('request.jwt.claim.sub', '', true);

select is(
  public.apply_kyc_checks(
    tests.get_supabase_uid('k_tenant'), 'in_progress', 'in_progress', 'KID-k1', null, 'digilocker'
  ) -> 'verification' ->> 'verification_status',
  'pending',
  'start-kyc opens a pending request'
);
select is(
  public.apply_kyc_checks(
    tests.get_supabase_uid('k_tenant'), 'verified', 'verified', 'KID-k1', '4821', 'digilocker'
  ) -> 'verification' ->> 'verification_status',
  'verified',
  'the webhook records a pass'
);
select is(
  public.apply_kyc_checks(
    tests.get_supabase_uid('k_tenant'), 'in_progress', 'in_progress', 'KID-k1', null, 'digilocker'
  ) -> 'verification' ->> 'verification_status',
  'verified',
  'a late in-progress event for the same request does not undo the pass'
);
select is(
  (select masked_last4 from public.identity_verifications
   where user_id = tests.get_supabase_uid('k_tenant')),
  '4821',
  'the last 4 digits are kept'
);
select is(
  public.apply_kyc_checks(
    tests.get_supabase_uid('k_tenant'), 'failed', 'failed', 'KID-k2', null, 'digilocker'
  ) -> 'verification' ->> 'verification_status',
  'rejected',
  'a new request starts fresh'
);
select is(
  public.apply_kyc_checks(
    tests.get_supabase_uid('k_tenant'), 'in_progress', 'in_progress', 'KID-k2', null, 'digilocker'
  ) -> 'verification' ->> 'aadhaar_status',
  'failed',
  'a failed check does not go back to in progress'
);

update public.identity_verifications
set started_at = now() - interval '20 days'
where user_id = tests.get_supabase_uid('k_tenant');
select is(
  (public.apply_kyc_checks(
    tests.get_supabase_uid('k_tenant'), 'in_progress', 'in_progress', 'KID-k3', null, 'digilocker'
  ) -> 'verification' ->> 'started_at')::timestamptz > now() - interval '1 minute',
  true,
  'a new request restarts the link clock'
);

select tests.authenticate_as('k_tenant');
set local role authenticated;
select throws_ok(
  $$select public.apply_kyc_checks(
      auth.uid(), 'verified', 'verified', 'KID-k2', '4821', 'digilocker'
    )$$,
  '42501',
  NULL,
  'a signed-in user still cannot write a result'
);

select * from finish();
rollback;
