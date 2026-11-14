-- Confirmation timestamps are copied from auth.users and cannot be edited
-- by the signed-in person. Phone and email stay unique on private_contacts.
begin;
select plan(5);

select has_column('public', 'profiles', 'email_confirmed_at', 'email confirmation is mirrored');
select has_column('public', 'profiles', 'phone_confirmed_at', 'phone confirmation is mirrored');

select tests.create_supabase_user('otp_owner', 'otp-owner@example.test', '+919876543210');
select tests.create_supabase_user('otp_other', 'otp-other@example.test', '+919876543211');

select isnt(
  (select email_confirmed_at from public.profiles where user_id = tests.get_supabase_uid('otp_owner')),
  null,
  'the auth trigger copies email_confirmed_at'
);

select tests.authenticate_as('otp_owner');
set local role authenticated;

select throws_ok(
  $$update public.profiles set email_confirmed_at = now() where user_id = auth.uid()$$,
  '42501',
  NULL,
  'a signed-in person cannot write the confirmation timestamp'
);

select throws_ok(
  $$update public.private_contacts
    set phone = '+919876543211'
    where user_id = auth.uid()$$,
  '23505',
  NULL,
  'a phone already stored for someone else is refused'
);

select * from finish();
rollback;
