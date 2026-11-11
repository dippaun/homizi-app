# Chat contact check

Chat reuses `public.messages`, `public.conversations`, and `public.send_message`. A message is stored only when `public.contains_contact_text` is false. The same rules run on the device in `lib/features/chat/domain/contact_guard.dart` before the request is sent.

`supabase/migrations/20261111130000_chat_contact_guard.sql` replaces the function. `docs/staging_apply_CHAT_1111.sql` is the same script for a manual paste. Neither file is applied to a hosted project by this change.

## Blocked

- An email address, including `name@host.tld`.
- An address written as `name [at] host [dot] com`, or `name at gmail dot com`, or a sentence that says "email" and uses "at" and "dot".
- A direct-message link: `wa.me`, `whatsapp.com`, `t.me`, `telegram.me`, `telegram.dog`.
- A phone number:
  - 10 to 15 digits in a row, such as `9876543210`.
  - The same number with spaces, dots, dashes, or slashes: `98765 43210`, `98765-43210`, `98765.43210`, `+91 98765 43210`.
  - Digits broken by up to three short words: `98 then 76 then 543210`.
  - Digits written as words, including `oh` for zero and `double` / `triple`: `nine eight seven six five four three two one zero`.
  - An Indian mobile (10 digits starting with 6–9), a trunk number (`0` plus 10 digits), or a `91` / `091` / `0091` country code.
  - Any `+` followed by 10 to 15 digits, so a non-Indian number in international form is blocked too.

The message is not sent. The composer keeps the draft and shows an orange warning: "Remove the phone number or email before sending. Chat cannot carry contact details."

## Left alone

These stay sendable so ordinary listing talk is not flagged:

- Rents and deposits: `₹18,000`, `Rs 18000`, `INR 1,80,000`, `Rent is 18000`. A money amount is masked only when it is under 10 digits or uses Indian comma grouping. `Rs 9876543210` is still a phone.
- Dates: `12/11/2026`, `2026-11-12`, `1 Dec`, `15 Nov 2026`, `11:30`, `4 pm`.
- Home types: `2BHK`, `2 BHK`, `1RK`.
- Floors: `4th floor`, `floor 2`, `floor 7`.
- Pincodes: a labelled 6-digit code whose first digit is 1–8 (`pin 560034`, `pincode 560001`) and a bare 6-digit code. Two neighbouring pincodes (`560001 560038`) are not joined into a phone.
- Short times and counts: `See you at 11`, `one room`.

A 16-digit reference is not treated as a phone. A partial number shorter than 10 digits is not treated as a phone unless separators or words join it into one of the shapes above.

## Read ticks

The messages table has no read column. A tick on your own bubble is a single mark when it is the latest from you, and a double mark when the other person has a later message in the thread. Opening a conversation clears its unread count on this device. Live inserts still arrive through the existing `messages` realtime publication when a signed-in session is connected.
