# Rent payments (Razorpay test mode)

HOMIZI can record rent, a deposit, or maintenance between two people on an active match. This is test mode only. No live key is accepted. Demo mode never calls Razorpay and does not move money.

## App

- Android uses `razorpay_flutter` when `RAZORPAY_KEY_ID` starts with `rzp_test_`.
- Web uses Razorpay Checkout JS through `window.homiziOpenRazorpay` in `web/index.html`.
- An empty key uses the demo gateway. The screen shows a Test mode banner and Simulate success / Simulate failure.
- A `rzp_live_` key throws when the app config is parsed. The order function also refuses it.
- The client does not mark a Razorpay row paid. The webhook does.

`RAZORPAY_KEY_ID` may be passed with `--dart-define`. Do not put it in `config/staging.json`.

## Database

`docs/staging_apply_D_1017b.sql` extends the existing `payments` table. Clients still cannot insert or update. Payer and payee can select. Status values are the existing enum: `pending`, `succeeded`, `failed`, `refunded`.

`create_demo_payment` and `complete_demo_payment` are the fallback when the Edge Function is not deployed or the test key is absent.

## Edge Functions

Deploy:

- `create-razorpay-order` (`verify_jwt = true`)
- `razorpay-webhook` (`verify_jwt = false`)

Secrets:

- `RAZORPAY_KEY_ID` — must start with `rzp_test_`
- `RAZORPAY_KEY_SECRET` — the test key secret
- `RAZORPAY_WEBHOOK_SECRET` — from the Razorpay test webhook

Create a test-mode webhook in the Razorpay dashboard pointing at:

`https://loraalfiuklespaldotd.supabase.co/functions/v1/razorpay-webhook`

Subscribe to `payment.captured` and `payment.failed`. The function checks the `X-Razorpay-Signature` HMAC of the raw body.

## Receipts

The Pay rent screen links to `/tools` when that route exists (rent receipts). Otherwise it shows the latest test payment so it can be copied into a receipt.
