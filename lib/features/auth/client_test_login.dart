/// Client-side test sign-in for one mailbox.
///
/// The Mumbai project has no email test-OTP map in `supabase/config.toml`,
/// and that file is not pushed, so a dashboard test OTP is not assumed.
/// [clientTestDemoEmail] with [clientTestDemoCode] therefore always opens an
/// on-device demo session and does not call Supabase Auth.
///
/// Every other address, including other `test<N>@homizi.in` mailboxes, keeps
/// hosted OTP or the staging password path. Production must ignore this match.
const clientTestDemoEmail = 'test5@homizi.in';

const clientTestDemoCode = '000000';

/// True only for the labelled client test account and its fixed code.
bool isClientTestDemoAccount(String email, String code) {
  return email.trim().toLowerCase() == clientTestDemoEmail &&
      code.trim() == clientTestDemoCode;
}
